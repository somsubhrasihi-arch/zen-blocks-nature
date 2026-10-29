import 'package:flutter/material.dart';

/// The game's four-square T piece, also used as the Android launcher mark.
class TBlockMark extends StatelessWidget {
  const TBlockMark({super.key, this.size = 48, this.color = const Color(0xFF38D8FF)});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(label: 'T-shaped block logo', image: true,
    child: SizedBox(width: size, height: size, child: CustomPaint(painter: _TMarkPainter(color))));
}

class _TMarkPainter extends CustomPainter {
  _TMarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 3.5;
    for (final position in const [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(1, 1)]) {
      final rect = Rect.fromLTWH(size.width*.07 + position.dx*unit, size.height*.2 + position.dy*unit, unit*.88, unit*.88);
      final block = RRect.fromRectAndRadius(rect, Radius.circular(unit*.13));
      canvas.drawRRect(block, Paint()..color = color.withValues(alpha: .3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawRRect(block, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .4)!, color, const Color(0xFF6856CE)]).createShader(rect));
      canvas.drawRRect(block, Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }
  @override
  bool shouldRepaint(covariant _TMarkPainter old) => old.color != color;
}
