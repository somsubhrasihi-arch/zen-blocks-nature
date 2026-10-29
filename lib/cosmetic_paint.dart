import 'package:flutter/material.dart';

void paintCosmeticBlock(Canvas canvas, Rect rect, Color color, {String skin = 'glass'}) {
  if (skin == 'pixel') {
    canvas.drawRect(rect.deflate(1), Paint()..color = Color.lerp(color, Colors.black, .22)!);
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 4, rect.height * .2), Paint()..color = Color.lerp(color, Colors.white, .65)!);
    canvas.drawRect(rect.deflate(rect.width * .22), Paint()..color = color);
    canvas.drawRect(rect.deflate(1), Paint()..color = Colors.white54..style = PaintingStyle.stroke..strokeWidth = 1);
    return;
  }
  final radius = skin == 'jelly' ? rect.shortestSide * .3 : skin == 'metal' ? 2.0 : 4.0;
  final r = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius));
  canvas.drawRRect(r, Paint()..color = color.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  final colors = skin == 'metal'
    ? [Color.lerp(color, Colors.white, .8)!, Color.lerp(color, Colors.black, .2)!, Color.lerp(color, Colors.white, .65)!, color]
    : [Color.lerp(color, Colors.white, .42)!, color, Color.lerp(color, Colors.black, .32)!];
  canvas.drawRRect(r, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(rect));
  canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: .78)..style = PaintingStyle.stroke..strokeWidth = 1.2);
  if (skin == 'jelly') {
    canvas.drawOval(Rect.fromLTWH(rect.left + rect.width * .2, rect.top + 3, rect.width * .6, rect.height * .23), Paint()..color = Colors.white.withValues(alpha: .5));
  } else {
    canvas.drawLine(Offset(rect.left + 4, rect.top + 4), Offset(rect.right - 5, rect.top + 4), Paint()..color = Colors.white.withValues(alpha: .52)..strokeWidth = 1.6);
  }
}

class CosmeticPreviewPainter extends CustomPainter {
  CosmeticPreviewPainter(this.id, this.colors);
  final String id;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = (size.shortestSide / 3.3).clamp(8.0, 26.0).toDouble();
    final start = Offset((size.width - unit * 3) / 2, (size.height - unit * 2) / 2);
    if (id.startsWith('skin:')) {
      for (final p in [const Offset(0, 0), const Offset(1, 0), const Offset(2, 0), const Offset(1, 1)]) {
        paintCosmeticBlock(canvas, (start + p * unit) & Size(unit, unit), colors[0], skin: id.split(':').last);
      }
    } else if (id == 'effect:lightning') {
      for (var i = 0; i < 3; i++) {
        final x = size.width * (.25 + i * .25);
        final path = Path()..moveTo(x+8, size.height*.2)..lineTo(x-5, size.height*.5)..lineTo(x+4, size.height*.5)..lineTo(x-7, size.height*.8);
        canvas.drawPath(path, Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
    } else {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(size.center(Offset.zero), unit * (.6 + i * .42), Paint()..color = colors[i].withValues(alpha: 1-i*.2)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CosmeticPreviewPainter old) => old.id != id || old.colors != colors;
}
