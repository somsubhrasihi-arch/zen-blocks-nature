import 'package:flutter/material.dart';
import 'customization.dart';

class ArcadeButton extends StatefulWidget {
  const ArcadeButton({super.key, required this.label, required this.icon,
    required this.onPressed, required this.accent, required this.surface,
    this.primary = false, this.stacked = false, this.height = 58,
    this.semanticLabel, this.subtitle});
  final String label;
  final String? semanticLabel, subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color accent, surface;
  final bool primary, stacked;
  final double height;
  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 100);
    const ink = Color(0xFFFFFFFF);
    final base = Color.lerp(widget.accent, widget.surface, widget.primary ? .08 : .24)!;
    final radius = BorderRadius.circular(widget.label.isEmpty ? 16 : 20);
    final icon = Icon(widget.icon, color: ink, size: widget.stacked ? 28 : 24,
      shadows: const [Shadow(color: Color(0x9908182B), offset: Offset(0, 2), blurRadius: 2)]);
    final label = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink, fontSize: widget.stacked ? 10 : 15,
        shadows: const [Shadow(color: Color(0xCC08182B), offset: Offset(0, 2), blurRadius: 2)],
        fontWeight: FontWeight.w900, letterSpacing: widget.stacked ? 1.2 : .2));
    return Semantics(button: true, enabled: enabled, label: widget.semanticLabel,
      child: Opacity(opacity: enabled ? 1 : .4, child: AnimatedScale(
        duration: duration, scale: _pressed ? .965 : 1,
        child: Padding(padding: const EdgeInsets.only(bottom: 5), child: AnimatedContainer(
          duration: duration,
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(borderRadius: radius, boxShadow: [
            BoxShadow(color: Color.lerp(base, Colors.black, .58)!, offset: Offset(0, _pressed ? 1 : 5), blurRadius: 1),
            BoxShadow(color: widget.accent.withValues(alpha: enabled ? .14 : 0), blurRadius: 14, spreadRadius: -3),
          ]),
          child: Material(color: Colors.transparent, borderRadius: radius,
            child: InkWell(borderRadius: radius, onTap: widget.onPressed,
              onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              splashColor: Colors.white.withValues(alpha: .24),
              child: CustomPaint(foregroundPainter: const _ButtonShine(), child: Ink(height: widget.height - 5,
                padding: EdgeInsets.symmetric(horizontal: widget.label.isEmpty ? 0 : widget.stacked ? 6 : 12, vertical: 5),
                decoration: BoxDecoration(borderRadius: radius,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    stops: const [0, .45, 1],
                    colors: [Color.lerp(base, Colors.white, .32)!, base, Color.lerp(base, Colors.black, .23)!]),
                  border: Border.all(color: Colors.white.withValues(alpha: .42), width: 1.5)),
                child: widget.label.isEmpty ? Center(child: icon) : widget.stacked
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(height: 3), Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label))])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(width: 9), Flexible(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(fit: BoxFit.scaleDown, child: label),
                    if (widget.subtitle != null) ...[const SizedBox(height: 2), FittedBox(fit: BoxFit.scaleDown, child: Text(widget.subtitle!, maxLines: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500,
                        shadows: [Shadow(color: Color(0xAA08182B), offset: Offset(0, 1), blurRadius: 2)])))],
                  ]))]),
              )),
            ),
          ),
        )),
      )),
    );
  }
}

/// Small specular reflections and an inset rim give the buttons a soft toy finish.
class _ButtonShine extends CustomPainter {
  const _ButtonShine();
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(r);
    final rim = RRect.fromRectAndRadius(Rect.fromLTWH(3, 3, size.width - 6, size.height - 7), const Radius.circular(17));
    canvas.drawRRect(rim, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x88FFFFFF), Color(0x00FFFFFF), Color(0x44FFFFFF)],
        stops: [0, .5, 1]).createShader(Offset.zero & size));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9, 5, (size.width * .32).clamp(8, 54).toDouble(), 4), const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .38));
    canvas.drawOval(Rect.fromLTWH(size.width - 13, 7, 5, 8), Paint()..color = Colors.white.withValues(alpha: .48));
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _ButtonShine oldDelegate) => false;
}

class ArcadeIconButton extends StatelessWidget {
  const ArcadeIconButton({super.key, required this.tooltip, required this.icon,
    required this.onPressed, required this.palette});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final GamePalette palette;
  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: SizedBox(width: 44,
    child: ArcadeButton(label: '', semanticLabel: tooltip, icon: icon, onPressed: onPressed,
      accent: palette.accent, surface: palette.control, height: 44)));
}

/// The three-pixel frame has its own layout space. Board painting and clipped
/// overlays can never draw over it, including at the rounded corners.
class GameBoardFrame extends StatelessWidget {
  const GameBoardFrame({super.key, required this.palette, required this.child});
  final GamePalette palette;
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(key: const ValueKey('board-frame-capture'),
    child: Container(key: const ValueKey('playing-field-frame'), padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: palette.accent, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: palette.accent.withValues(alpha: .22), blurRadius: 10, spreadRadius: 1)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(15),
        child: ColoredBox(color: palette.board, child: child)),
    ));
}
