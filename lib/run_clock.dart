import 'dart:async';
import 'package:flutter/material.dart';
import 'game.dart';
import 'play_modes.dart';

/// Rebuilds just the clock while the rest of the field stays still.
class SprintTimeText extends StatefulWidget {
  const SprintTimeText({super.key, required this.game});
  final ZenGame game;
  @override
  State<SprintTimeText> createState() => _SprintTimeTextState();
}
class _SprintTimeTextState extends State<SprintTimeText> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && widget.game.canMove) setState(() {});
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(formatRunTime(widget.game.elapsedMilliseconds),
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]));
}
