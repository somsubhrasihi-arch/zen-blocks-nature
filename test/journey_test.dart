import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/campaign.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/progress_store.dart';
import 'package:zen_blocks/session_store.dart';
import 'fake_audio.dart';
import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

void clearOne(ZenGame game) {
  game.board[19] = [1,1,1,1,1,1,0,0,0,0];
  game.active = Piece(0, [[1,1,1,1]], 6, 18);
  game.hardDrop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('all 30 stages have valid goals, stars and increasing worlds', () {
    expect(journeyStages.length, 30);
    expect(journeyStages.map((s) => s.id).toSet().length, 30);
    for (final s in journeyStages) {
      expect(s.target, greaterThan(0));
      expect(s.starsFor(s.goldPieces), 3);
      expect(s.starsFor(s.goldPieces + 1), 2);
      expect(s.starsFor(s.goldPieces * 2 + 1), 1);
      final game = ZenGame()..start(journeyStage: s);
      expect(game.level, s.startLevel);
      expect(game.obstacleRows.length, s.obstacleCount);
      expect(game.canMove, true);
      final restore = ZenGame();
      expect(restore.restoreState(game.saveState()), true);
      expect(restore.stage!.id, s.id);
      expect(restore.saveState(), game.saveState());
      game.dispose(); restore.dispose();
    }
  });
  test('stage ends on its objective and awards stars for actual blocks used', () {
    final game = ZenGame()..start(journeyStage: journeyStages.first);
    clearOne(game);
    expect(game.completed, false);
    clearOne(game);
    expect(game.completed, true);
    expect(game.over, false);
    expect(game.canMove, false);
    expect(game.earnedStars, 3);
    expect(game.saveState(), isNull);
    final score = game.score;
    game.hardDrop(); game.tick(); game.togglePause();
    expect(game.score, score); expect(game.paused, false);
    game.dispose();
  });
  test('excavation counts marked rows and tracks their movement after clears', () {
    final game = ZenGame()..start(journeyStage: journeyStages[2]);
    expect(game.obstacleRows, {18,19});
    clearOne(game);
    expect(game.obstacleRows, {19});
    expect(game.goalProgress, 1);
    clearOne(game);
    expect(game.completed, true);
    expect(game.goalProgress, 2);
    game.dispose();
  });
  test('score goal ends when reached after locking a piece', () {
    final game = ZenGame()..start(journeyStage: journeyStages[1]);
    game.score = 399;
    game.hardDrop();
    expect(game.completed, true);
    game.dispose();
  });
  test('legacy Classic save still restores without new fields', () {
    final game = ZenGame()..start();
    final old = game.saveState()!..remove('stageId')..remove('runId')..remove('obstacleRows');
    final restored = ZenGame();
    expect(restored.restoreState(old), true);
    expect(restored.stage, isNull);
    expect(restored.runId, isNotEmpty);
    game.dispose(); restored.dispose();
  });
  test('invalid stage metadata cannot alter the live game', () {
    final game = ZenGame()..start();
    final before = game.saveState();
    final bad = jsonDecode(jsonEncode(before)) as Map<String,dynamic>;
    bad['stageId'] = 99;
    expect(game.restoreState(bad), false);
    expect(game.saveState(), before);
    game.dispose();
  });
  test('reward receipts prevent duplicate payouts across reloads', () async {
    final store = ProgressStore(); await store.load();
    final reward = await store.settle(runId: 'one', lines: 2, pieces: 6, stageId: 1, completed: true, stars: 3);
    expect(reward.coins, 155); // 100 stage + 25 first line + 30 first stage
    expect(store.data.stars[1], 3);
    final reloaded = ProgressStore(); await reloaded.load();
    final again = await reloaded.settle(runId: 'one', lines: 2, pieces: 6, stageId: 1, completed: true, stars: 3);
    expect(again.duplicate, true); expect(reloaded.data.coins, 155);
    expect(reloaded.data.runs, 1);
    final replay = await reloaded.settle(runId: 'two', lines: 2, pieces: 8, stageId: 1, completed: true, stars: 2);
    expect(replay.coins, 12); expect(reloaded.data.stars[1], 3);
  });
  test('stars improve once and world gates require stars plus previous stage', () async {
    final p = PlayerProgress();
    expect(p.unlocked(journeyStages.first), true);
    expect(p.unlocked(journeyStages[1]), false);
    for (var i = 1; i <= 10; i++) p.stars[i] = 1;
    expect(p.unlocked(journeyStages[10]), false);
    p.stars[1] = 3;
    expect(p.unlocked(journeyStages[10]), true);
    p.stars.remove(10);
    expect(p.unlocked(journeyStages[10]), false);
    final store = ProgressStore(); await store.load();
    await store.settle(runId:'a',lines:2,pieces:50,stageId:1,completed:true,stars:1);
    final better = await store.settle(runId:'b',lines:2,pieces:10,stageId:1,completed:true,stars:3);
    expect(better.coins,32); expect(store.data.stars[1],3);
  });
  test('parallel purchases debit once, cannot overspend, and equip survives restart', () async {
    final store = ProgressStore(); await store.load();
    await store.settle(runId:'earn',lines:2,pieces:5,stageId:1,completed:true,stars:3);
    final purchases = await Future.wait([store.buy('skin:pixel'),store.buy('skin:pixel'),store.buy('skin:jelly')]);
    expect(purchases,[PurchaseResult.purchased,PurchaseResult.owned,PurchaseResult.insufficient]);
    expect(store.data.coins,35);
    expect(await store.equip('skin:jelly'),false);
    expect(await store.equip('skin:pixel'),true);
    final reloaded = ProgressStore(); await reloaded.load();
    expect(reloaded.data.skin,'pixel'); expect(reloaded.data.coins,35);
    expect(await reloaded.buy('bad-id'),PurchaseResult.unavailable);
  });
  test('unfinished runs do not pay and achievements only award once', () async {
    final store=ProgressStore();await store.load();
    final failed=await store.settle(runId:'fail',lines:0,pieces:1,stageId:1);
    expect(failed.coins,0);expect(store.data.stars,isEmpty);
    final first=await store.settle(runId:'classic',lines:1,pieces:10);
    expect(first.coins,31); // 5 line + 1 block bonus + 25 achievement
    final next=await store.settle(runId:'classic2',lines:1,pieces:10);
    expect(next.coins,6);expect(next.achievements,isEmpty);
  });
  test('Journey sessions retain mode and identity through session storage', () async {
    final game=ZenGame()..start(journeyStage:journeyStages[12]);
    final sessions=SessionStore();await sessions.save(game.saveState());
    final loaded=await sessions.load(); final restored=ZenGame();
    expect(restored.restoreState(loaded),true);
    expect(restored.stage!.id,13); expect(restored.runId,game.runId);
    expect(restored.obstacleRows,game.obstacleRows); expect(restored.paused,true);
    game.dispose();restored.dispose();
  });
  testWidgets('Journey completion, rewards, next stage, and shop previews', (tester) async {
    await loadPreviewFonts();
    await tester.binding.setSurfaceSize(const Size(412,900));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend()))));
    await tester.pump();await tester.pump();await tester.pump();
    await tester.tap(find.text('Journey · 0/30'));await tester.pump();await tester.pump(const Duration(milliseconds:350));
    expect(find.text('Play stage 1'),findsOneWidget);
    await capture(tester,'08-journey');
    await tester.tap(find.text('Play stage 1'));await tester.pump();await tester.pump(const Duration(milliseconds:350));
    final dynamic state=tester.state(find.byType(GameScreen));
    expect(state.game.stage.id,1);
    clearOne(state.game);clearOne(state.game);
    await tester.pump();await tester.pump();await tester.pump();
    expect(find.text('Stage complete!'),findsOneWidget);
    expect(find.text('+155 Block Coins'),findsOneWidget);
    await capture(tester,'09-stage-complete');
    await tester.tap(find.text('Next stage'));await tester.pump();
    expect(state.game.stage.id,2);expect(state.game.completed,false);
    await tester.tap(find.byTooltip('Pause'));await tester.pump();
    await tester.tap(find.text('Home'));await tester.pump();
    await tester.ensureVisible(find.text('Shop · 155'));await tester.tap(find.text('Shop · 155'));
    await tester.pump();await tester.pump(const Duration(milliseconds:350));
    await capture(tester,'10-shop');
    await tester.tap(find.text('120 coins · Unlock'));await tester.pump();await tester.pump(const Duration(milliseconds:250));
    await tester.tap(find.text('Unlock'));await tester.pump();await tester.pump();await tester.pump(const Duration(milliseconds:250));
    expect(state.progress.data.coins,35);
    await tester.tap(find.text('Equip'));await tester.pump();await tester.pump();
    expect(state.progress.data.skin,'pixel');
    await tester.tap(find.text('Achievements'));await tester.pump();
    await capture(tester,'11-achievements');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
