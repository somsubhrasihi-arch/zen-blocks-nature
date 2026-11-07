import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress_store.dart';
import 'ads_config.dart';
import 'play_modes.dart';

import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Live services are opt-in build configuration; never simulate a payment/ad.
class Monetization extends ChangeNotifier {
  Monetization(this.progress, {AdsConfiguration? adConfiguration,
    Future<void> Function()? initializeAds,
    Future<RewardedAd?> Function(String unit)? loadAd})
    : configuration = adConfiguration ?? ads,
      _initializeAds = initializeAds, _loadAd = loadAd;
  final AdsConfiguration configuration;
  final Future<void> Function()? _initializeAds;
  final Future<RewardedAd?> Function(String unit)? _loadAd;
  String? adDiagnostic;
  bool hasAdFailure = false;
  String? _activeAdUnit;
  int _failureCount = 0;
  DateTime? _retryAt;
  Timer? _retryTimer;
  Duration get retryIn {
    if (_retryAt == null) return Duration.zero;
    final duration = _retryAt!.difference(progress.now);
    return duration.isNegative ? Duration.zero : duration;
  }
  bool get canRequestAd => !busy && retryIn == Duration.zero;
  bool get coinAdsConfigured => configuration.coinRewardedUnit.isNotEmpty && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  void _cooldown(int seconds) {
    _retryAt = progress.now.add(Duration(seconds: seconds));
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () { _retryAt = null; _emit(); });
  }

  bool get usingTestAds => configuration.testMode;

  final ProgressStore progress;
  static const testAds = bool.fromEnvironment('ADS_TEST_MODE');
  static const ads = AdsConfiguration(testMode: testAds,
    productionRewardedUnit: String.fromEnvironment('REWARDED_AD_UNIT_ID'),
    productionCoinUnit: String.fromEnvironment('REWARDED_COIN_AD_UNIT_ID'));
  static String get rewardedUnit => ads.rewardedUnit;
  String adStatus = 'Rewarded ads are not available in this build.';
  bool privacyOptionsRequired = false;
  Future<bool>? _consentRequest;
  Future<bool> _refreshConsent() async {
    final result = Completer<bool>();
    Future<void> finish() async {
      try {
        final allowed = await ConsentInformation.instance.canRequestAds();
        privacyOptionsRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
        if (!result.isCompleted) result.complete(allowed);
        _emit();
      } catch (_) { if (!result.isCompleted) result.complete(false); }
    }
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () {
        if (_disposed || result.isCompleted) { if (!result.isCompleted) result.complete(false); return; }
        ConsentForm.loadAndShowConsentFormIfRequired((_) { unawaited(finish()); });
      }, (_) { unawaited(finish()); });
      return await result.future.timeout(const Duration(seconds: 30), onTimeout: () { if (!result.isCompleted) result.complete(false); return false; });
    } catch (_) { return false; }
  }
  static const verificationUrl = String.fromEnvironment('PURCHASE_VERIFY_URL');
  static const productIds = {'tblock_coins_500', 'tblock_coins_1500'};
  final Map<String, ProductDetails> products = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool busy = false, _initialized = false, _disposed = false;
  Future<void> _purchaseQueue = Future.value();
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String status = 'Purchases are not available in this build.';
  bool get adsConfigured =>
      configuration.enabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  bool get billingConfigured =>
      Uri.tryParse(verificationUrl)?.scheme == 'https' &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (adsConfigured) {
      adStatus = usingTestAds ? 'Test ads enabled · No advertising revenue' : 'Watch an optional ad for one extra life.';
      // A fresh UMP update is requested on each launch for production ads.
      if (!usingTestAds) _consentRequest = _refreshConsent();
      _emit();
    }
    if (!billingConfigured) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (updates) {
        _purchaseQueue = _purchaseQueue
            .then((_) => _updates(updates))
            .catchError((Object error) {
              busy = false;
              status =
                  'Purchase delivery is pending. Try recovering the purchase.';
              _emit();
            });
      },
      onError: (Object error) {
        status = 'Store connection lost. Try again later.';
        _emit();
      },
    );
    try {
      if (!await InAppPurchase.instance.isAvailable()) {
        status = 'Google Play is unavailable.';
        _emit();
        return;
      }
      final response = await InAppPurchase.instance.queryProductDetails(
        productIds,
      );
      products.addEntries(
        response.productDetails.map((p) => MapEntry(p.id, p)),
      );
      status = products.isEmpty
          ? 'Products are not available yet.'
          : 'Secure checkout with Google Play';
    } catch (_) {
      status = 'Could not connect to Google Play.';
    }
    _emit();
  }

  Future<void> buy(ProductDetails product) async {
    if (busy || !billingConfigured) return;
    busy = true;
    _emit();
    try {
      final opened = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: false,
      );
      if (!opened) {
        busy = false;
        status = 'Checkout could not open.';
      }
    } catch (_) {
      busy = false;
      status = 'Checkout is unavailable. Please try again.';
    }
    _emit();
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        status = 'Waiting for payment confirmation…';
        _emit();
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          // The server verifies product/package/token with Google, records a unique
          // grant and returns its stable grantId. No service credentials live here.
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 15);
          late Map result;
          try {
            final request = await client
                .postUrl(Uri.parse(verificationUrl))
                .timeout(const Duration(seconds: 20));
            request.headers.contentType = ContentType.json;
            request.write(
              jsonEncode({
                'productId': purchase.productID,
                'source': purchase.verificationData.source,
                'verificationData':
                    purchase.verificationData.serverVerificationData,
              }),
            );
            final response = await request.close().timeout(
              const Duration(seconds: 20),
            );
            final body = await response
                .transform(utf8.decoder)
                .join()
                .timeout(const Duration(seconds: 20));
            if (response.statusCode != 200)
              throw StateError('Verification failed');
            result = jsonDecode(body) as Map;
          } finally {
            client.close(force: true);
          }
          if (result['verified'] != true ||
              result['productId'] != purchase.productID ||
              result['grantId'] is! String ||
              (result['grantId'] as String).isEmpty) {
            throw StateError('Invalid verification response');
          }
          await progress.grantVerifiedPurchase(
            result['grantId'] as String,
            purchase.productID,
          );
          // Complete only after the durable grant. Android consumables are consumed
          // explicitly so a crash before delivery can be recovered by Play.
          await _consume(purchase);
          if (purchase.pendingCompletePurchase)
            await InAppPurchase.instance.completePurchase(purchase);
          status = 'Coins added. Enjoy your next adventure!';
        } catch (_) {
          status = 'Purchase delivery is pending. Reopen the store to retry.';
        }
      } else {
        status = purchase.status == PurchaseStatus.canceled
            ? 'Purchase cancelled.'
            : 'Payment could not be completed.';
        if (purchase.pendingCompletePurchase)
          await InAppPurchase.instance.completePurchase(purchase);
      }
      busy = false;
      _emit();
    }
  }

  Future<void> _consume(PurchaseDetails purchase) async {
    // Platform-specific consumption is required when autoConsume is disabled.
    await InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .consumePurchase(purchase);
  }

  Future<void> recover() async {
    if (billingConfigured && !busy)
      await InAppPurchase.instance.restorePurchases();
  }

  /// Preserve SDK failures rather than collapsing every failure into no-fill.
  Future<RewardedAd?> _requestRewardedAd(String unit) async {
    if (_loadAd != null) return await _loadAd(unit);
    final result = Completer<RewardedAd?>();
    var accepting = true;
    unawaited(RewardedAd.load(adUnitId: unit, request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!accepting || result.isCompleted || _disposed) { ad.dispose(); }
          else { result.complete(ad); }
        },
        onAdFailedToLoad: (error) {
          if (accepting && !result.isCompleted) result.completeError(error);
        },
      )).catchError((Object error, StackTrace stack) {
        if (accepting && !result.isCompleted) result.completeError(error, stack);
      }));
    try { return await result.future.timeout(const Duration(seconds: 40)); }
    finally { accepting = false; }
  }
  void _adFailed(String stage, Object error) {
    hasAdFailure = true;
    _failureCount++;
    _cooldown(_failureCount == 1 ? 15 : _failureCount == 2 ? 30 : 60);
    final sdk = error is AdError ? error : null;
    adStatus = error is TimeoutException
      ? 'The ad request timed out. Check your connection and try again.'
      : 'Ad couldn’t load. You can retry shortly or keep playing.';
    if (kDebugMode) {
      final reason = sdk == null ? '$error' : 'Code: ${sdk.code}\nDomain: ${sdk.domain}\nMessage: ${sdk.message}';
      adDiagnostic = 'Stage: $stage\nMode: ${usingTestAds ? 'Google sample test ad' : 'Configured ad unit'}\nUnit: ${_activeAdUnit ?? configuration.rewardedUnit}\n$reason';
      if (sdk != null) adStatus += ' (Error ${sdk.code})';
    }
    _emit();
  }
  Future<bool> watchForLife({bool Function()? canShow}) => _watchReward(
    unit: configuration.rewardedUnit, eligible: () => progress.canWatchLifeAd,
    grant: progress.grantAdLife, rewardLabel: 'One life added!', canShow: canShow);
  Future<bool> watchForRunBonus(String runId, {bool Function()? canShow}) => _watchReward(
    unit: configuration.coinRewardedUnit,
    eligible: () => progress.data.canClaimRunAd(runId, utcDay(progress.now)),
    grant: () => progress.grantRunAdBonus(runId), rewardLabel: '25 bonus coins added!', canShow: canShow);
  Future<bool> _watchReward({required String unit, required bool Function() eligible,
    required Future<bool> Function() grant, required String rewardLabel, bool Function()? canShow}) async {
    if (unit.isEmpty || kIsWeb || defaultTargetPlatform != TargetPlatform.android || !canRequestAd || !eligible()) return false;
    busy = true; adDiagnostic = null; hasAdFailure = false; _activeAdUnit = unit;
    var stage = 'Initializing ad SDK';
    _emit();
    try {
      adStatus = usingTestAds ? 'Loading test ad…' : 'Loading rewarded ad…'; _emit();
      if (!usingTestAds) {
        stage = 'Privacy consent';
        var allowed = await (_consentRequest ??= _refreshConsent());
        if (!allowed) allowed = await (_consentRequest = _refreshConsent());
        if (!allowed) { adStatus = 'Ads are unavailable with the current privacy settings.'; return false; }
      }
      stage = 'Initializing ad SDK';
      if (_initializeAds != null) { await _initializeAds().timeout(const Duration(seconds: 20)); }
      else { await MobileAds.instance.initialize().timeout(const Duration(seconds: 20)); }
      stage = 'Loading rewarded ad';
      final ad = await _requestRewardedAd(unit);
      if (ad == null || _disposed || !eligible() || (canShow != null && !canShow())) {
        ad?.dispose();
        if (ad == null && !_disposed) _adFailed(stage, StateError('No ad returned by the SDK'));
        else { adStatus = 'Ad cancelled. Continue when you’re ready.'; }
        return false;
      }
      stage = 'Showing ad';
      final closed = Completer<void>();
      Future<bool>? delivery;
      AdError? showError;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) { ad.dispose(); if (!closed.isCompleted) closed.complete(); },
        onAdFailedToShowFullScreenContent: (ad, error) {
          showError = error; ad.dispose(); if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show(onUserEarnedReward: (_, reward) { delivery ??= grant(); });
      await closed.future;
      if (showError != null) { _adFailed(stage, showError!); return false; }
      stage = 'Saving life reward';
      final earned = delivery != null && await delivery!;
      if (earned) { _failureCount = 0; _cooldown(60); }
      adStatus = earned ? rewardLabel : 'Finish the rewarded ad to receive the reward.';
      return earned;
    } catch (error) { _adFailed(stage, error); return false; }
    finally { busy = false; _emit(); }
  }

  Future<void> privacyOptions() async {
    if (adsConfigured && privacyOptionsRequired) {
      ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) { adStatus = 'Privacy choices are unavailable. Please try again.'; _emit(); }
        _consentRequest = null;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
