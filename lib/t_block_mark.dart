import 'package:flutter/material.dart';

/// Rotated golden buddy T, shared by the brand, home scene and launcher artwork.
class TBlockMark extends StatelessWidget {
  const TBlockMark({
    super.key,
    this.size = 48,
    this.color = const Color(0xFFFFC44D),
  });
  final double size;
  // Kept for source compatibility; the brand always uses its golden color.
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Golden smiling T-BLOCK logo',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const BuddyMarkPainter()),
    ),
  );
}

class BuddyMarkPainter extends CustomPainter {
  const BuddyMarkPainter();
  static const positions = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(2, 0),
    Offset(1, 1),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 3.4;
    final start = Offset(
      (size.width - unit * 3) / 2,
      (size.height - unit * 2) / 2,
    );
    for (var i = 0; i < positions.length; i++) {
      final at = start + positions[i] * unit;
      final rect = Rect.fromLTWH(at.dx, at.dy, unit * .93, unit * .93);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(0, unit * .065),
          Radius.circular(unit * .24),
        ),
        Paint()..color = const Color(0xFFDB9B34),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(unit * .24)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFDA77), Color(0xFFFFC44D)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            at.dx + unit * .16,
            at.dy + unit * .12,
            unit * .55,
            unit * .08,
          ),
          Radius.circular(unit * .05),
        ),
        Paint()..color = const Color(0xFFFFEDB1),
      );
      if (i == 1) {
        final ink = Paint()..color = const Color(0xFF41255F);
        canvas.drawCircle(
          at + Offset(unit * .31, unit * .48),
          unit * .045,
          ink,
        );
        canvas.drawCircle(
          at + Offset(unit * .64, unit * .48),
          unit * .045,
          ink,
        );
        canvas.drawArc(
          Rect.fromLTWH(
            at.dx + unit * .36,
            at.dy + unit * .54,
            unit * .23,
            unit * .18,
          ),
          0,
          3.14159,
          false,
          Paint()
            ..color = const Color(0xFF41255F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = unit * .035
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BuddyMarkPainter oldDelegate) => false;
}
