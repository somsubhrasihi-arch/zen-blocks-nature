import 'package:flutter/material.dart';

/// Axis locking separates deliberate drops from horizontal positioning.
class BoardTouchControls extends StatefulWidget {
  const BoardTouchControls({super.key, required this.enabled, required this.onRotate,
    required this.onMove, required this.onDrop, required this.child});
  final bool enabled;
  final VoidCallback onRotate, onDrop;
  final ValueChanged<int> onMove;
  final Widget child;
  @override
  State<BoardTouchControls> createState() => _BoardTouchControlsState();
}
class _BoardTouchControlsState extends State<BoardTouchControls> {
  Offset travel = Offset.zero;
  double horizontal = 0;
  int axis = 0;
  void reset() { travel = Offset.zero; horizontal = 0; axis = 0; }
  @override
  void didUpdateWidget(covariant BoardTouchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) reset();
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final step = (box.maxWidth / 10).clamp(16.0, 48.0).toDouble();
    return Semantics(label: 'Playing field', hint: 'Tap to rotate. Drag left or right to move. Swipe down to drop.',
      child: GestureDetector(behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onRotate : null,
        onPanStart: widget.enabled ? (_) => reset() : null,
        onPanUpdate: widget.enabled ? (d) {
          travel += d.delta;
          if (axis == 0 && travel.distance > 10) axis = travel.dx.abs() > travel.dy.abs() ? 1 : 2;
          if (axis == 1) {
            horizontal += d.delta.dx;
            while (horizontal.abs() >= step) {
              final direction = horizontal > 0 ? 1 : -1;
              widget.onMove(direction); horizontal -= direction * step;
            }
          }
        } : null,
        onPanEnd: widget.enabled ? (_) {
          if (axis == 2 && travel.dy >= step * 2 && travel.dy > travel.dx.abs() * 1.3) widget.onDrop();
          reset();
        } : null,
        onPanCancel: reset, child: widget.child));
  });
}
