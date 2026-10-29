import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'fake_audio.dart';

void fillLine(ZenGame game) {
  game.board = List.generate(boardHeight, (_) => List.filled(boardWidth, 0));
  game.board.last.fillRange(0, boardWidth, 1);
  game.board.last.fillRange(3, 7, 0);
  game.active = Piece(0, [List<int>.from(shapes[0].first)], 3, 0);
  game.hardDrop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completed locks and clears produce one appropriate cue each', () {
    final game = ZenGame();
    final tracker = GameSoundTracker();
    expect(tracker.update(game), isEmpty);
    game.start();
    expect(tracker.update(game), [SoundCue.start]);
    game.move(1, 0);
    game.softDrop();
    expect(tracker.update(game), isEmpty);
    game.hardDrop();
    expect(tracker.update(game), [SoundCue.lock]);
    expect(tracker.update(game), isEmpty);
    fillLine(game);
    expect(tracker.update(game), [SoundCue.clear]);
    game.lines = 9;
    tracker.update(game);
    fillLine(game);
    expect(tracker.update(game), [SoundCue.levelUp]);
    game.over = true;
    expect(tracker.update(game), [SoundCue.gameOver]);
    expect(tracker.update(game), isEmpty);
    game.reset();
    tracker.update(game);
    game.start();
    expect(tracker.update(game), [SoundCue.start]);
    game.dispose();
  });

  test('music and effects mute independently and pause in background', () async {
    final backend = FakeAudioBackend();
    final audio = GameAudio(backend: backend);
    final game = ZenGame()..start();
    Future<void> sync({bool music = true, bool effects = true, bool foreground = true}) =>
      audio.sync(game, musicEnabled: music, effectsEnabled: effects, foreground: foreground);
    await sync();
    expect(backend.musicStates, [true]);
    expect(backend.cues, [SoundCue.start]);
    game.hardDrop();
    await sync(music: false);
    expect(backend.musicStates.last, false);
    expect(backend.cues.last, SoundCue.lock);
    await sync(effects: false);
    expect(backend.musicStates.last, true);
    final count = backend.cues.length;
    game.hardDrop();
    await sync(effects: false);
    expect(backend.cues.length, count);
    expect(backend.stops, greaterThan(0));
    await sync(foreground: false);
    expect(backend.musicStates.last, false);
    await sync();
    expect(backend.musicStates.last, true);
    game.togglePause();
    await sync();
    expect(backend.musicStates.last, false);
    game.togglePause();
    await sync();
    expect(backend.musicStates.last, true);
    await audio.rotate();
    expect(backend.cues.last, SoundCue.rotate);
    game.over = true;
    await sync();
    expect(backend.musicStates.last, false);
    expect(backend.cues.last, SoundCue.gameOver);
    final stopsBeforeBackground = backend.stops;
    await sync(foreground: false);
    expect(backend.stops, greaterThan(stopsBeforeBackground));
    await audio.dispose();
    expect(backend.disposed, true);
    game.dispose();
  });

  test('all original audio cues are bundled', () async {
    for (final name in ['aurora', ...SoundCue.values.map((cue) => cue.name)]) {
      final data = await rootBundle.load('assets/audio/$name.mp3');
      expect(data.lengthInBytes, greaterThan(1000));
    }
  });

  testWidgets('board has larger cells and controls fit a phone viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend())));
    await tester.pump();
    await tester.tap(find.text('Play Classic'));
    await tester.pump();
    final board = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter);
    final size = tester.getSize(board);
    expect(size.height, greaterThan(590));
    expect(size.width, greaterThan(290));
    expect(size.width / size.height, closeTo(.5, .01));
    expect(tester.getBottomRight(find.text('DROP')).dy, lessThanOrEqualTo(900));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
