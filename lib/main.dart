import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ZenBlocksApp());
}

const forest = Color(0xFF050B28);
const panel = Color(0xFF121947);
const cream = Color(0xFFF6F5FF);
const muted = Color(0xFFA9B9EE);
const blockColors = <Color>[
  Color(0xFF00DFFF), Color(0xFFFFC247), Color(0xFFE250FF),
  Color(0xFF00F2B2), Color(0xFFFF648F), Color(0xFF598BFF),
  Color(0xFFAB72FF),
];

class ZenBlocksApp extends StatelessWidget {
  const ZenBlocksApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Zen Blocks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
          scaffoldBackgroundColor: forest, colorSchemeSeed: const Color(0xFF9ECFC0)),
        home: const GameScreen(),
      );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController aurora;
  int lastLines = 0;
  int burstSerial = 0;
  bool effectsEnabled = true;
  final ZenGame game = ZenGame();
  Timer? timer;
  int highScore = 0;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int _lastScore = 0;
  bool _wasOver = false;

  @override
  void initState() {
    super.initState();
    aurora = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_onGameChanged);
    _loadSettings();
    _scheduleTick();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      soundEnabled = prefs.getBool('soundEnabled') ?? true;
      vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      effectsEnabled = prefs.getBool('effectsEnabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', soundEnabled);
    await prefs.setBool('vibrationEnabled', vibrationEnabled);
    await prefs.setBool('effectsEnabled', effectsEnabled);
  }

  void _onGameChanged() {
    if (game.lines > lastLines) {
      burstSerial++;
      if (vibrationEnabled) HapticFeedback.heavyImpact();
    }
    lastLines = game.lines;
    if (game.score > highScore) {
      highScore = game.score;
      SharedPreferences.getInstance().then((p) => p.setInt('highScore', highScore));
    }
    if (game.score > _lastScore && soundEnabled && game.started) {
      SystemSound.play(SystemSoundType.click);
    }
    if (game.over && !_wasOver && vibrationEnabled) HapticFeedback.mediumImpact();
    _wasOver = game.over;
    _lastScore = game.score;
    if (mounted) setState(() {});
  }

  void _scheduleTick() {
    timer?.cancel();
    timer = Timer(Duration(milliseconds: game.fallMilliseconds), () {
      if (mounted) {
        game.tick();
        _scheduleTick();
      }
    });
  }

  void _act(VoidCallback action) {
    action();
    if (vibrationEnabled) HapticFeedback.selectionClick();
    _scheduleTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && game.started && !game.paused && !game.over) {
      game.togglePause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    aurora.dispose();
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  Widget _stat(String label, String value) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF172B68), Color(0xFF211044)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF5C72D9).withValues(alpha: .65))),
    child: Column(children: [Text(label.toUpperCase(), style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.4)),
      const SizedBox(height: 4), Text(value, style: const TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w700))]),
  ));

  Widget _control(IconData icon, String label, VoidCallback action) => Expanded(
    child: Semantics(button: true, label: label, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(color: const Color(0xFF18265B), borderRadius: BorderRadius.circular(16),
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _act(action),
          child: SizedBox(height: 62, child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, color: cream, size: 25), Text(label, style: const TextStyle(fontSize: 10, color: muted))])))),
    )),
  );

  void _showSettings() => showModalBottomSheet<void>(context: context, backgroundColor: panel,
    showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, update) =>
      SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min,
        children: [const Text('Aurora settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text('Gentle sound effects'), value: soundEnabled, onChanged: (v) {
            update(() => soundEnabled = v); setState(() {}); _saveSettings();
          }),
          SwitchListTile(title: const Text('Touch vibration'), value: vibrationEnabled, onChanged: (v) {
            update(() => vibrationEnabled = v); setState(() {}); _saveSettings();
          }),
          SwitchListTile(title: const Text('Spectacular effects'), value: effectsEnabled, onChanged: (v) {
            update(() => effectsEnabled = v); setState(() {}); _saveSettings();
          }),
          const Padding(padding: EdgeInsets.all(12), child: Text('Audio uses the device system click. No background music is bundled.',
            textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12))),
        ])))));

  @override
  Widget build(BuildContext context) {
    final next = game.nextKind;
    return Scaffold(body: AnimatedBuilder(animation: aurora, builder: (context, _) => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF090B31), Color(0xFF251054), Color(0xFF071638)])),
      child: Stack(children: [Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: AuroraPainter(aurora.value, game.level, effectsEnabled)))),
      SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxHeight;
      final boardHeightPx = (available - 290).clamp(250.0, 620.0);
      return SingleChildScrollView(child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, color: Color(0xFF25E5FF), size: 28),
            const SizedBox(width: 8), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('ZEN BLOCKS', style: TextStyle(color: cream, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text('NEON AURORA', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 3))])),
            IconButton(tooltip: 'Settings', onPressed: _showSettings, icon: const Icon(Icons.tune_rounded, color: cream)),
            IconButton(tooltip: game.paused ? 'Resume' : 'Pause', onPressed: game.togglePause,
              icon: Icon(game.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: cream))]),
          const SizedBox(height: 14),
          Row(children: [_stat('Score', '${game.score}'), const SizedBox(width: 8),
            _stat('Level', '${game.level}'), const SizedBox(width: 8), _stat('Best', '$highScore')]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 0) _act(() => game.move(1, 0));
                if ((details.primaryVelocity ?? 0) < 0) _act(() => game.move(-1, 0));
              },
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 0) _act(game.hardDrop);
              },
              onTap: () => _act(game.rotate),
              child: AspectRatio(aspectRatio: boardWidth / boardHeight,
                child: Container(constraints: BoxConstraints(maxHeight: boardHeightPx),
                  decoration: BoxDecoration(color: const Color(0xE8081031), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38D8FF), width: 2)),
                  clipBehavior: Clip.antiAlias, child: Stack(children: [
                    CustomPaint(painter: BoardPainter(game.visibleBoard), size: Size.infinite),
                    if (effectsEnabled && game.started) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: SparkPainter(aurora.value, burstSerial)))),
                    if (!game.started || game.paused || game.over)
                      Container(color: const Color(0xE9091030), alignment: Alignment.center,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(game.over ? Icons.emoji_events_outlined : Icons.spa_outlined, color: muted, size: 44),
                          const SizedBox(height: 12),
                          Text(game.over ? 'Aurora fades'  : game.paused ? 'Paused in starlight' : 'Light up the night',
                            textAlign: TextAlign.center, style: const TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: () => _act(() {
                            if (game.paused) { game.togglePause(); } else { game.start(); }
                          }), child: Text(game.paused ? 'Resume' : game.over ? 'Play again' : 'Start playing')),
                        ])),
                  ]))),
            ))),
            const SizedBox(width: 12),
            SizedBox(width: 86, child: Column(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [const Text('NEXT', style: TextStyle(fontSize: 11, color: muted, letterSpacing: 2)),
                  const SizedBox(height: 10), SizedBox(height: 64, width: 72,
                    child: CustomPaint(painter: NextPainter(next), size: Size.infinite))])),
              const SizedBox(height: 14), const Icon(Icons.emoji_events_outlined, color: Color(0xFFFFC247)),
              const Text('BEST', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.5)),
              Text('$highScore', style: const TextStyle(color: cream, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18), Text('10 lines\nper level', textAlign: TextAlign.center,
                style: TextStyle(color: muted.withValues(alpha: 0.8), fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _control(Icons.arrow_back_rounded, 'LEFT', () => game.move(-1, 0)),
            _control(Icons.rotate_right_rounded, 'ROTATE', game.rotate),
            _control(Icons.arrow_forward_rounded, 'RIGHT', () => game.move(1, 0)),
            _control(Icons.arrow_downward_rounded, 'DOWN', game.softDrop),
            _control(Icons.keyboard_double_arrow_down_rounded, 'DROP', game.hardDrop),
          ]),
          const SizedBox(height: 10),
          const Text('Tap board to rotate  •  Swipe down to drop',
            style: TextStyle(color: muted, fontSize: 11)),
        ])));
    })) ]))));
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.cells);
  final List<List<int>> cells;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / boardWidth;
    final h = size.height / boardHeight;
    final grid = Paint()..color = const Color(0xFF354B91)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (var y = 0; y < boardHeight; y++) {
      for (var x = 0; x < boardWidth; x++) {
        final rect = Rect.fromLTWH(x * w, y * h, w, h);
        canvas.drawRect(rect, grid);
        final v = cells[y][x];
        if (v > 0) drawBlock(canvas, rect.deflate(1), blockColors[v - 1]);
      }
    }
  }
  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

