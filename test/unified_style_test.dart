import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/playful_style.dart';
import 'package:zen_blocks/t_block_mark.dart';

void main() {
  test(
    'every piece palette shares cream surfaces and readable purple text',
    () {
      for (final original in gamePalettes) {
        final p = original.playful;
        expect(p.id, original.id);
        expect(p.blocks, original.blocks);
        expect(p.panel, buddyCream);
        expect(p.board, buddyCream);
        expect(buddyTheme(p).brightness, Brightness.light);
        expect(buddyInk.computeLuminance(), lessThan(.1));
        expect(p.panel.computeLuminance(), greaterThan(.9));
      }
    },
  );
  testWidgets('golden buddy has a top bar and downward stem', (tester) async {
    const key = ValueKey('brand-capture');
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 102,
              height: 102,
              child: CustomPaint(painter: BuddyMarkPainter()),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      int alpha(int x, int y) => bytes[(y * image.width + x) * 4 + 3];
      for (final x in [18, 48, 78]) {
        expect(alpha(x, 30), 255);
      }
      expect(alpha(48, 65), 255);
      expect(alpha(18, 65), 0);
      expect(alpha(78, 65), 0);
      image.dispose();
    });
  });
}
