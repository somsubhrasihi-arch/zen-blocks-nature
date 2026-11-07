import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress_store.dart';
import 'ads_config.dart';

import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Live services are opt-in build configuration; never simulate a payment/ad.
class Monetization extends ChangeNotifier {
  Monetization(this.progress);
  final ProgressStore progress;
  static const testAds = bool.fromEnvironment('ADS_TEST_MODE');
  static const ads = AdsConfiguration(testMode: testAds,
    productionRewardedUnit: String.fromEnvironment('REWARDED_AD_UNIT_ID'));
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

  String status = 'Purchases and ads are not available in this build.';
  bool get adsConfigured =>
      rewardedUnit.isNotEmpty &&
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
      adStatus = testAds ? 'Test ads enabled · No advertising revenue' : 'Watch an optional ad for one extra life.';
      // A fresh UMP update is requested on each launch for production ads.
      if (!testAds) _consentRequest = _refreshConsent();
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

  Future<bool> watchForLife() async {
    if (!adsConfigured || busy || progress.data.livesAt(progress.now) >= 5)
      return false;
    busy = true;
    _emit();
    try {
      adStatus = testAds ? 'Loading test ad…' : 'Loading rewarded ad…'; _emit();
      if (!testAds) {
        var allowed = await (_consentRequest ??= _refreshConsent());
        if (!allowed) { allowed = await (_consentRequest = _refreshConsent()); }
        if (!allowed) { adStatus = 'Ads are unavailable with the current privacy settings.'; return false; }
      }
      await MobileAds.instance.initialize();
      final loaded = Completer<RewardedAd?>();
      RewardedAd.load(
        adUnitId: rewardedUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) { if (loaded.isCompleted || _disposed) { ad.dispose(); } else { loaded.complete(ad); } },
          onAdFailedToLoad: (_) { if (!loaded.isCompleted) loaded.complete(null); },
        ),
      );
      final ad = await loaded.future.timeout(const Duration(seconds: 30), onTimeout: () { if (!loaded.isCompleted) loaded.complete(null); return null; });
      if (ad == null || _disposed) {
        ad?.dispose();
        adStatus = 'No ad available. Please try again later.';
        return false;
      }
      final closed = Completer<void>();
      Future<bool>? grant;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          closed.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          closed.complete();
        },
      );
      ad.show(
        onUserEarnedReward: (_, reward) {
          grant ??= progress.grantAdLife();
        },
      );
      await closed.future;
      final earned = grant != null && await grant!;
      adStatus = earned
          ? 'One life added!'
          : 'Finish the rewarded ad to receive a life.';
      return earned;
    } catch (_) {
      adStatus = 'Ad unavailable. Please try again later.';
      return false;
    } finally {
      busy = false;
      _emit();
    }
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
    _subscription?.cancel();
    super.dispose();
  }
}