void drawBlock(Canvas canvas, Rect rect, Color color) {
  final r = RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(4));
  canvas.drawRRect(r, Paint()..color = color.withValues(alpha: .55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  canvas.drawRRect(r, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color.lerp(color, Colors.white, .42)!, color, Color.lerp(color, Colors.black, .32)!]).createShader(rect));
  canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: .78)..style = PaintingStyle.stroke..strokeWidth = 1.2);
  canvas.drawLine(Offset(rect.left + 4, rect.top + 4), Offset(rect.right - 5, rect.top + 4),
    Paint()..color = Colors.white.withValues(alpha: .52)..strokeWidth = 1.6);
}

class AuroraPainter extends CustomPainter {
  AuroraPainter(this.t, this.level, this.enabled);
  final double t;
  final int level;
  final bool enabled;
  @override
  void paint(Canvas canvas, Size size) {
    final phase = enabled ? t * math.pi * 2 : 0.0;
    final palettes = <List<Color>>[
      [const Color(0xFF00DFFF), const Color(0xFFAB47FF)],
      [const Color(0xFF00FFC8), const Color(0xFF5C89FF)],
      [const Color(0xFFFF48B7), const Color(0xFFFF9D3B)],
      [const Color(0xFFAD65FF), const Color(0xFF2E8EFF)],
      [const Color(0xFF2CF8F1), const Color(0xFFFA4CFF)],
    ];
    final colors = palettes[((level - 1) ~/ 10) % palettes.length];
    for (var i = 0; i < 3; i++) {
      final x = size.width * (.15 + i * .32) + math.sin(phase + i) * 28;
      final y = size.height * (.16 + i * .11);
      canvas.drawCircle(Offset(x, y), size.width * .46, Paint()
        ..shader = RadialGradient(colors: [colors[i % 2].withValues(alpha: .25), Colors.transparent])
            .createShader(Rect.fromCircle(center: Offset(x, y), radius: size.width * .46)));
    }
    final star = Paint()..color = Colors.white.withValues(alpha: .65);
    for (var i = 0; i < 65; i++) {
      final x = ((i * 97 + 29) % 397) / 397 * size.width;
      final y = ((i * 131 + 17) % 601) / 601 * size.height;
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.3 : .65, star);
    }
  }
  @override
  bool shouldRepaint(covariant AuroraPainter old) => old.t != t || old.level != level || old.enabled != enabled;
}

