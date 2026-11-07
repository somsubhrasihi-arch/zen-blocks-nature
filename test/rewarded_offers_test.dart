import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/ads_config.dart';
import 'package:zen_blocks/monetization.dart';
import 'package:zen_blocks/progress_store.dart';

class RewardedAdStub extends Fake implements RewardedAd {
  RewardedAdStub({this.earn = true});
  final bool earn;
  bool disposed = false, shown = false;
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  @override
  Future<void> show({
    required OnUserEarnedRewardCallback onUserEarnedReward,
  }) async {
    shown = true;
    if (earn) {
      onUserEarnedReward(this, RewardItem(1, 'test'));
      onUserEarnedReward(this, RewardItem(1, 'test'));
    }
    fullScreenContentCallback?.onAdDismissedFullScreenContent?.call(this);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'completed coin ad grants once even if the SDK repeats the reward callback',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.settle(runId: 'run', lines: 1, pieces: 5);
      final before = store.data.coins, ad = RewardedAdStub();
      final service = Monetization(
        store,
        adConfiguration: const AdsConfiguration(testMode: true),
        initializeAds: () async {},
        loadAd: (_) async => ad,
      );
      expect(await service.watchForRunBonus('run'), true);
      expect(store.data.coins, before + 25);
      expect(store.data.coinAds, 1);
      expect(service.canRequestAd, false);
      expect(ad.disposed, true);
      expect(await service.watchForRunBonus('run'), false);
      service.dispose();
      store.dispose();
    },
  );
  test(
    'early closure grants no coin bonus and does not mark the offer collected',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.settle(runId: 'run', lines: 1, pieces: 5);
      final before = store.data.coins;
      final service = Monetization(
        store,
        adConfiguration: const AdsConfiguration(testMode: true),
        initializeAds: () async {},
        loadAd: (_) async => RewardedAdStub(earn: false),
      );
      expect(await service.watchForRunBonus('run'), false);
      expect(store.data.coins, before);
      expect(store.data.bonusRunClaimed, false);
      service.dispose();
      store.dispose();
    },
  );
  test(
    'leaving the offer screen while loading prevents a late ad from opening',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.beginJourney('life');
      final ad = RewardedAdStub();
      final service = Monetization(
        store,
        adConfiguration: const AdsConfiguration(testMode: true),
        initializeAds: () async {},
        loadAd: (_) async => ad,
      );
      expect(await service.watchForLife(canShow: () => false), false);
      expect(ad.shown, false);
      expect(ad.disposed, true);
      expect(store.data.lives, 4);
      service.dispose();
      store.dispose();
    },
  );
}
