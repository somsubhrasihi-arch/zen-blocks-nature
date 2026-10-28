import 'dart:async';
import 'package:flutter/material.dart';

/// A thumbstick with a dead zone, repeating movement and one rotation per push.
class GameJoystick extends StatefulWidget {
  const GameJoystick({super.key, required this.enabled, required this.onLeft,
    required this.onRight, required this.onDown, required this.onRotate});
  final bool enabled;
  final VoidCallback onLeft, onRight, onDown, onRotate;

  @override
  State<GameJoystick> createState() => _GameJoystickState();
}

class _GameJoystickState extends State<GameJoystick> with WidgetsBindingObserver {
  Offset _offset = Offset.zero;
  int _direction = 0;
  Timer? _repeat;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant GameJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _stop(rebuild: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  void _emit() {
    if (!widget.enabled) return;
    switch (_direction) {
      case 1: widget.onLeft(); break;
      case 2: widget.onRight(); break;
      case 3: widget.onDown(); break;
      case 4: widget.onRotate(); break;
    }
  }

  void _move(Offset position) {
    if (!widget.enabled) return;
    final delta = position - const Offset(62, 62);
    final offset = delta.distance > 38 ? delta / delta.distance * 38 : delta;
    final direction = delta.distance < 14 ? 0 : delta.dx.abs() > delta.dy.abs()
        ? (delta.dx < 0 ? 1 : 2) : (delta.dy > 0 ? 3 : 4);
    setState(() => _offset = offset);
    if (direction == _direction) return;
    _repeat?.cancel();
    _direction = direction;
    if (direction == 0) return;
    _emit();
    if (direction != 4) {
      _repeat = Timer.periodic(const Duration(milliseconds: 120), (_) => _emit());
    }
  }

  void _stop({bool rebuild = true}) {
    _repeat?.cancel();
    _repeat = null;
    _direction = 0;
    _pointer = null;
    if (rebuild && mounted) {
      setState(() => _offset = Offset.zero);
    } else {
      _offset = Offset.zero;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Movement joystick',
    hint: 'Left or right to move, down to soft drop, up to rotate',
    enabled: widget.enabled,
    child: Opacity(opacity: widget.enabled ? 1 : .45, child: SizedBox(
      width: 124, height: 124,
      child: GestureDetector(
        onPanStart: (_) {},
        onPanUpdate: (_) {},
        child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!widget.enabled || _pointer != null) return;
          _pointer = event.pointer;
          _move(event.localPosition);
        },
        onPointerMove: (event) {
          if (_pointer == event.pointer) _move(event.localPosition);
        },
        onPointerUp: (event) { if (_pointer == event.pointer) _stop(); },
        onPointerCancel: (event) { if (_pointer == event.pointer) _stop(); },
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF253F78), Color(0xFF121947)]),
            border: Border.all(color: const Color(0xFF38D8FF), width: 1.5)),
          child: Stack(alignment: Alignment.center, children: [
            const Positioned(top: 7, child: Icon(Icons.rotate_right_rounded, color: Color(0xFFA9B9EE), size: 18)),
            const Positioned(left: 7, child: Icon(Icons.chevron_left, color: Color(0xFFA9B9EE), size: 18)),
            const Positioned(right: 7, child: Icon(Icons.chevron_right, color: Color(0xFFA9B9EE), size: 18)),
            const Positioned(bottom: 7, child: Icon(Icons.keyboard_arrow_down, color: Color(0xFFA9B9EE), size: 18)),
            Transform.translate(offset: _offset, child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF55EEFF), Color(0xFF6271F2)]),
                border: Border.all(color: Colors.white70),
                boxShadow: const [BoxShadow(color: Color(0x6638D8FF), blurRadius: 12)]),
              child: const Icon(Icons.drag_indicator, color: Colors.white, size: 22))),
          ]),
        ),
      )),
    )),
  );
}
