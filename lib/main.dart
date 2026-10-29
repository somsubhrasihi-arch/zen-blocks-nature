import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'joystick.dart';
import 'game_audio.dart';
import 'session_store.dart';
import 'customization.dart';
import 't_block_mark.dart';

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
  const ZenBlocksApp({super.key, this.audio});
  final GameAudio? audio;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appDisplayName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
          scaffoldBackgroundColor: forest, colorSchemeSeed: const Color(0xFF9ECFC0)),
        home: GameScreen(audio: audio),
      );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.audio});
  final GameAudio? audio;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController aurora;
  int lastLines = 0;
  late final AnimationController burst;
  bool burstVisible = false;
  Timer? burstExpiry;
  bool _foreground = true;
  bool effectsEnabled = true;
  bool joystickEnabled = true;
  final ZenGame game = ZenGame();
  late final GameAudio audio;
  bool musicEnabled = true;
  GamePalette _palette = neonPalette;
  String _musicTrack = 'aurora';
  ThemeData get _themeData => ThemeData(useMaterial3: true, brightness: Brightness.dark,
    scaffoldBackgroundColor: _palette.background.first, colorSchemeSeed: _palette.accent);
  double musicVolume = .28, effectsVolume = .8;
  int joystickRepeat = 120;
  final SessionStore sessions = SessionStore();
  Map<String, dynamic>? _savedState;
  bool _home = true, _loading = true;
  Timer? _saveDebounce;
  int _lastLocks = 0;
  Timer? timer;
  int highScore = 0;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  bool _wasOver = false;

  @override
  void initState() {
    super.initState();
    audio = widget.audio ?? GameAudio();
    unawaited(audio.prepare());
    aurora = AnimationController(vsync: this, duration: Duration(seconds: 8))..repeat();
    burst = AnimationController(vsync: this, duration: Duration(milliseconds: 650))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _hideBurst();
      });
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_onGameChanged);
    _loadSettings();
    _scheduleTick();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await sessions.load();
    if (!mounted) return;
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      soundEnabled = prefs.getBool('soundEnabled') ?? true;
      musicEnabled = prefs.getBool('musicEnabled') ?? true;
      _palette = paletteForId(prefs.getString('themeId'));
      _musicTrack = trackForId(prefs.getString('musicTrack')).id;
      vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      effectsEnabled = prefs.getBool('effectsEnabled') ?? true;
      joystickEnabled = prefs.getBool('joystickEnabled') ?? true;
      musicVolume = (prefs.getDouble('musicVolume') ?? .28).clamp(0.0, 1.0).toDouble();
      effectsVolume = (prefs.getDouble('effectsVolume') ?? .8).clamp(0.0, 1.0).toDouble();
      joystickRepeat = (prefs.getInt('joystickRepeat') ?? 120).clamp(80, 220).toInt();
      _savedState = saved;
      _loading = false;
    });
    _syncAnimations();
    _syncAudio();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', soundEnabled);
    await prefs.setBool('musicEnabled', musicEnabled);
    await prefs.setString('themeId', _palette.id);
    await prefs.setString('musicTrack', _musicTrack);
    await prefs.setBool('vibrationEnabled', vibrationEnabled);
    await prefs.setBool('effectsEnabled', effectsEnabled);
    await prefs.setBool('joystickEnabled', joystickEnabled);
    await prefs.setDouble('musicVolume', musicVolume);
    await prefs.setDouble('effectsVolume', effectsVolume);
    await prefs.setInt('joystickRepeat', joystickRepeat);
  }

  void _onGameChanged() {
    if (game.lines > lastLines) {
      if (effectsEnabled && _foreground && !game.paused) {
        burstVisible = true;
        burst.forward(from: 0);
        burstExpiry?.cancel();
        // Remove the overlay even if the animation ticker stalls on a device.
        burstExpiry = Timer(Duration(milliseconds: 700), _hideBurst);
      }
      if (vibrationEnabled) HapticFeedback.heavyImpact();
    }
    if (!game.started || game.over) {
      _hideBurst();
      burst.reset();
    }
    lastLines = game.lines;
    _syncAnimations();
    if (game.score > highScore) {
      highScore = game.score;
      SharedPreferences.getInstance().then((p) => p.setInt('highScore', highScore));
    }
    _syncAudio();
    if (game.over && !_wasOver && vibrationEnabled) HapticFeedback.mediumImpact();
    _wasOver = game.over;
    if (!_loading) {
      _saveDebounce?.cancel();
      if (!game.started || game.over || game.paused || game.piecesLocked != _lastLocks) {
        unawaited(_persistNow());
      } else {
        _saveDebounce = Timer(Duration(milliseconds: 150), () => unawaited(_persistNow()));
      }
    }
    _lastLocks = game.piecesLocked;
    if (mounted) setState(() {});
  }

  void _syncAudio() {
    unawaited(audio.sync(game, musicEnabled: musicEnabled,
      effectsEnabled: soundEnabled, foreground: _foreground && !_home,
      musicVolume: musicVolume, effectsVolume: effectsVolume, musicTrack: _musicTrack));
  }

  void _rotate() {
    final before = game.active?.cells;
    game.rotate();
    if (!identical(before, game.active?.cells)) unawaited(audio.rotate());
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
  }

  Future<void> _persistNow() {
    _saveDebounce?.cancel();
    if (_loading) return Future.value();
    _savedState = game.saveState();
    return sessions.save(_savedState);
  }

  Future<void> _startNewGame({bool confirm = true}) async {
    if (_loading) return;
    if (confirm && (game.saveState() != null || _savedState != null)) {
      final replace = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text('Start a new game?'),
        content: Text('Your current saved game will be replaced. Your personal best is kept.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('New game'))],
      ));
      if (replace != true || !mounted) return;
    }
    _saveDebounce?.cancel();
    game.reset();
    setState(() { _home = false; _savedState = null; });
    game.start();
    _scheduleTick();
    _syncAudio();
    unawaited(_persistNow());
  }

  void _continueGame() {
    if (_loading) return;
    if (!game.started || game.over) {
      if (_savedState == null || !game.restoreState(_savedState)) {
        setState(() => _savedState = null);
        return;
      }
    }
    setState(() => _home = false);
    if (game.paused) game.togglePause();
    _scheduleTick();
    _syncAudio();
  }

  void _returnHome() {
    if (game.started && !game.over && !game.paused) game.togglePause();
    unawaited(_persistNow());
    setState(() => _home = true);
    _syncAudio();
  }

  Widget _volumeSlider(String label, double value, bool enabled, ValueChanged<double> onChanged) => Column(
    children: [Text('$label · ${(value * 100).round()}%', style: TextStyle(color: _palette.muted)),
      Slider(semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
        value: value, divisions: 20, onChanged: enabled ? onChanged : null,
        onChangeEnd: (_) => _saveSettings())],
  );

  void _showHowToPlay() => showModalBottomSheet<void>(context: context, showDragHandle: true,
    isScrollControlled: true, backgroundColor: _palette.panel, builder: (context) => SafeArea(
      child: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Find your flow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Fill a complete horizontal row to clear it. Clear 10 rows to reach the next level.'),
          SizedBox(height: 16),
          Text('Joystick: hold left or right to move, pull down for a soft drop, push up once to rotate.'),
          SizedBox(height: 12),
          Text('Tap the board or ROTATE to turn a piece. DROP lands it immediately. The faint outline shows its landing position.'),
          SizedBox(height: 12),
          Text('Prefer buttons? Turn off Joystick controls in Settings. You can adjust joystick speed, music and effects volume there too.'),
          SizedBox(height: 12),
          Text('Your game saves automatically. Use Home to pause it, then Continue when you return.'),
          SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text('Got it')),
        ]))),
    ));

  Widget _buildHome() => Center(child: SingleChildScrollView(child: Padding(
    padding: EdgeInsets.all(24), child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 420),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      TBlockMark(size: 76, color: _palette.accent),
      SizedBox(height: 16),
      Text('T-BLOCK AURORA', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, letterSpacing: 2, fontWeight: FontWeight.w800)),
      Text(_palette.name.toUpperCase(), style: TextStyle(color: _palette.muted, letterSpacing: 4)),
      SizedBox(height: 12),
      Text('Find your flow, one block at a time.', style: TextStyle(color: _palette.muted)),
      SizedBox(height: 28),
      Text('PERSONAL BEST  $highScore', style: TextStyle(color: cream, fontSize: 18)),
      SizedBox(height: 24),
      if (_loading) Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
      if (_savedState != null) ...[
        Text('Saved game · Score ${_savedState!['score']} · Level ${_savedState!['level']}',
          style: TextStyle(color: _palette.muted)),
        SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _loading ? null : _continueGame, icon: Icon(Icons.play_arrow_rounded), label: Text('Continue'))),
      ],
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: _loading ? null : _startNewGame, icon: Icon(Icons.add_rounded),
        label: Text(_savedState == null ? 'Start playing' : 'Start new game'))),
      SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
        TextButton.icon(onPressed: _showHowToPlay, icon: Icon(Icons.help_outline), label: Text('How to play')),
        IconButton(tooltip: 'Settings', onPressed: _showSettings, icon: Icon(Icons.tune_rounded)),
      ]),
      SizedBox(height: 20),
      Text('Offline play · Saved on this device · v1.3.0', style: TextStyle(color: _palette.muted, fontSize: 11)),
    ])),
  )));

  void _hideBurst() {
    burstExpiry?.cancel();
    burstExpiry = null;
    burst.stop();
    if (mounted && burstVisible) setState(() => burstVisible = false);
  }

  void _syncAnimations() {
    final animate = effectsEnabled && _foreground && !game.paused;
    if (animate) {
      if (!aurora.isAnimating) aurora.repeat();
      if (burstVisible && burst.value > 0 && burst.value < 1 && !burst.isAnimating) {
        burst.forward();
      }
    } else {
      aurora.stop();
      _hideBurst();
      if (!effectsEnabled) burst.reset();
    }
  }

  void _setEffectsEnabled(bool value) {
    setState(() => effectsEnabled = value);
    _syncAnimations();
    _saveSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed && game.started && !game.paused && !game.over) {
      game.togglePause();
    }
    _syncAnimations();
    _syncAudio();
    if (!_foreground) unawaited(_persistNow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    burstExpiry?.cancel();
    _saveDebounce?.cancel();
    unawaited(_persistNow());
    aurora.dispose();
    burst.dispose();
    game.removeListener(_onGameChanged);
    game.dispose();
    unawaited(audio.dispose());
    super.dispose();
  }

  Widget _stat(String label, String value) => Expanded(child: Container(
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 9),
    decoration: BoxDecoration(gradient: LinearGradient(colors: _palette.stats), borderRadius: BorderRadius.circular(14), border: Border.all(color: _palette.accent.withValues(alpha: .4))),
    child: Column(children: [Text(label.toUpperCase(), style: TextStyle(color: _palette.muted, fontSize: 10, letterSpacing: 1.4)),
      SizedBox(height: 4), Text(value, style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w700))]),
  ));

  Widget _control(IconData icon, String label, VoidCallback action) => Expanded(
    child: Semantics(button: true, label: label, child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Material(color: _palette.control, borderRadius: BorderRadius.circular(16),
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _act(action),
          child: SizedBox(height: 62, child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, color: cream, size: 25), Text(label, style: TextStyle(fontSize: 10, color: _palette.muted))])))),
    )),
  );

  void _showSettings() => showModalBottomSheet<void>(context: context, backgroundColor: _palette.panel,
    showDragHandle: true, isScrollControlled: true, builder: (context) => StatefulBuilder(builder: (context, update) =>
      Theme(data: _themeData, child: SafeArea(child: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text('Personalize your game', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(key: ValueKey('theme-selector'), value: _palette.id, isExpanded: true,
            decoration: InputDecoration(labelText: 'Visual theme', border: OutlineInputBorder()),
            items: gamePalettes.map((theme) => DropdownMenuItem(value: theme.id, child: Row(children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(4))),
              SizedBox(width: 10), Text(theme.name),
            ]))).toList(),
            onChanged: (id) { if (id == null) return; update(() => _palette = paletteForId(id)); setState(() {}); _saveSettings(); }),
          SizedBox(height: 14),
          DropdownButtonFormField<String>(key: ValueKey('music-selector'), value: _musicTrack, isExpanded: true,
            decoration: InputDecoration(labelText: 'Music track', border: OutlineInputBorder()),
            items: musicTracks.map((track) => DropdownMenuItem(value: track.id, child: Text(track.label,
              overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (id) { if (id == null) return; update(() => _musicTrack = trackForId(id).id); setState(() {}); _syncAudio(); _saveSettings(); }),
          Padding(padding: EdgeInsets.only(top: 8), child: Text(trackForId(_musicTrack).mood,
            style: TextStyle(color: _palette.muted, fontSize: 12))),
          Text('Music changes while playing; paused games stay silent.', style: TextStyle(color: _palette.muted, fontSize: 11)),
          SwitchListTile(title: Text('Background music'), value: musicEnabled, onChanged: (v) {
            update(() => musicEnabled = v); setState(() {}); _syncAudio(); _saveSettings();
          }),
          _volumeSlider('Music volume', musicVolume, musicEnabled, (v) {
            update(() => musicVolume = v); setState(() {}); _syncAudio();
          }),
          SwitchListTile(title: Text('Game sound effects'), value: soundEnabled, onChanged: (v) {
            update(() => soundEnabled = v); setState(() {}); _syncAudio(); _saveSettings();
          }),
          _volumeSlider('Effects volume', effectsVolume, soundEnabled, (v) {
            update(() => effectsVolume = v); setState(() {}); _syncAudio();
          }),
          SwitchListTile(title: Text('Touch vibration'), value: vibrationEnabled, onChanged: (v) {
            update(() => vibrationEnabled = v); setState(() {}); _saveSettings();
          }),
          SwitchListTile(title: Text('Joystick controls'), value: joystickEnabled, onChanged: (v) {
            update(() => joystickEnabled = v); setState(() {}); _saveSettings();
          }),
          if (joystickEnabled) Column(children: [
            Text('Joystick speed · ${(100 * (220 - joystickRepeat) / 140).round()}%'),
            Slider(label: 'Joystick speed', value: (220 - joystickRepeat).toDouble(), min: 0, max: 140, divisions: 14,
              onChanged: (v) { update(() => joystickRepeat = 220 - v.round()); setState(() {}); },
              onChangeEnd: (_) => _saveSettings()),
          ]),
          SwitchListTile(title: Text('Spectacular effects'), value: effectsEnabled, onChanged: (v) {
            update(() => _setEffectsEnabled(v));
          }),
          Text('T-Block Aurora · 1.3.0', style: TextStyle(color: _palette.muted, fontSize: 12)),
          Padding(padding: EdgeInsets.all(12), child: Text('Original ambient music and game sounds are bundled for offline play. Music pauses when the game is paused or the app is in the background.',
            textAlign: TextAlign.center, style: TextStyle(color: _palette.muted, fontSize: 12))),
        ])))))));

  @override
  Widget build(BuildContext context) {
    final next = game.nextKind;
    return Theme(data: _themeData, child: PopScope(canPop: _home, onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _returnHome();
    }, child: Scaffold(body: Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _palette.background)),
      child: Stack(children: [Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: AuroraPainter(aurora, game.level, effectsEnabled, palette: _palette))))),
      SafeArea(child: _home ? _buildHome() : LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxHeight;
      final boardHeightPx = (available - (joystickEnabled ? 290 : 230)).clamp(200.0, 900.0);
      return SingleChildScrollView(child: Padding(padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(children: [
          Row(children: [TBlockMark(size: 32, color: _palette.accent),
            SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('T-BLOCK', style: TextStyle(color: cream, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text(_palette.name.toUpperCase(), style: TextStyle(color: _palette.muted, fontSize: 10, letterSpacing: 2))])),
            IconButton(tooltip: 'Settings', onPressed: _showSettings, icon: Icon(Icons.tune_rounded, color: cream)),
            IconButton(tooltip: game.paused ? 'Resume' : 'Pause', onPressed: game.togglePause,
              icon: Icon(game.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: cream))]),
          SizedBox(height: 14),
          Row(children: [_stat('Score', '${game.score}'), SizedBox(width: 8),
            _stat('Level', '${game.level}'), SizedBox(width: 8), _stat('Best', '$highScore'),
            SizedBox(width: 8), SizedBox(width: 62, child: Column(children: [
              Text('NEXT', style: TextStyle(color: _palette.muted, fontSize: 10, letterSpacing: 1.5)),
              SizedBox(height: 44, width: 62, child: CustomPaint(painter: NextPainter(next, palette: _palette))),
            ]))]),
          SizedBox(height: 12),
          Center(child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 0) _act(() => game.move(1, 0));
                if ((details.primaryVelocity ?? 0) < 0) _act(() => game.move(-1, 0));
              },
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 0) _act(game.hardDrop);
              },
              onTap: () => _act(_rotate),
              child: SizedBox(width: boardHeightPx / 2, child: AspectRatio(aspectRatio: boardWidth / boardHeight,
                child: Container(constraints: BoxConstraints(maxHeight: boardHeightPx),
                  decoration: BoxDecoration(color: _palette.board, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _palette.accent, width: 2)),
                  clipBehavior: Clip.antiAlias, child: Stack(children: [
                    RepaintBoundary(child: CustomPaint(painter: BoardPainter(game.visibleBoard, ghost: game.ghostPiece, palette: _palette), size: Size.infinite)),
                    if (burstVisible && effectsEnabled && game.canMove) Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: SparkPainter(burst, palette: _palette))))),
                    if (!game.started || game.paused || game.over)
                      Container(color: _palette.overlay, alignment: Alignment.center,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(game.over ? Icons.emoji_events_outlined : Icons.pause_circle_outline, color: _palette.muted, size: 36),
                          SizedBox(height: 8),
                          Text(game.over ? 'Aurora fades' : 'Paused',
                            style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.bold)),
                          if (game.over) ...[
                            SizedBox(height: 8),
                            Text('Score ${game.score}  ·  Best $highScore', style: TextStyle(color: cream)),
                            Text('${game.lines} lines  ·  Level ${game.level}', style: TextStyle(color: _palette.muted)),
                          ],
                          SizedBox(height: 10),
                          ElevatedButton(onPressed: () {
                            if (game.paused) { game.togglePause(); _scheduleTick(); }
                            else { _startNewGame(confirm: false); }
                          }, child: Text(game.over ? 'Play again' : 'Resume')),
                          if (game.paused) TextButton(onPressed: _startNewGame, child: Text('Restart')),
                          TextButton(onPressed: _returnHome, child: Text('Home')),
                        ])),
                  ])))),
            )),
          SizedBox(height: 14),
          if (joystickEnabled) Row(children: [
            GameJoystick(enabled: game.canMove, repeatMilliseconds: joystickRepeat,
              onLeft: () => game.move(-1, 0),
              onRight: () => game.move(1, 0),
              onDown: game.softDrop, onRotate: _rotate),
            SizedBox(width: 12),
            _control(Icons.rotate_right_rounded, 'ROTATE', _rotate),
            _control(Icons.keyboard_double_arrow_down_rounded, 'DROP', game.hardDrop),
          ]) else Row(children: [
            _control(Icons.arrow_back_rounded, 'LEFT', () => game.move(-1, 0)),
            _control(Icons.rotate_right_rounded, 'ROTATE', _rotate),
            _control(Icons.arrow_forward_rounded, 'RIGHT', () => game.move(1, 0)),
            _control(Icons.arrow_downward_rounded, 'DOWN', game.softDrop),
            _control(Icons.keyboard_double_arrow_down_rounded, 'DROP', game.hardDrop),
          ]),
        ])));
    })) ])))));
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.cells, {this.ghost, this.palette = neonPalette});
  final GamePalette palette;
  final List<List<int>> cells;
  final Piece? ghost;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / boardWidth;
    final h = size.height / boardHeight;
    final landing = ghost;
    if (landing != null) {
      final color = palette.blocks[landing.kind];
      for (var row = 0; row < landing.cells.length; row++) {
        for (var col = 0; col < landing.cells[row].length; col++) {
          final x = landing.x + col, y = landing.y + row;
          if (landing.cells[row][col] == 0 || y < 0 || y >= boardHeight || x < 0 || x >= boardWidth || cells[y][x] != 0) continue;
          final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x*w+2, y*h+2, w-4, h-4), const Radius.circular(4));
          canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .12));
          canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .65)..style = PaintingStyle.stroke..strokeWidth = 1.3);
        }
      }
    }
    final grid = Paint()..color = palette.grid..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (var y = 0; y < boardHeight; y++) {
      for (var x = 0; x < boardWidth; x++) {
        final rect = Rect.fromLTWH(x * w, y * h, w, h);
        canvas.drawRect(rect, grid);
        final v = cells[y][x];
        if (v > 0) drawBlock(canvas, rect.deflate(1), palette.blocks[v - 1]);
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
  AuroraPainter(this.animation, this.level, this.enabled, {this.palette = neonPalette}) : super(repaint: animation);
  final GamePalette palette;
  final Animation<double> animation;
  final int level;
  final bool enabled;
  @override
  void paint(Canvas canvas, Size size) {
    final phase = enabled ? animation.value * math.pi * 2 : 0.0;
    final palettes = palette.auroras;
    final colors = palettes[((level - 1) ~/ 10) % palettes.length];
    for (var i = 0; i < 3; i++) {
      final x = size.width * (.15 + i * .32) + math.sin(phase + i) * 28;
      final y = size.height * (.16 + i * .11);
      canvas.drawCircle(Offset(x, y), size.width * .46, Paint()
        ..shader = RadialGradient(colors: [colors[i % 2].withValues(alpha: .25), Colors.transparent])
            .createShader(Rect.fromCircle(center: Offset(x, y), radius: size.width * .46)));
    }
    // Visible, flowing light ribbons; repainting them does not rebuild the game UI.
    for (var ribbon = 0; ribbon < 2; ribbon++) {
      final path = Path();
      final base = size.height * (.18 + ribbon * .22);
      for (var step = 0; step <= 32; step++) {
        final x = size.width * step / 32;
        final y = base + math.sin(step / 32 * math.pi * 2 + phase + ribbon * 2) * size.height * .055;
        if (step == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.lineTo(size.width, base + size.height * .16);
      path.lineTo(0, base + size.height * .16);
      path.close();
      canvas.drawPath(path, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [colors[ribbon].withValues(alpha: .18), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, base - size.height * .055, size.width, size.height * .215)));
    }
    final star = Paint();
    for (var i = 0; i < 65; i++) {
      final x = ((i * 97 + 29) % 397) / 397 * size.width;
      final y = ((i * 131 + 17) % 601) / 601 * size.height;
      final alpha = enabled ? .35 + .3 * (1 + math.sin(phase + i * 1.7)) / 2 : .5;
      star.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.3 : .65, star);
    }
  }
  @override
  bool shouldRepaint(covariant AuroraPainter old) => old.animation != animation || old.level != level || old.enabled != enabled || old.palette != palette;
}

class SparkPainter extends CustomPainter {
  SparkPainter(this.animation, {this.palette = neonPalette}) : super(repaint: animation);
  final GamePalette palette;
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1) return;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24;
      final distance = 15 + progress * size.width * .48;
      final center = Offset(size.width / 2, size.height * .65);
      final point = center + Offset(math.cos(a) * distance, math.sin(a) * distance * .5);
      canvas.drawCircle(point, 1.5 + (1 - progress) * 2.5, Paint()..color = palette.blocks[i % palette.blocks.length].withValues(alpha: 1 - progress));
    }
  }
  @override
  bool shouldRepaint(covariant SparkPainter old) => old.animation != animation || old.palette != palette;
}

class NextPainter extends CustomPainter {
  NextPainter(this.kind, {this.palette = neonPalette});
  final GamePalette palette;
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
          Rect.fromLTWH(startX + c * unit, startY + r * unit, unit - 1, unit - 1), palette.blocks[kind!]);
      }
    }
  }
  @override
  bool shouldRepaint(covariant NextPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.palette != palette;
}
