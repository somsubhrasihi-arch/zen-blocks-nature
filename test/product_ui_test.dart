import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/arcade_ui.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/game.dart';
import 'package:zen_blocks/game_audio.dart';
import 'package:zen_blocks/main.dart';
import 'fake_audio.dart';

const captureKey = ValueKey('product-capture');

Future<void> loadPreviewFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) {
      final bytes = File(path).readAsBytesSync();
      await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      break;
    }
  }
  try {
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  } catch (_) {
    // The engine may already have loaded the bundled icon font.
  }
}

Future<void> mount(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RepaintBoundary(key: captureKey,
    child: ZenBlocksApp(audio: GameAudio(backend: FakeAudioBackend()))));
  await tester.pump(); await tester.pump();
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-previews')..createSync(recursive: true);
    File('${directory.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPreviewFonts);

  for (final size in [const Size(360, 640), const Size(393, 850), const Size(412, 900), const Size(480, 960)]) {
    testWidgets('board and controls fit ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await mount(tester, size);
      await tester.tap(find.text('Start playing')); await tester.pump();
      final frame = tester.getRect(find.byKey(const ValueKey('playing-field-frame')));
      final board = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter));
      expect(frame.left, greaterThanOrEqualTo(8));
      expect(frame.right, lessThanOrEqualTo(size.width - 8));
      expect(board.left - frame.left, closeTo(3, .01));
      expect(frame.right - board.right, closeTo(3, .01));
      expect(board.top - frame.top, closeTo(3, .01));
      expect(frame.bottom - board.bottom, closeTo(3, .01));
      expect(board.width / board.height, closeTo(.5, .001));
      expect(tester.getBottomRight(find.text('DROP')).dy, lessThan(size.height));
      if (size.height == 900) expect(board.height, greaterThan(630));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('larger text keeps the field and controls on screen', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, const Size(393, 850));
    await tester.tap(find.text('Start playing')); await tester.pump();
    final frame = tester.getRect(find.byKey(const ValueKey('playing-field-frame')));
    expect(frame.top, greaterThan(0));
    expect(frame.bottom, lessThan(tester.getTopLeft(find.text('DROP')).dy));
    expect(tester.getBottomRight(find.text('DROP')).dy, lessThan(850));
    expect(tester.takeException(), isNull);
    await capture(tester, '06-game-large-text');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await capture(tester, '07-settings-large-text');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('board border paints continuously on all four sides', (tester) async {
    await mount(tester, const Size(412, 900));
    await tester.tap(find.text('Start playing')); await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board-frame-capture')));
      final image = await boundary.toImage();
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final expected = [56, 216, 255, 255];
      for (final point in [Offset(image.width/2, 1), Offset(1, image.height/2),
        Offset((image.width-2).toDouble(), image.height/2), Offset(image.width/2, (image.height-2).toDouble())]) {
        final index = (point.dy.floor()*image.width + point.dx.floor())*4;
        expect(data.sublist(index, index+4), expected);
      }
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('arcade buttons respond to press and keep their action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 220,
      child: ArcadeButton(label: 'Play', icon: Icons.play_arrow_rounded, onPressed: () => taps++,
        accent: neonPalette.accent, surface: neonPalette.control, primary: true)))));
    final touch = await tester.startGesture(tester.getCenter(find.text('Play')));
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, lessThan(1));
    await touch.up(); await tester.pump(const Duration(milliseconds: 110));
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('capture product screens and verify final copy', (tester) async {
    await mount(tester, const Size(412, 900));
    expect(find.text('T-BLOCK'), findsOneWidget);
    expect(find.text(gameTagline), findsOneWidget);
    expect(find.text('NEON AURORA'), findsNothing);
    await capture(tester, '01-home');
    await tester.tap(find.text('Start playing')); await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    state.game.board[19] = [1, 1, 0, 4, 4, 5, 5, 0, 7, 7];
    state.game.board[18] = [0, 0, 0, 4, 0, 5, 0, 0, 7, 0];
    state.game.active = Piece(2, shapes[2].map((row) => List<int>.from(row)).toList(), 3, 6);
    state.game.notifyListeners();
    await tester.pump();
    await capture(tester, '02-game');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('original default'), findsNothing);
    expect(find.textContaining('bundled for offline play'), findsNothing);
    expect(find.textContaining('paused games stay silent'), findsNothing);
    await capture(tester, '03-settings');
    await tester.tap(find.byKey(const ValueKey('theme-selector')));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    await capture(tester, '04-theme-menu');
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pump(); await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(find.text('T-BLOCK • 1.6.0'), 250, scrollable: find.byType(Scrollable).last); await tester.pump();
    await capture(tester, '05-settings-controls');
    expect(find.text('Settings'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
