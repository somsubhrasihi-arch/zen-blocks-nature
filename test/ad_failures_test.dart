import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/ads_config.dart';
import 'package:zen_blocks/monetization.dart';
import 'package:zen_blocks/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('SDK load failure retains its cause, releases retry and grants no life', () async {
    var now = DateTime.utc(2026, 11, 8);
    final progress = ProgressStore(utcNow: () => now); await progress.load();
    await progress.beginJourney('attempt');
    var requests = 0;
    final service = Monetization(progress,
      adConfiguration: const AdsConfiguration(testMode: true),
      initializeAds: () async {},
      loadAd: (unit) async {
        expect(unit, AdsConfiguration.sampleRewardedUnit); requests++;
        throw LoadAdError(2, 'com.google.android.gms.ads', 'Network error', null);
      });
    expect(await service.watchForLife(), false);
    expect(service.busy, false); expect(progress.data.lives, 4);
    expect(service.adDiagnostic, contains('Code: 2'));
    expect(service.adDiagnostic, contains('Network error'));
    expect(service.adDiagnostic, contains('Loading rewarded ad'));
    expect(await service.watchForLife(), false); expect(requests, 1);
    now = now.add(const Duration(seconds: 16));
    expect(await service.watchForLife(), false); expect(requests, 2);
    expect(progress.data.lives, 4);
    service.dispose(); progress.dispose();
  });
  test('initialization timeout is distinguished from an ad load failure', () async {
    final progress = ProgressStore(); await progress.load();
    await progress.beginJourney('attempt');
    var loaded = false;
    final service = Monetization(progress,
      adConfiguration: const AdsConfiguration(testMode: true),
      initializeAds: () async { throw TimeoutException('SDK initialization'); },
      loadAd: (_) async { loaded = true; return null; });
    expect(await service.watchForLife(), false); expect(loaded, false);
    expect(service.adStatus, contains('timed out'));
    expect(service.adDiagnostic, contains('Initializing ad SDK'));
    expect(service.busy, false); expect(progress.data.lives, 4);
    service.dispose(); progress.dispose();
  });
}
