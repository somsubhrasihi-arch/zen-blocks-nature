import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/engagement.dart';
import 'package:zen_blocks/progress_store.dart';
import 'package:zen_blocks/play_modes.dart';
import 'package:zen_blocks/campaign.dart';
import 'package:zen_blocks/cosmetic_paint.dart';
import 'package:zen_blocks/journey_ui.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/ad_help.dart';
import 'package:zen_blocks/friend_challenges.dart';

import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'visit collection survives missed days, reload and duplicate claims',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      var store = ProgressStore(utcNow: () => now);
      await store.load();
      for (var gift = 0; gift < 7; gift++) {
        expect(await store.claimActivity('visit'), true);
        expect(await store.claimActivity('visit'), false);
        now = now.add(Duration(days: gift == 3 ? 4 : 1));
        store = ProgressStore(utcNow: () => now);
        await store.load();
      }
      expect(store.data.giftDays, 7);
      expect(store.data.coins, 250);
      now = now.subtract(const Duration(days: 3));
      expect(await store.claimActivity('visit'), false);
      expect(store.data.giftDays, 7);
    },
  );
  test('weekly missions and chest pay once and expire at Monday UTC', () async {
    var now = DateTime.utc(2026, 11, 8, 23, 59);
    final store = ProgressStore(utcNow: () => now);
    await store.load();
    for (var i = 0; i < 10; i++) {
      await store.settle(
        runId: 'week$i',
        lines: 8,
        pieces: 25,
        stageId: 1,
        completed: true,
        stars: 3,
      );
    }
    expect(await store.claimWeekly('chest'), false);
    final before = store.data.coins;
    for (final mission in weeklyMissions) {
      expect(await store.claimWeekly(mission.id), true);
      expect(await store.claimWeekly(mission.id), false);
    }
    expect(await store.claimWeekly('chest'), true);
    expect(await store.claimWeekly('chest'), false);
    expect(store.data.coins, before + 500);
    now = now.add(const Duration(minutes: 2));
    expect(await store.claimWeekly('lines'), false);
    await store.settle(runId: 'new-week', lines: 1, pieces: 2);
    expect(store.data.weekRuns, 1);
    expect(store.data.weekLines, 1);
    expect(store.data.weeklyClaims, isEmpty);
    now = now.subtract(const Duration(days: 1));
    await store.settle(runId: 'backdated', lines: 50, pieces: 60);
    expect(store.data.weekLines, 1);
    expect(await store.claimWeekly('lines'), false);
  });
  test(
    'run ad bonuses are receipt-bound, capped and duplicate-safe across reload',
    () async {
      var now = DateTime.utc(2026, 11, 8);
      final store = ProgressStore(utcNow: () => now);
      await store.load();
      expect(await store.grantRunAdBonus('invented'), false);
      for (var i = 0; i < 4; i++) {
        await store.settle(runId: 'bonus$i', lines: 1, pieces: 5);
        final before = store.data.coins;
        final claims = await Future.wait([
          store.grantRunAdBonus('bonus$i'),
          store.grantRunAdBonus('bonus$i'),
        ]);
        expect(claims.where((ok) => ok).length, i < 3 ? 1 : 0);
        expect(store.data.coins, before + (i < 3 ? 25 : 0));
      }
      final reloaded = ProgressStore(utcNow: () => now);
      await reloaded.load();
      expect(await reloaded.grantRunAdBonus('bonus3'), false);
      now = now.add(const Duration(days: 1));
      expect(await reloaded.grantRunAdBonus('bonus3'), false);
      await reloaded.settle(runId: 'next-day', lines: 1, pieces: 5);
      expect(await reloaded.grantRunAdBonus('next-day'), true);
    },
  );
  test(
    'life ads cap at five per day without blocking earned-coin refills',
    () async {
      final store = ProgressStore(utcNow: () => DateTime.utc(2026, 11, 8));
      await store.load();
      for (var i = 0; i < 6; i++) {
        await store.beginJourney('life$i');
        expect(await store.grantAdLife(), i < 5);
      }
      expect(store.canWatchLifeAd, false);
      await store.settle(runId: 'earn', lines: 40, pieces: 100);
      expect(await store.refillWithCoins(), true);
      expect(store.data.lives, 5);
    },
  );
  test('bundles debit once, charge only missing cosmetics and preserve equip choices', () async {
    final store = ProgressStore();
    await store.load();
    await store.settle(runId: 'earn', lines: 200, pieces: 500);
    await store.buy('skin:pixel', equip: true);
    final bundle = shopBundles.first;
    expect(bundle.priceFor(store.data.owned), 192);
    final before = store.data.coins;
    final results = await Future.wait([
      store.buyBundle(bundle.id),
      store.buyBundle(bundle.id),
    ]);
    expect(results.where((r) => r == PurchaseResult.purchased).length, 1);
    expect(store.data.coins, before - 192);
    expect(store.data.owned, containsAll(bundle.items));
    expect(store.data.skin, 'pixel');
    final restored = ProgressStore();
    await restored.load();
    expect(await restored.buyBundle(bundle.id), PurchaseResult.owned);
  });
  test(
    'focus quest changes predictably and uses its selected daily counter',
    () async {
      final days = ['2026-11-08', '2026-11-09', '2026-11-10'];
      expect(
        days.map((d) => dailyActivitiesFor(d).last.counter).toSet().length,
        3,
      );
      final store = ProgressStore(utcNow: () => DateTime.utc(2026, 11, 8));
      await store.load();
      final focus = dailyActivitiesFor('2026-11-08').last;
      expect(await store.claimActivity('focus'), false);
      for (var i = 0; i < 5; i++) {
        await store.settle(
          runId: 'focus$i',
          lines: 20,
          pieces: 30,
          stageId: 1,
          completed: true,
          stars: 3,
        );
      }
      expect(
        store.data.activityValue(focus.counter),
        greaterThanOrEqualTo(focus.target),
      );
      expect(await store.claimActivity('focus'), true);
      expect(await store.claimActivity('focus'), false);
    },
  );
  test('shared codes reproduce the Daily seed and reject invalid dates', () {
    final code = friendChallengeCode('2026-11-08');
    expect(dayFromFriendCode(code), '2026-11-08');
    expect(
      dailyForDay(dayFromFriendCode(code))!.seed,
      dailyForDay('2026-11-08')!.seed,
    );
    expect(dayFromFriendCode('TBD-20260230'), isNull);
    expect(dayFromFriendCode('hello'), isNull);
    expect(challengeShareText('2026-11-08', null), contains(code));
  });
  test(
    'Daily records keep the fastest valid completion and survive reload',
    () async {
      final store = ProgressStore(utcNow: () => DateTime.utc(2026, 11, 8));
      await store.load();
      final d = dailyForDay('2026-11-08')!;
      Future<void> finish(String id, int ms) async {
        await store.settle(
          runId: id,
          lines: 50,
          score: 10000,
          obstaclesCleared: 8,
          pieces: 50,
          mode: PlayMode.daily,
          dailyDay: d.day,
          completed: true,
          elapsedMs: ms,
        );
      }

      await finish('slow', 100000);
      await finish('fast', 90000);
      await finish('slower', 110000);
      final restored = ProgressStore();
      await restored.load();
      expect(restored.data.dailyRecords[d.day]!.elapsedMs, 90000);
    },
  );
  test('legacy saves load with safe engagement defaults', () {
    final old = PlayerProgress()..coins = 50;
    final json = old.toJson()
      ..remove('giftDays')
      ..remove('week')
      ..remove('dailyRecords')
      ..remove('rewardedAdDay');
    final p = PlayerProgress.fromJson(json);
    expect(p.coins, 50);
    expect(p.giftDays, 0);
    expect(p.dailyRecords, isEmpty);
    expect(p.lives, 5);
  });
  test('prestige skins have distinct rendered artwork', () async {
    final frames = <String>[];
    for (final skin in ['glass', 'holo', 'circuit', 'crystal']) {
      final recorder = ui.PictureRecorder();
      paintCosmeticBlock(
        Canvas(recorder),
        const Rect.fromLTWH(0, 0, 48, 48),
        Colors.cyan,
        skin: skin,
      );
      final image = await recorder.endRecording().toImage(48, 48);
      final bytes = await image.toByteData();
      frames.add(bytes!.buffer.asUint8List().toString());
      image.dispose();
    }
    expect(frames.toSet().length, 4);
  });
  testWidgets(
    'weekly rewards and ad help remain accessible on a compact screen',
    (tester) async {
      await loadPreviewFonts();
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = ProgressStore();
      await store.load();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: AdventureHub(
              palette: neonPalette,
              progress: store,
              onStage: (_) {},
              initialTab: 3,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Weekly'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Weekly'));
      await tester.pump();
      expect(find.text('This week’s quest'), findsOneWidget);
      await tester.ensureVisible(find.text('This week’s quest'));
      await tester.pump();
      await capture(tester, '25-weekly-quests');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAdHelp(context),
              child: const Text('Help'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Having trouble loading an ad?'), findsOneWidget);
      expect(
        find.textContaining('does not change your DNS settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  testWidgets(
    'friend challenge screen validates codes and opens the selected puzzle',
    (tester) async {
      await loadPreviewFonts();
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = ProgressStore(utcNow: () => DateTime.utc(2026, 11, 8));
      await store.load();
      String? opened;
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FriendChallenges(
                      palette: neonPalette,
                      progress: store,
                      onChallenge: (day) => opened = day,
                    ),
                  ),
                ),
                child: const Text('Friends'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((widget) => widget is SelectableText && widget.data == 'TBD-20261108'), findsOneWidget);
      await capture(tester, '26-friend-challenges');
      await tester.ensureVisible(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'TBD-20990101');
      await tester.ensureVisible(find.text('Open challenge'));
      await tester.pump();
      await tester.tap(find.text('Open challenge'));
      await tester.pump();
      expect(
        find.text('Enter a valid code for today or an earlier day.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'TBD-20261108');
      await tester.ensureVisible(find.text('Open challenge'));
      await tester.pump();
      await tester.tap(find.text('Open challenge'));
      await tester.pumpAndSettle();
      expect(opened, '2026-11-08');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