class SparkPainter extends CustomPainter {
  SparkPainter(this.t, this.serial);
  final double t;
  final int serial;
  @override
  void paint(Canvas canvas, Size size) {
    if (serial == 0) return;
    final progress = (t * 3) % 1;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24;
      final distance = 15 + progress * size.width * .48;
      final center = Offset(size.width / 2, size.height * .65);
      final point = center + Offset(math.cos(a) * distance, math.sin(a) * distance * .5);
      canvas.drawCircle(point, 1.5 + (1 - progress) * 2.5, Paint()..color = blockColors[i % blockColors.length].withValues(alpha: 1 - progress));
    }
  }
  @override
  bool shouldRepaint(covariant SparkPainter old) => old.t != t || old.serial != serial;
}

class NextPainter extends CustomPainter {
  NextPainter(this.kind);
  final int? kind;
  @override
  void paint(Canvas canvas, Size size) {
    if (kind == null) return;
    final shape = shapes[kind!];
    final unit = (size.width / 4).clamp(10.0, 18.0);
    final startX = (size.width - shape.first.length * unit) / 2;
    final startY = (size.height - shape.length * unit) / 2;
    for (var r = 0; r < shape.length; r++) {
      for (var c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) drawBlock(canvas,
          Rect.fromLTWH(startX + c * unit, startY + r * unit, unit - 1, unit - 1), blockColors[kind!]);
      }
    }
  }
  @override
  bool shouldRepaint(covariant NextPainter oldDelegate) => oldDelegate.kind != kind;
}
