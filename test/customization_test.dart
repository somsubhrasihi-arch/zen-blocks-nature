import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/t_block_mark.dart';
import 'fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('current colors and ambient track remain defaults', () {
    expect(paletteForId(null), neonPalette);
    expect(paletteForId('unknown'), neonPalette);
    expect(neonPalette.blocks, blockColors);
    expect(trackForId(null).asset, 'audio/aurora.mp3');
    expect(trackForId('unknown').id, 'aurora');
    expect(gamePalettes.map((p) => p.id).toSet().length, 4);
    expect(musicTracks.map((p) => p.bpm).toList(), [60, 80, 105, 135]);
  });

  test('every music choice is bundled for offline playback', () async {
    for (final track in musicTracks) {
      expect((await rootBundle.load('assets/${track.asset}')).lengthInBytes, greaterThan(1000));
    }
  });

  test('track switches respect pause and do not replay game events', () async {
    final backend = FakeAudioBackend();
    final audio = GameAudio(backend: backend);
    final game = ZenGame()..start();
    await audio.sync(game, musicEnabled: true, effectsEnabled: true, foreground: true);
    final count = backend.cues.length;
    final before = game.saveState();
    await audio.sync(game, musicEnabled: true, effectsEnabled: true, foreground: true, musicTrack: 'rush');
    expect(backend.tracks.last, 'audio/neon_rush.mp3');
    expect(backend.musicStates.last, true);
    expect(backend.cues.length, count);
    expect(game.saveState(), before);
    game.togglePause();
    await audio.sync(game, musicEnabled: true, effectsEnabled: true, foreground: true, musicTrack: 'ocean');
    expect(backend.tracks.last, 'audio/ocean_pulse.mp3');
    expect(backend.musicStates.last, false);
    await audio.dispose(); game.dispose();
  });

  testWidgets('name and T-piece mark appear on the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend())));
    await tester.pump(); await tester.pump();
    expect(find.text('T-BLOCK'), findsOneWidget);
    expect(find.byType(TBlockMark), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, appDisplayName);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saved theme and track restore while preserving the score', (tester) async {
    SharedPreferences.setMockInitialValues({'themeId': 'forest', 'musicTrack': 'rush', 'highScore': 1234});
    final backend = FakeAudioBackend();
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: backend)));
    await tester.pump(); await tester.pump();
    expect(find.text(gameTagline), findsOneWidget);
    await tester.tap(find.text('Play Classic'));
    await tester.pump(); await tester.pump();
    final board = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<BoardPainter>().single;
    expect(board.palette.id, 'forest');
    expect(backend.tracks.last, 'audio/neon_rush.mp3');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('highScore'), 1234);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('theme and track selectors update and persist without changing the game', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = FakeAudioBackend();
    await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: backend)));
    await tester.pump(); await tester.pump();
    await tester.tap(find.text('Play Classic')); await tester.pump();
    await tester.tap(find.byTooltip('Pause')); await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    final saved = state.game.saveState();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    final theme = tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('theme-selector')));
    theme.onChanged!('sunset');
    await tester.pump();
    final music = tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('music-selector')));
    music.onChanged!('ocean');
    await tester.pump(); await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeId'), 'sunset');
    expect(prefs.getString('musicTrack'), 'ocean');
    expect(state.game.saveState(), saved);
    expect(backend.musicStates.last, false);
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    final board = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<BoardPainter>().single;
    expect(board.palette.id, 'sunset');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
