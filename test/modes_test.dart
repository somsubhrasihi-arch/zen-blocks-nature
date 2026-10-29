import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/campaign.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/play_modes.dart';
import 'package:zen_blocks/progress_store.dart';
import 'fake_audio.dart';
import 'journey_test.dart' show clearOne;
import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

String lineDay() {
  var day=DateTime.utc(2026,10,29);
  while(dailyForDay(utcDay(day))!.goal != StageGoal.lines) { day=day.add(const Duration(days:1)); }
  return utcDay(day);
}
Future<RunReward> winDaily(ProgressStore store,String day,String id) {
  final d=dailyForDay(day)!;
  return store.settle(runId:id,lines:d.goal==StageGoal.lines?d.target:2,pieces:30,completed:true,
    mode:PlayMode.daily,dailyDay:day,score:d.goal==StageGoal.score?d.target:0,
    obstaclesCleared:d.goal==StageGoal.excavation?d.target:0);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('Sprint finishes at 40 lines and freezes its monotonic active clock',(){
    var now=0;
    final g=ZenGame(nowMilliseconds:()=>now)..start(playMode:PlayMode.sprint);
    now=12000;expect(g.elapsedMilliseconds,12000);
    g.togglePause();now=45000;expect(g.elapsedMilliseconds,12000);
    g.togglePause();now=48000;expect(g.elapsedMilliseconds,15000);
    g.lines=39;g.level=4;clearOne(g);
    expect(g.completed,true);expect(g.goalProgress,40);expect(g.canMove,false);
    expect(g.elapsedMilliseconds,15000);now=100000;expect(g.elapsedMilliseconds,15000);
    expect(g.earnedStars,0);g.dispose();
  });
  test('Sprint resume excludes time spent closed and preserves the receipt',(){
    var now=0;final g=ZenGame(nowMilliseconds:()=>now)..start(playMode:PlayMode.sprint);
    now=23456;final snapshot=g.saveState()!;
    now=100000;final restored=ZenGame(nowMilliseconds:()=>now);
    expect(restored.restoreState(snapshot),true);expect(restored.paused,true);
    expect(restored.elapsedMilliseconds,23456);expect(restored.mode,PlayMode.sprint);
    expect(restored.runId,g.runId);now=200000;expect(restored.elapsedMilliseconds,23456);
    restored.togglePause();now+=2000;expect(restored.elapsedMilliseconds,25456);
    g.dispose();restored.dispose();
  });
  test('Daily challenge rotates goals and validates exact UTC dates',(){
    final goals=<StageGoal>{};
    for(var i=0;i<9;i++) { goals.add(dailyForDay(utcDay(DateTime.utc(2026,10,29+i)))!.goal); }
    expect(goals.length,3);expect(dailyForDay('2026-02-30'),isNull);
    expect(dailyForDay('2026-2-3'),isNull);expect(dailyForDay(null),isNull);
    expect(utcDay(DateTime.parse('2026-10-30T01:00:00+04:00')),'2026-10-29');
  });
  test('Daily seed and future bags remain identical after resuming',(){
    final day=lineDay();
    final a=ZenGame(random:Random(1))..start(playMode:PlayMode.daily,dailyDay:day);
    final b=ZenGame(random:Random(999))..start(playMode:PlayMode.daily,dailyDay:day);
    for(var i=0;i<12;i++) {
      expect(a.active!.kind,b.active!.kind);a.hardDrop();b.hardDrop();
      a.board=List.generate(20,(_)=>List.filled(10,0));b.board=List.generate(20,(_)=>List.filled(10,0));
    }
    final restored=ZenGame(random:Random(5));expect(restored.restoreState(a.saveState()),true);restored.togglePause();
    for(var i=0;i<28;i++) {
      expect(a.active!.kind,restored.active!.kind);expect(a.nextKind,restored.nextKind);
      a.hardDrop();restored.hardDrop();
      a.board=List.generate(20,(_)=>List.filled(10,0));restored.board=List.generate(20,(_)=>List.filled(10,0));
    }
    a.dispose();b.dispose();restored.dispose();
  });
  test('Daily saves retain objectives, marked rows and original date',(){
    final g=ZenGame()..start(playMode:PlayMode.daily,dailyDay:'2026-10-29');
    final saved=g.saveState();final restored=ZenGame();
    expect(restored.restoreState(saved),true);expect(restored.daily!.day,'2026-10-29');
    expect(restored.goalTarget,g.goalTarget);expect(restored.obstacleRows,g.obstacleRows);
    expect(restored.saveState(),saved);g.dispose();restored.dispose();
  });
  test('invalid new mode data leaves an existing run unchanged',(){
    final g=ZenGame()..start();final before=g.saveState();
    for(final patch in [{'mode':'bad'},{'mode':'daily','dailyDay':'2026-02-30'}, {'elapsedMs':-1},
      {'mode':'sprint','stageId':1},{'mode':'daily','dailyDay':'2026-10-29','dailyBag':-1}]) {
      final bad=jsonDecode(jsonEncode(before)) as Map<String,dynamic>..addAll(patch);
      expect(g.restoreState(bad),false);expect(g.saveState(),before);
    }
    g.dispose();
  });
  test('Daily pays once even with different receipts and concurrent completions',()async{
    final today=lineDay();final store=ProgressStore(utcNow:()=>parseDay(today)!);await store.load();
    final results=await Future.wait([winDaily(store,today,'a'),winDaily(store,today,'b')]);
    expect(results[0].details['Daily Challenge'],120);
    expect(results[1].details.containsKey('Daily Challenge'),false);
    expect(store.data.dailyWins,1);expect(store.data.dailyStreak,1);
    final reloaded=ProgressStore(utcNow:()=>parseDay(today)!);await reloaded.load();
    final replay=await winDaily(reloaded,today,'c');expect(replay.coins,0);
    expect(replay.note,contains('Practice'));expect(reloaded.data.dailyWins,1);
  });
  test('streak rewards cap, gaps reset, and rollback cannot claim old dates',()async{
    var now=DateTime.utc(2026,10,20);final store=ProgressStore(utcNow:()=>now);await store.load();
    for(var i=0;i<8;i++) {
      final result=await winDaily(store,utcDay(now),'day$i');
      expect(result.details['Daily streak']??0,(i*10).clamp(0,60));
      now=now.add(const Duration(days:1));
    }
    expect(store.data.dailyStreak,8);expect(store.data.bestDailyStreak,8);
    expect(store.data.earned,containsAll(['dailyFirst','dailySeven','streakSeven']));
    now=now.add(const Duration(days:1));
    expect(store.data.activeDailyStreak(utcDay(now)),0);
    final result=await winDaily(store,utcDay(now),'gap');expect(result.details['Daily streak'],isNull);
    expect(store.data.dailyStreak,1);
    now=now.subtract(const Duration(days:2));
    final rollback=await winDaily(store,utcDay(now),'back');
    expect(rollback.details['Daily Challenge'],isNull);expect(store.data.dailyStreak,1);
  });
  test('past saved daily challenge is practice and cannot take today’s reward',()async{
    final store=ProgressStore(utcNow:()=>DateTime.utc(2026,10,30));await store.load();
    final result=await winDaily(store,'2026-10-29','old');expect(result.details['Daily Challenge'],isNull);
    expect(store.data.dailyWins,0);expect(store.data.canClaimDaily('2026-10-30'),true);
  });
  test('Sprint pays completion, speed and PB bonuses but rejects incomplete runs',()async{
    final store=ProgressStore();await store.load();
    final failed=await store.settle(runId:'fail',lines:0,pieces:99,mode:PlayMode.sprint,elapsedMs:1000);
    expect(failed.coins,0);expect(store.data.runs,0);
    final first=await store.settle(runId:'first',lines:40,pieces:110,mode:PlayMode.sprint,completed:true,elapsedMs:290000);
    expect(first.details['Sprint finish'],60);expect(first.details['Speed bonus'],25);
    expect(first.achievements,containsAll(['Across the Finish Line','Quick Stack']));expect(store.data.sprintBestMs,290000);
    final small=await store.settle(runId:'tiny',lines:40,pieces:110,mode:PlayMode.sprint,completed:true,elapsedMs:289500);
    expect(small.details['New personal best'],isNull);expect(store.data.sprintBestMs,289500);
    final better=await store.settle(runId:'better',lines:40,pieces:110,mode:PlayMode.sprint,completed:true,elapsedMs:280000);
    expect(better.details['New personal best'],15);expect(store.data.sprintBestMs,280000);
    final reload=ProgressStore();await reload.load();expect(reload.data.sprintBestMs,280000);
  });
  test('replay pool is shared, resets on UTC day, and ignores first clears',()async{
    var now=DateTime.utc(2026,10,29);final store=ProgressStore(utcNow:()=>now);await store.load();
    await store.settle(runId:'journey',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    await store.settle(runId:'sprint1',lines:40,pieces:110,mode:PlayMode.sprint,completed:true,elapsedMs:400000);
    expect(store.data.practiceCoins,0);
    for(var i=0;i<10;i++) { await store.settle(runId:'repeat$i',lines:2,pieces:6,stageId:1,completed:true,stars:3); }
    expect(store.data.practiceCoins,100);
    final capped=await store.settle(runId:'sprint2',lines:40,pieces:110,mode:PlayMode.sprint,completed:true,elapsedMs:400000);
    expect(capped.details['Sprint finish + speed'],isNull);
    now=now.add(const Duration(days:1));
    final fresh=await store.settle(runId:'newday',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    expect(fresh.details['Replay'],12);expect(store.data.practiceCoins,12);
    now=now.subtract(const Duration(days:1));
    final back=await store.settle(runId:'rollback',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    expect(back.details['Replay'],isNull);
  });
  test('existing coins, skins, stars and achievements migrate without a reset',()async{
    SharedPreferences.setMockInitialValues({ProgressStore.key:jsonEncode({'version':1,'coins':543,'lines':20,'runs':5,
      'stars':{'1':3},'owned':['skin:pixel','effect:nova'],'earned':['firstLine'],'settled':['old-receipt'], 'skin':'pixel','effect':'nova'})});
    final store=ProgressStore();await store.load();expect(store.data.coins,543);expect(store.data.skin,'pixel');
    expect(store.data.effect,'nova');expect(store.data.stars[1],3);expect(store.data.earned,contains('firstLine'));
    final reward=await store.settle(runId:'old-receipt',lines:2,pieces:10);expect(reward.duplicate,true);
    expect(store.data.coins,543);
  });
  test('Classic no longer awards coins or run achievements for dropping blocks alone',()async{
    final store=ProgressStore();await store.load();
    final result=await store.settle(runId:'empty',lines:0,pieces:100);expect(result.coins,0);expect(store.data.runs,0);
    final clear=await store.settle(runId:'line',lines:1,pieces:100);expect(clear.details['Lines cleared'],5);
    expect(store.data.runs,1);
  });
  testWidgets('Sprint and Daily launch, fit and resume through the home screen',(tester)async{
    await loadPreviewFonts();await tester.binding.setSurfaceSize(const Size(412,900));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend()))));
    await tester.pump();await tester.pump();
    await tester.tap(find.text('Sprint'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    await capture(tester,'12-sprint-intro');
    await tester.tap(find.text('Start Sprint'));await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    final dynamic state=tester.state(find.byType(GameScreen));expect(state.game.mode,PlayMode.sprint);
    await capture(tester,'13-sprint-game');
    await tester.tap(find.byTooltip('Pause'));await tester.pump();
    final elapsed=state.game.elapsedMilliseconds as int;
    await tester.tap(find.text('Home'));await tester.pump();
    expect(state.game.elapsedMilliseconds,elapsed);
    await tester.tap(find.text('Continue'));await tester.pump();expect(state.game.mode,PlayMode.sprint);
    await tester.tap(find.byTooltip('Pause'));await tester.pump();await tester.tap(find.text('Home'));await tester.pump();
    await tester.ensureVisible(find.text('Daily Challenge'));await tester.tap(find.text('Daily Challenge'));
    await tester.pump();await tester.pump(const Duration(milliseconds:500));
    await capture(tester,'14-daily-intro');
    await tester.ensureVisible(find.text('Start challenge'));await tester.tap(find.text('Start challenge'));
    await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    await tester.tap(find.text('New game'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    expect(state.game.mode,PlayMode.daily);expect(state.game.daily.day,utcDay(DateTime.now()));
    await capture(tester,'15-daily-game');expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
