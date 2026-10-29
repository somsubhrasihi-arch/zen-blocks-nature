import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/session_store.dart';
import 'fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save restores rotated piece, board, score and remaining queue', () {
    final source = ZenGame()..start()..hardDrop()..rotate()..move(-1, 0)..softDrop();
    final saved = source.saveState()!;
    final restored = ZenGame();
    expect(restored.restoreState(jsonDecode(jsonEncode(saved))), true);
    expect(restored.paused, true);
    expect(restored.canMove, false);
    expect(restored.saveState(), saved);
    restored.togglePause();
    source.hardDrop();
    restored.hardDrop();
    expect(restored.visibleBoard, source.visibleBoard);
    expect(restored.nextKind, source.nextKind);
    expect(restored.score, source.score);
    source.dispose(); restored.dispose();
  });

  test('invalid save leaves the game untouched', () {
    final game = ZenGame()..start();
    final before = game.saveState();
    final invalid = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
    invalid['board'][0][0] = 99;
    expect(game.restoreState(invalid), false);
    expect(game.saveState(), before);
    invalid['board'][0][0] = 0;
    invalid['piece']['cells'] = [[1, 1, 1, 1, 1]];
    expect(game.restoreState(invalid), false);
    expect(game.restoreState({'version': 22}), false);
    expect(game.restoreState(null), false);
    expect(game.saveState(), before);
    game.dispose();
  });

  test('landing preview matches the eventual hard drop', () {
    final game = ZenGame()..start();
    final landing = game.ghostPiece!;
    final expected = <String>{};
    for (var r = 0; r < landing.cells.length; r++) {
      for (var c = 0; c < landing.cells[r].length; c++) {
        if (landing.cells[r][c] != 0) expected.add('${landing.x+c},${landing.y+r}');
      }
    }
    final beforeY = game.active!.y;
    expect(game.ghostPiece!.y, greaterThan(beforeY));
    expect(game.active!.y, beforeY);
    game.hardDrop();
    final actual = <String>{};
    for (var y = 0; y < boardHeight; y++) {
      for (var x = 0; x < boardWidth; x++) {
        if (game.board[y][x] > 0) actual.add('$x,$y');
      }
    }
    expect(actual, expected);
    game.dispose();
  });

  test('ordered saves keep latest progress and remove corrupt data', () async {
    SharedPreferences.setMockInitialValues({SessionStore.key: 'broken json'});
    final store = SessionStore();
    expect(await store.load(), isNull);
    final game = ZenGame()..start();
    final old = game.saveState();
    game.softDrop();
    final latest = game.saveState();
    final firstWrite = store.save(old);
    final lastWrite = store.save(latest);
    await Future.wait([firstWrite, lastWrite]);
    expect(await store.load(), latest);
    await store.save(null);
    expect(await store.load(), isNull);
    game.dispose();
  });

  testWidgets('continue restores a saved game and home pauses it', (tester) async {
    final source = ZenGame()..start()..softDrop();
    final saved = source.saveState()!;
    SharedPreferences.setMockInitialValues({SessionStore.key: jsonEncode(saved)});
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend())));
    await tester.pump();
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    expect(state.game.saveState(), saved);
    expect(state.game.paused, false);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
    expect(state.game.paused, true);
    await tester.tap(find.text('Start new game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(state.game.saveState(), saved);
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
  });

  testWidgets('rapid control taps do not postpone gravity', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend())));
    await tester.pump(); await tester.pump();
    await tester.tap(find.text('Play Classic')); await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('ROTATE'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.game.active.y as int, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('volume updates stay independent and zero volume mutes', () async {
    final backend = FakeAudioBackend();
    final audio = GameAudio(backend: backend);
    final game = ZenGame()..start();
    await audio.sync(game, musicEnabled: true, effectsEnabled: true, foreground: true,
      musicVolume: .5, effectsVolume: .2);
    expect(backend.levels.last, [.5, .2]);
    expect(backend.musicStates.last, true);
    final cues = backend.cues.length;
    await audio.sync(game, musicEnabled: true, effectsEnabled: true, foreground: true,
      musicVolume: 0, effectsVolume: 0);
    expect(backend.musicStates.last, false);
    await audio.rotate();
    expect(backend.cues.length, cues);
    await audio.dispose(); game.dispose();
  });

  testWidgets('volume sliders change playback and persist settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeAudioBackend();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: backend)));
    await tester.pump(); await tester.pump();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    final slider = tester.widgetList<Slider>(find.byType(Slider)).first;
    slider.onChanged!(.6);
    slider.onChangeEnd!(.6);
    await tester.pump(); await tester.pump();
    expect(backend.levels.last.first, .6);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('musicVolume'), .6);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
