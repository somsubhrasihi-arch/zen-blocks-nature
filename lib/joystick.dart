import 'dart:async';
import 'package:flutter/material.dart';

/// A thumbstick with a dead zone, repeating movement and one rotation per push.
class GameJoystick extends StatefulWidget {
  const GameJoystick({super.key, required this.enabled, required this.onLeft,
    required this.onRight, required this.onDown, required this.onRotate,
    this.repeatMilliseconds = 120, this.size = 124,
    this.accent = const Color(0xFF38D8FF), this.surface = const Color(0xFF121947),
    this.muted = const Color(0xFFA9B9EE)});
  final bool enabled;
  final VoidCallback onLeft, onRight, onDown, onRotate;
  final int repeatMilliseconds;
  final double size;
  final Color accent, surface, muted;

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
    else if (oldWidget.repeatMilliseconds != widget.repeatMilliseconds && _direction > 0 && _direction != 4) {
      _repeat?.cancel();
      _repeat = Timer.periodic(Duration(milliseconds: widget.repeatMilliseconds.clamp(80, 220).toInt()), (_) => _emit());
    }
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
    final delta = position - Offset(widget.size / 2, widget.size / 2);
    final radius = widget.size * .30645;
    final offset = delta.distance > radius ? delta / delta.distance * radius : delta;
    final direction = delta.distance < widget.size * .113 ? 0 : delta.dx.abs() > delta.dy.abs()
        ? (delta.dx < 0 ? 1 : 2) : (delta.dy > 0 ? 3 : 4);
    setState(() => _offset = offset);
    if (direction == _direction) return;
    _repeat?.cancel();
    _direction = direction;
    if (direction == 0) return;
    _emit();
    if (direction != 4) {
      _repeat = Timer.periodic(Duration(milliseconds: widget.repeatMilliseconds.clamp(80, 220).toInt()), (_) => _emit());
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
      width: widget.size, height: widget.size,
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
            gradient: RadialGradient(colors: [Color.lerp(widget.surface, widget.accent, .18)!, widget.surface]),
            boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: .2), blurRadius: 12)],
            border: Border.all(color: widget.accent, width: 1.5)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(top: 7, child: Icon(Icons.rotate_right_rounded, color: widget.muted, size: 18)),
            Positioned(left: 7, child: Icon(Icons.chevron_left, color: widget.muted, size: 18)),
            Positioned(right: 7, child: Icon(Icons.chevron_right, color: widget.muted, size: 18)),
            Positioned(bottom: 7, child: Icon(Icons.keyboard_arrow_down, color: widget.muted, size: 18)),
            Transform.translate(offset: _offset, child: Container(
              width: widget.size * .371, height: widget.size * .371,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color.lerp(widget.accent, Colors.white, .3)!, Color.lerp(widget.accent, widget.surface, .4)!]),
                border: Border.all(color: Colors.white70),
                boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: .4), blurRadius: 12)]),
              child: const Icon(Icons.control_camera_rounded, color: Colors.white, size: 22))),
          ]),
        ),
      )),
    )),
  );
}
