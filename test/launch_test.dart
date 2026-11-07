import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/app_info_screen.dart';
import 'package:zen_blocks/app_policy.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/progress_store.dart';
import 'package:zen_blocks/session_store.dart';
import 'fake_audio.dart';
import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  setUpAll(loadPreviewFonts);
  test('local recovery keeps purchased ownership, balance and payout receipts together',()async{
    final store=ProgressStore();await store.load();
    await store.settle(runId:'receipt',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    await store.buy('skin:pixel',equip:true);
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString(ProgressStore.backupKey),prefs.getString(ProgressStore.key));
    await prefs.setString(ProgressStore.key,'{damaged');
    final recovered=ProgressStore();await recovered.load();
    expect(recovered.recoveredFromBackup,true);expect(recovered.data.coins,35);expect(recovered.data.skin,'pixel');
    expect(recovered.data.owned,contains('skin:pixel'));
    final duplicate=await recovered.settle(runId:'receipt',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    expect(duplicate.duplicate,true);expect(recovered.data.coins,35);
    expect(jsonDecode(prefs.getString(ProgressStore.key)!)['coins'],35);
  });
  test('old valid progress gets a recovery copy without resetting its contents',()async{
    final p=PlayerProgress()..coins=90;p.stars[1]=2;
    SharedPreferences.setMockInitialValues({ProgressStore.key:jsonEncode(p.toJson())});
    final store=ProgressStore();await store.load();
    expect(store.data.coins,90);expect(store.data.stars[1],2);
    final prefs=await SharedPreferences.getInstance();expect(prefs.getString(ProgressStore.backupKey),isNotNull);
    expect(store.recoveredFromBackup,false);
  });
  test('a damaged game restores its run identity and deliberate clearing removes both copies',()async{
    final game=ZenGame()..start()..softDrop();final snapshot=game.saveState()!;
    final sessions=SessionStore();await sessions.save(snapshot);
    final prefs=await SharedPreferences.getInstance();await prefs.setString(SessionStore.key,'bad-json');
    final recovered=SessionStore();expect(await recovered.load(),snapshot);expect(recovered.recoveredFromBackup,true);
    await recovered.save(null);expect(await SessionStore().load(),isNull);
    expect(prefs.containsKey(SessionStore.backupKey),false);game.dispose();
  });
  test('a valid primary remains authoritative when its recovery record is damaged',()async{
    final game=ZenGame()..start();final snapshot=game.saveState()!;await SessionStore().save(snapshot);
    final prefs=await SharedPreferences.getInstance();await prefs.setString(SessionStore.backupKey,'bad');
    final sessions=SessionStore();expect(await sessions.load(),snapshot);expect(sessions.recoveredFromBackup,false);
    expect(jsonDecode(prefs.getString(SessionStore.backupKey)!)['runId'],snapshot['runId']);game.dispose();
  });
  test('public privacy text stays aligned with the policy available offline',(){
    final publicPolicy=File('PRIVACY_POLICY.md').readAsStringSync();
    for(final section in privacySections){expect(publicPolicy,contains(section.title));expect(publicPolicy,contains(section.body));}
    expect(privacyPolicyUrl,endsWith('/PRIVACY_POLICY.md'));
    expect(supportUrl,endsWith('/issues'));
  });
  testWidgets('guided practice teaches a row clear without changing saved game or coins',(tester)async{
    final source=ZenGame()..start()..softDrop();final saved=source.saveState()!;await SessionStore().save(saved);
    final progress=ProgressStore();await progress.load();await progress.settle(runId:'starter',lines:2,pieces:6,stageId:1,completed:true,stars:3);
    final prefs=await SharedPreferences.getInstance();final before=prefs.getString(ProgressStore.key);
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:ZenBlocksApp(audio:GameAudio(backend:FakeAudioBackend()))));await tester.pump();await tester.pump();await tester.pump();
    await tester.tap(find.text('Practice'));await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    await capture(tester,'21-guided-practice');
    await tester.tap(find.text('Left'));await tester.pump();
    await tester.ensureVisible(find.text('Next step'));await tester.tap(find.text('Next step'));await tester.pump();
    await tester.ensureVisible(find.text('Rotate'));await tester.tap(find.text('Rotate'));await tester.pump();
    await tester.ensureVisible(find.text('Next step'));await tester.tap(find.text('Next step'));await tester.pump();
    await tester.ensureVisible(find.text('Right'));
    for(var i=0;i<3;i++){await tester.tap(find.text('Right'));await tester.pump();}
    await tester.ensureVisible(find.text('Drop'));await tester.tap(find.text('Drop'));await tester.pump();
    expect(find.text('Perfect! You cleared a row.'),findsOneWidget);await capture(tester,'22-practice-complete');
    await tester.ensureVisible(find.text('Finish practice'));await tester.tap(find.text('Finish practice'));
    await tester.pump();await tester.pump(const Duration(milliseconds:700));await tester.pump();
    expect(prefs.getBool('practiceCompleted'),true);expect(prefs.getString(ProgressStore.key),before);
    expect(await SessionStore().load(),saved);expect(find.text('Continue'),findsOneWidget);expect(find.text('Practice'),findsNothing);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());source.dispose();
  });
  testWidgets('privacy is readable offline and licences are accessible',(tester)async{
    await tester.binding.setSurfaceSize(const Size(412,900));addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(key:captureKey,child:MaterialApp(debugShowCheckedModeBanner:false,
      theme:ThemeData(brightness:Brightness.dark,fontFamily:'Roboto'),home:const AppInfoScreen(palette:neonPalette))));
    await tester.pump();expect(find.text('Privacy policy'),findsOneWidget);
    await capture(tester,'23-about-privacy');
    await tester.tap(find.text('Open-source licences'));await tester.pump();await tester.pump(const Duration(milliseconds:700));
    expect(find.byType(LicensePage),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
