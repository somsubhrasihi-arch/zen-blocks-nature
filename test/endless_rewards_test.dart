import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:zen_blocks/journey_ui.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/monetization.dart';
import 'product_ui_test.dart' show captureKey, capture, loadPreviewFonts;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/campaign.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'generated stages stay playable and restore far beyond the first campaign',
    () {
      for (final id in [31, 40, 99, 1000, 1000000]) {
        final stage = stageForId(id)!;
        expect(stage.startLevel, lessThanOrEqualTo(9));
        expect(stage.obstacleCount, lessThanOrEqualTo(9));
        final game = ZenGame()..start(journeyStage: stage);
        final restored = ZenGame();
        expect(restored.restoreState(game.saveState()), true);
        expect(restored.stage!.id, id);
        game.dispose();
        restored.dispose();
      }
      final p = PlayerProgress();
      for (var id = 1; id <= 1000; id++) {
        p.stars[id] = 3;
      }
      expect(p.recommendedStage!.id, 1001);
      expect(PlayerProgress.fromJson(p.toJson()).stars[1000], 3);
    },
  );
  test(
    'life reservation, resume, win refund and refill survive reloads',
    () async {
      var now = DateTime.utc(2026, 11, 8, 12);
      var store = ProgressStore(utcNow: () => now);
      await store.load();
      expect(await store.beginJourney('one'), true);
      expect(store.data.lives, 4);
      expect(await store.beginJourney('one'), true);
      expect(store.data.lives, 4);
      await store.settle(
        runId: 'one',
        lines: 2,
        pieces: 8,
        stageId: 1,
        completed: true,
        stars: 3,
      );
      expect(store.data.lives, 5);
      await store.settle(
        runId: 'one',
        lines: 2,
        pieces: 8,
        stageId: 1,
        completed: true,
        stars: 3,
      );
      expect(store.data.lives, 5);
      for (var i = 0; i < 5; i++) {
        expect(await store.beginJourney('fail$i'), true);
      }
      expect(await store.beginJourney('empty'), false);
      now = now.add(const Duration(minutes: 31));
      store = ProgressStore(utcNow: () => now);
      await store.load();
      expect(store.data.livesAt(now), 1);
      expect(await store.beginJourney('refilled'), true);
      expect(store.data.lives, 0);
      now = now.subtract(const Duration(hours: 2));
      expect(store.data.livesAt(now), 0);
    },
  );
  test(
    'daily claims are atomic, duplicate safe, reset daily and resist rollback',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      final store = ProgressStore(utcNow: () => now);
      await store.load();
      expect(await store.claimActivity('visit'), true);
      expect(await store.claimActivity('visit'), false);
      expect(await store.claimActivity('lines'), false);
      await store.settle(runId: 'activity', lines: 20, pieces: 70);
      expect(await store.claimActivity('lines'), true);
      final balance = store.data.coins;
      now = now.add(const Duration(days: 1));
      expect(await store.claimActivity('visit'), true);
      expect(store.data.coins, balance + 25);
      now = now.subtract(const Duration(days: 1));
      expect(await store.claimActivity('visit'), false);
      expect(await store.claimActivity('lines'), false);
    },
  );
  test(
    'coin refill and verified purchase receipts cannot double grant',
    () async {
      final store = ProgressStore();
      await store.load();
      await store.grantVerifiedPurchase('verified-one', 'tblock_coins_500');
      await store.grantVerifiedPurchase('verified-one', 'tblock_coins_500');
      expect(store.data.coins, 500);
      expect(await store.refillWithCoins(), false);
      await store.beginJourney('attempt');
      expect(await store.refillWithCoins(), true);
      expect(store.data.coins, 350);
      expect(store.data.lives, 5);
      final reloaded = ProgressStore();
      await reloaded.load();
      await reloaded.grantVerifiedPurchase('verified-one', 'tblock_coins_500');
      expect(reloaded.data.coins, 350);
      expect(await store.grantAdLife(), false);
    },
  );
  testWidgets('daily rewards are claimable and unconfigured monetization stays unavailable', (tester) async {
    final store = ProgressStore(); await store.load();
    final service = Monetization(store); await service.initialize();
    expect(service.products, isEmpty);
    expect(service.billingConfigured, false);
    expect(service.adsConfigured, false);
    await loadPreviewFonts();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key: captureKey, child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark), home: AdventureHub(palette: neonPalette,
      progress: store, monetization: service, onStage: (_) {}, initialTab: 3))));
    await tester.pump();
    expect(find.text('Journey lives · 5 / 5'), findsOneWidget);
    expect(find.text('Rewarded ads are not available in this build.'), findsOneWidget);
    await capture(tester, '24-daily-rewards-lives');
    await tester.scrollUntilVisible(find.text('Your daily gift'), 250, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    final claim = find.text('Claim reward').first;
    await tester.ensureVisible(claim); await tester.pump();
    await tester.tap(claim); await tester.pump(); await tester.pump();
    expect(store.data.coins, 25);
    expect(find.text('Claimed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); service.dispose(); store.dispose();
  });

}
