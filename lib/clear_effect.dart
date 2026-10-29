import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'customization.dart';

class SparkPainter extends CustomPainter {
  SparkPainter(this.animation, {this.palette = neonPalette, this.effect = 'sparks'}) : super(repaint: animation);
  final GamePalette palette;
  final Animation<double> animation;
  final String effect;
  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1) return;
    if (effect == 'nova') {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(size.width / 2, size.height * .65), (progress * size.width * .5 + i * 10),
          Paint()..color = palette.blocks[i].withValues(alpha: (1-progress) * .8)..style = PaintingStyle.stroke..strokeWidth = 3*(1-progress)+1);
      }
    }
    if (effect == 'lightning') {
      for (var i = 0; i < 5; i++) {
        final x = size.width * (i + 1) / 6;
        final y = size.height * .65;
        final path = Path()..moveTo(x + 12, y - progress * 75)..lineTo(x - 7, y)..lineTo(x + 7, y)..lineTo(x - 12, y + progress * 75);
        canvas.drawPath(path, Paint()..color = palette.blocks[i].withValues(alpha: 1-progress)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
      return;
    }
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24;
      final distance = 15 + progress * size.width * .48;
      final center = Offset(size.width / 2, size.height * .65);
      final point = center + Offset(math.cos(a) * distance, math.sin(a) * distance * .5);
      canvas.drawCircle(point, 1.5 + (1 - progress) * 2.5, Paint()..color = palette.blocks[i % palette.blocks.length].withValues(alpha: 1 - progress));
    }
  }
  @override
  bool shouldRepaint(covariant SparkPainter old) => old.animation != animation || old.palette != palette || old.effect != effect;
}

