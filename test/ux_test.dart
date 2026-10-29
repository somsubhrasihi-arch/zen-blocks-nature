import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/board_touch.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/journey_ui.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/progress_store.dart';
import 'fake_audio.dart';
import 'journey_test.dart' show clearOne;
import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  setUpAll(loadPreviewFonts);
  testWidgets('board taps rotate, drags move, deliberate swipes drop and short swipes do not',(tester)async{
    var rotations=0,moves=0,drops=0;
    await tester.pumpWidget(MaterialApp(home:Center(child:SizedBox(width:300,height:500,
      child:BoardTouchControls(enabled:true,onRotate:()=>rotations++,onMove:(dx)=>moves+=dx,onDrop:()=>drops++,child:const ColoredBox(color:Colors.blue))))));
    final board=find.byType(BoardTouchControls);
    await tester.tap(board);expect(rotations,1);
    await tester.drag(board,const Offset(100,0));expect(moves,greaterThan(0));expect(drops,0);
    await tester.drag(board,const Offset(0,140));expect(drops,1);
    await tester.drag(board,const Offset(0,25));expect(drops,1);
    final touch=await tester.startGesture(tester.getCenter(board));
    await touch.moveBy(const Offset(80,0));await touch.moveBy(const Offset(30,150));await touch.up();expect(drops,1);
  });
  testWidgets('disabled board ignores taps and swipes',(tester)async{
    var actions=0;
    await tester.pumpWidget(MaterialApp(home:Center(child:SizedBox(width:300,height:500,
      child:BoardTouchControls(enabled:false,onRotate:()=>actions++,onMove:(_)=>actions++,onDrop:()=>actions++,child:const ColoredBox(color:Colors.blue))))));
    await tester.tap(find.byType(BoardTouchControls));await tester.drag(find.byType(BoardTouchControls),const Offset(0,160));expect(actions,0);
  });
  testWidgets('settings pause Sprint and leave an explicit Resume action',(tester)async{
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend())));await tester.pump();await tester.pump();
    await tester.tap(find.text('Sprint'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    await tester.tap(find.text('Start Sprint'));await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    final dynamic state=tester.state(find.byType(GameScreen));
    await tester.tap(find.byTooltip('Settings'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    expect(state.game.paused,true);final elapsed=state.game.elapsedMilliseconds;final pieceY=state.game.active.y;
    await tester.pump(const Duration(seconds:3));expect(state.game.elapsedMilliseconds,elapsed);expect(state.game.active.y,pieceY);
    await tester.tap(find.byTooltip('Done'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    expect(find.text('Paused'),findsOneWidget);expect(find.text('Resume'),findsOneWidget);
    await tester.tap(find.text('Resume'));await tester.pump();expect(state.game.paused,false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('touch controls work on the actual field without breaking pause buttons',(tester)async{
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend())));await tester.pump();await tester.pump();
    await tester.tap(find.text('Play Classic'));await tester.pump();
    final dynamic state=tester.state(find.byType(GameScreen));final game=state.game as ZenGame;
    game.active=Piece(2,shapes[2].map((r)=>List<int>.from(r)).toList(),3,2);game.notifyListeners();await tester.pump();
    await tester.tap(find.byType(BoardTouchControls));await tester.pump();expect(game.active!.cells.length,3);
    final x=game.active!.x;await tester.drag(find.byType(BoardTouchControls),const Offset(80,0));await tester.pump();expect(game.active!.x,greaterThan(x));
    await tester.drag(find.byType(BoardTouchControls),const Offset(0,150));await tester.pump();expect(game.piecesLocked,1);
    await tester.tap(find.byTooltip('Pause'));await tester.pump();await tester.tap(find.text('Resume'));await tester.pump();expect(game.canMove,true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('Journey recommends the next unlocked stage or a star improvement when gated',(){
    final p=PlayerProgress();expect(p.recommendedStage!.id,1);p.stars[1]=3;expect(p.recommendedStage!.id,2);
    for(var i=1;i<=10;i++) {p.stars[i]=1;}
    expect(p.recommendedStage!.world,0);p.stars[1]=3;expect(p.recommendedStage!.id,11);
    for(var i=1;i<=30;i++) {p.stars[i]=3;}expect(p.recommendedStage,isNull);
  });
  test('buy-and-equip commits ownership, selection and balance together',()async{
    final store=ProgressStore();await store.load();await store.settle(runId:'earn',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    expect(await store.buy('skin:pixel',equip:true),PurchaseResult.purchased);expect(store.data.coins,35);
    final reloaded=ProgressStore();await reloaded.load();expect(reloaded.data.skin,'pixel');expect(reloaded.data.owned,contains('skin:pixel'));
    expect(await reloaded.buy('skin:metal',equip:true),PurchaseResult.insufficient);expect(reloaded.data.skin,'pixel');expect(reloaded.data.coins,35);
  });
  testWidgets('locked cosmetic previews do not spend coins and filters stay useful',(tester)async{
    final store=ProgressStore();await store.load();
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:MaterialApp(debugShowCheckedModeBanner:false, theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,fontFamily:'Roboto',colorSchemeSeed:neonPalette.accent), home:AdventureHub(palette:neonPalette,progress:store,onStage:(_){},initialTab:1))));await tester.pump();
    final previews=find.text('Preview');await tester.ensureVisible(previews.at(2));await tester.tap(previews.at(2));
    await tester.pump();await tester.pump(const Duration(milliseconds:500));
    expect(find.text('Jelly Gems'),findsWidgets);expect(store.data.coins,0);expect(store.data.skin,'glass');
    await capture(tester,'18-cosmetic-preview');
    await tester.tap(find.text('Close preview'));await tester.pump();await tester.pump(const Duration(milliseconds:500));
    await tester.scrollUntilVisible(find.text('Owned'), -250, scrollable: find.byType(Scrollable).first);await tester.tap(find.text('Owned'));await tester.pump();
    expect(find.text('Pixel Pop'),findsNothing);expect(find.text('Neon Glass'),findsOneWidget);
    await tester.tap(find.text('Affordable'));await tester.pump();expect(find.text('A little more play, a new look'),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
  testWidgets('Reduce motion persists and stops background and clear animations',(tester)async{
    SharedPreferences.setMockInitialValues({'reduceMotion':true});
    await tester.pumpWidget(ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend())));await tester.pump();await tester.pump();
    final dynamic state=tester.state(find.byType(GameScreen));expect(state.reduceMotion,true);expect(state.aurora.isAnimating,false);
    await tester.tap(find.text('Play Classic'));await tester.pump();clearOne(state.game);await tester.pump();
    expect(state.burstVisible,false);expect(state.aurora.isAnimating,false);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('compact phone with large text keeps home and shop usable',(tester)async{
    tester.platformDispatcher.textScaleFactorTestValue=1.5;addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(360,640));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend()))));await tester.pump();await tester.pump();
    expect(tester.takeException(),isNull);await capture(tester,'19-home-small-large-text');
    await tester.ensureVisible(find.text('Shop · 0'));await tester.tap(find.text('Shop · 0'));
    await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    expect(tester.takeException(),isNull);await capture(tester,'20-shop-small-large-text');await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Journey has a direct next-stage shortcut and world browsing',(tester)async{
    final store=ProgressStore();await store.load();
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));var launched=0;
    await tester.pumpWidget(MaterialApp(home:AdventureHub(palette:neonPalette,progress:store,onStage:(s)=>launched=s.id)));await tester.pump();
    expect(find.text('Continue Journey'),findsOneWidget);
    await tester.ensureVisible(find.text('Prism Peaks'));await tester.tap(find.text('Prism Peaks'));await tester.pump();
    expect(find.text('New Heights'),findsOneWidget);expect(find.text('First Steps'),findsNothing);
    await tester.ensureVisible(find.text('Continue Journey'));await tester.tap(find.text('Continue Journey'));await tester.pump();expect(launched,1);
    await tester.pumpWidget(const SizedBox.shrink());store.dispose();
  });
}
