import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/main.dart';
import 'package:zen_blocks/game_audio.dart';
import 'fake_audio.dart';

Future<void> mountGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(412, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend())));
  await tester.pump();
  await tester.tap(find.text('Play Classic'));
  await tester.pump();
}

ZenGame gameOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(GameScreen));
  return state.game as ZenGame;
}

void clearLine(ZenGame game) {
  game.board = List.generate(boardHeight, (_) => List.filled(boardWidth, 0));
  game.board.last.fillRange(0, boardWidth, 1);
  game.board.last.fillRange(3, 7, 0);
  game.active = Piece(0, [List<int>.from(shapes[0].first)], 3, 0);
  game.hardDrop();
}

final sparkLayer = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SparkPainter);

SparkPainter sparksOf(WidgetTester tester) => tester.widgetList<CustomPaint>(
  find.byType(CustomPaint)).map((w) => w.painter).whereType<SparkPainter>().single;

void main() {
  testWidgets('line clear bursts finish once and reset on a new game', (tester) async {
    await mountGame(tester);
    final game = gameOf(tester);
    expect(sparkLayer, findsNothing);
    clearLine(game);
    expect(game.lines, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sparksOf(tester).animation.value, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sparkLayer, findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(sparkLayer, findsNothing);
    clearLine(game);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sparksOf(tester).animation.value, inExclusiveRange(0, 1));
    game.reset();
    game.start();
    await tester.pump();
    expect(sparkLayer, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pause removes a burst and resume does not replay it', (tester) async {
    await mountGame(tester);
    final game = gameOf(tester);
    clearLine(game);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sparkLayer, findsOneWidget);
    game.togglePause();
    await tester.pump();
    expect(sparkLayer, findsNothing);
    game.togglePause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(sparkLayer, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expiry removes particles even when the animation ticker stops', (tester) async {
    await mountGame(tester);
    clearLine(gameOf(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final dynamic state = tester.state(find.byType(GameScreen));
    state.burst.stop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sparkLayer, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('aurora moves without rebuilding the board and respects effects setting', (tester) async {
    await mountGame(tester);
    final board = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter);
    final before = tester.widget(board);
    final aurora = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter).whereType<AuroraPainter>().single.animation;
    final initial = aurora.value;
    await tester.pump(const Duration(milliseconds: 100));
    expect(aurora.value, isNot(initial));
    expect(identical(tester.widget(board), before), isTrue);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Line-clear effects'));
    await tester.pump();
    await tester.tap(find.text('Line-clear effects'));
    await tester.pump();
    final stopped = aurora.value;
    await tester.pump(const Duration(milliseconds: 400));
    expect(aurora.value, stopped);
    await tester.tap(find.text('Line-clear effects'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(aurora.value, stopped);
    await tester.tap(find.byTooltip('Done'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Resume'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
    expect(aurora.value, isNot(stopped));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('finished spark bursts paint no lingering ring', () async {
    Future<bool> paintsPixels(double progress) async {
      final recorder = ui.PictureRecorder();
      SparkPainter(AlwaysStoppedAnimation<double>(progress))
          .paint(Canvas(recorder), const Size(100, 200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 200);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final visible = bytes!.buffer.asUint8List().any((v) => v != 0);
      image.dispose();
      picture.dispose();
      return visible;
    }
    expect(await paintsPixels(0), isFalse);
    expect(await paintsPixels(.5), isTrue);
    expect(await paintsPixels(1), isFalse);
  });
}
