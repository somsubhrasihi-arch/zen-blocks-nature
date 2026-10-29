import 'package:flutter/material.dart';
import 'customization.dart';

class ArcadeButton extends StatefulWidget {
  const ArcadeButton({super.key, required this.label, required this.icon,
    required this.onPressed, required this.accent, required this.surface,
    this.primary = false, this.stacked = false, this.height = 58,
    this.semanticLabel});
  final String label;
  final String? semanticLabel;
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
    final ink = widget.primary ? const Color(0xFF09182B) : const Color(0xFFF6F5FF);
    final icon = Icon(widget.icon, color: ink, size: widget.stacked ? 28 : 24);
    final label = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ink, fontSize: widget.stacked ? 10 : 15,
        fontWeight: FontWeight.w800, letterSpacing: widget.stacked ? 1.2 : .2));
    return Semantics(button: true, enabled: enabled, label: widget.semanticLabel,
      child: Opacity(opacity: enabled ? 1 : .4, child: AnimatedScale(
        duration: duration, scale: _pressed ? .965 : 1,
        child: Padding(padding: const EdgeInsets.only(bottom: 5), child: AnimatedContainer(
          duration: duration,
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
            BoxShadow(color: Color.lerp(widget.accent, Colors.black, .65)!, offset: Offset(0, _pressed ? 1 : 5)),
            BoxShadow(color: widget.accent.withValues(alpha: enabled ? .14 : 0), blurRadius: 14, spreadRadius: -3),
          ]),
          child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(18),
            child: InkWell(borderRadius: BorderRadius.circular(18), onTap: widget.onPressed,
              onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              splashColor: widget.accent.withValues(alpha: .2),
              child: Ink(height: widget.height - 5,
                padding: EdgeInsets.symmetric(horizontal: widget.label.isEmpty ? 0 : widget.stacked ? 6 : 12, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: widget.primary
                      ? [Color.lerp(widget.accent, Colors.white, .32)!, widget.accent]
                      : [Color.lerp(widget.surface, widget.accent, .2)!, widget.surface]),
                  border: Border.all(color: widget.accent.withValues(alpha: widget.primary ? .9 : .5), width: 1.2)),
                child: widget.label.isEmpty ? Center(child: icon) : widget.stacked
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(height: 3), Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label))])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(width: 9), Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label))]),
              ),
            ),
          ),
        )),
      )),
    );
  }
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
