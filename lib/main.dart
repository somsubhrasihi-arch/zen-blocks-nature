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
import 'arcade_ui.dart';
import 'campaign.dart';
import 'progress_store.dart';
import 'journey_ui.dart';
import 'cosmetic_paint.dart';
import 'play_modes.dart';
import 'run_clock.dart';

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
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Roboto',
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
    scaffoldBackgroundColor: _palette.background.first, colorSchemeSeed: _palette.accent,
    fontFamily: 'Roboto', sliderTheme: SliderThemeData(trackHeight: 5,
      activeTrackColor: _palette.accent, inactiveTrackColor: _palette.accent.withValues(alpha: .16),
      thumbColor: _palette.accent, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 16)));
  double musicVolume = .28, effectsVolume = .8;
  int joystickRepeat = 120;
  final SessionStore sessions = SessionStore();
  final ProgressStore progress = ProgressStore();
  RunReward? _runReward;
  String? _settlingRun, _rewardError;
  bool _settling = false;

  void _progressChanged() { if (mounted) setState(() {}); }
  void _openHub([int tab = 0]) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Theme(data: _themeData,
      child: AdventureHub(palette: _palette, progress: progress, initialTab: tab,
        onStage: (stage) => _startNewGame(journeyStage: stage)))));
  }
  Future<void> _settleFinished() async {
    if ((!game.over && !game.completed) || _settlingRun == game.runId) return;
    final id = game.runId;
    _settlingRun = id; _settling = true; _rewardError = null;
    try {
      final reward = await progress.settle(runId: id, lines: game.lines, pieces: game.piecesLocked,
        stageId: game.stage?.id, completed: game.completed, stars: game.earnedStars,
        mode: game.mode, dailyDay: game.daily?.day, elapsedMs: game.elapsedMilliseconds,
        score: game.score, obstaclesCleared: game.obstaclesCleared);
      if (mounted && game.runId == id) setState(() { _runReward = reward; _settling = false; });
    } catch (_) {
      if (mounted && game.runId == id) setState(() {
        _settlingRun = null; _settling = false; _rewardError = 'Your reward could not be saved.';
      });
    }
  }
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
    progress.addListener(_progressChanged);
    _loadSettings();
    _scheduleTick();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await sessions.load();
    await progress.load();
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
    if (!game.started || game.over || game.completed) {
      _hideBurst();
      burst.reset();
    }
    lastLines = game.lines;
    _syncAnimations();
    if (game.mode == PlayMode.classic && game.score > highScore) {
      highScore = game.score;
      SharedPreferences.getInstance().then((p) => p.setInt('highScore', highScore));
    }
    _syncAudio();
    if (game.over && !_wasOver && vibrationEnabled) HapticFeedback.mediumImpact();
    _wasOver = game.over;
    if (game.over || game.completed) unawaited(_settleFinished());
    if (!_loading) {
      _saveDebounce?.cancel();
      if (!game.started || game.over || game.completed || game.paused || game.piecesLocked != _lastLocks) {
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

  Future<void> _startNewGame({bool confirm = true, JourneyStage? journeyStage, PlayMode playMode = PlayMode.classic, String? dailyDay}) async {
    if (_loading || _settling || _rewardError != null) return;
    if (journeyStage != null && !progress.data.unlocked(journeyStage)) return;
    if (confirm && (game.saveState() != null || _savedState != null)) {
      final replace = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text('Start a new game?'),
        content: Text('Your current saved game will be replaced. Your personal best is kept.'),
        actions: [Row(children: [Expanded(child: _button('Cancel', Icons.close_rounded, () => Navigator.pop(context, false), height: 48)),
          SizedBox(width: 10), Expanded(child: _button('New game', Icons.bolt_rounded, () => Navigator.pop(context, true), primary: true, height: 48))])],
      ));
      if (replace != true || !mounted) return;
    }
    _saveDebounce?.cancel();
    game.reset();
    _runReward = null; _settlingRun = null; _rewardError = null;
    setState(() { _home = false; _savedState = null; });
    game.start(journeyStage: journeyStage, playMode: playMode, dailyDay: dailyDay);
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
    if (_settling || _rewardError != null) return;
    if (game.started && !game.over && !game.paused) game.togglePause();
    unawaited(_persistNow());
    setState(() => _home = true);
    _syncAudio();
  }

  Widget _button(String label, IconData icon, VoidCallback? action, {bool primary = false,
    Color? accent, double height = 58, bool stacked = false}) => ArcadeButton(
      label: label, icon: icon, onPressed: action, accent: accent ?? _palette.accent,
      surface: _palette.control, primary: primary, height: height, stacked: stacked);

  Widget _volumeSlider(String label, double value, bool enabled, ValueChanged<double> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(label, style: TextStyle(color: cream, fontSize: 13, fontWeight: FontWeight.w600))),
        Container(padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: _palette.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
          child: Text('${(value * 100).round()}%', style: TextStyle(color: _palette.accent, fontSize: 11, fontWeight: FontWeight.w700)))]),
      Slider(semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
        value: value, onChanged: enabled ? onChanged : null, onChangeEnd: (_) => _saveSettings())],
  );

  void _showHowToPlay() => showModalBottomSheet<void>(context: context, showDragHandle: true,
    useSafeArea: true, isScrollControlled: true, backgroundColor: _palette.panel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => Theme(data: _themeData, child: SafeArea(
      child: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How to play', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          SizedBox(height: 18),
          _helpRow(Icons.view_stream_rounded, 'Clear the rows', 'Fill a horizontal row. Every 10 rows increases the speed.'),
          _helpRow(Icons.timer_rounded, 'Pick your pace', 'Sprint races to 40 lines. Daily Challenge brings a new seeded puzzle at 00:00 UTC, with one reward per day and streak bonuses.'),
          _helpRow(Icons.route_rounded, 'Take the Journey', 'Complete stage objectives. Use fewer blocks to earn up to three stars and unlock new worlds.'),
          _helpRow(Icons.shopping_bag_rounded, 'Make it yours', 'Finish runs for Block Coins. Spend them on skins and clear effects in the Shop. Rewards save on this device.'),
          _helpRow(Icons.control_camera_rounded, 'Make your move', 'Hold the joystick left or right. Pull down to fall faster; push up to rotate.'),
          _helpRow(Icons.rotate_right_rounded, 'Find the fit', 'Tap the board or Rotate. The faint outline shows where your piece will land.'),
          _helpRow(Icons.keyboard_double_arrow_down_rounded, 'Drop it', 'Hit Drop to land your piece instantly.'),
          SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _button('Got it', Icons.check_rounded, () => Navigator.pop(context), primary: true)),
        ]))),
    )));

  Widget _helpRow(IconData icon, String title, String detail) => Padding(
    padding: EdgeInsets.only(bottom: 18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _palette.accent, size: 26), SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), SizedBox(height: 4),
        Text(detail, style: TextStyle(color: _palette.muted, fontSize: 13, height: 1.45)),
      ])),
    ]));

  Widget _buildHome() => Center(child: SingleChildScrollView(child: Padding(
    padding: EdgeInsets.all(24), child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 420),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      TBlockMark(size: 60, color: _palette.accent), SizedBox(height: 16),
      Text('T-BLOCK', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 40, letterSpacing: 4, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      Text(gameTagline, style: TextStyle(color: _palette.muted, fontSize: 13, letterSpacing: 1.8)),
      SizedBox(height: 18),
      Container(padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(color: _palette.panel.withValues(alpha: .7), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _palette.accent.withValues(alpha: .22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_rounded, color: _palette.blocks[1], size: 32), SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PERSONAL BEST', style: TextStyle(color: _palette.muted, fontSize: 9, letterSpacing: 1.6)),
            Text('$highScore', style: TextStyle(color: cream, fontSize: 27, fontWeight: FontWeight.w800)),
          ]),
        ])),
      SizedBox(height: 24),
      if (_loading) Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
      if (_savedState != null) ...[
        Text('${_savedState!['stageId'] != null ? 'Journey · Stage ${_savedState!["stageId"]}' : _savedState!['mode'] == 'sprint' ? 'Sprint' : _savedState!['mode'] == 'daily' ? 'Daily Challenge' : 'Classic'}  •  Score ${_savedState!["score"]}', style: TextStyle(color: _palette.muted, fontSize: 13)),
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: _button('Continue', Icons.play_arrow_rounded, _loading ? null : _continueGame, primary: true, height: 62)),
        SizedBox(height: 10),
      ],
      SizedBox(width: double.infinity, child: _button(_savedState == null ? 'Start playing' : 'Start new game',
        Icons.bolt_rounded, _loading ? null : _startNewGame, primary: _savedState == null,
        accent: _savedState == null ? _palette.accent : _palette.blocks[2], height: 62)),
      SizedBox(height: 12),
      SizedBox(width: double.infinity, child: _button('Journey · ${progress.data.stars.length}/30', Icons.route_rounded,
        _loading ? null : () => _openHub(), accent: _palette.blocks[2], height: 58)),
      SizedBox(height: 10),
      Row(children: [Expanded(child: _button('Sprint', Icons.timer_rounded, _loading ? null : () => _showModeIntro(PlayMode.sprint), height: 54)),
        SizedBox(width: 10), Expanded(child: _button('Daily Challenge', Icons.today_rounded,
          _loading ? null : () => _showModeIntro(PlayMode.daily), accent: _palette.blocks[3], height: 54))]),
      SizedBox(height: 10),
      Row(children: [Expanded(child: _button('Shop · ${progress.data.coins}', Icons.shopping_bag_rounded,
          _loading ? null : () => _openHub(1), accent: _palette.blocks[1], height: 50)),
        SizedBox(width: 10), Expanded(child: _button('Achievements', Icons.emoji_events_rounded, _loading ? null : () => _openHub(2), height: 50))]),
      SizedBox(height: 14),
      Row(children: [
        Expanded(child: _button('How to play', Icons.sports_esports_rounded, _showHowToPlay, height: 50)),
        SizedBox(width: 10), Expanded(child: Tooltip(message: 'Settings', child: _button('Settings', Icons.tune_rounded, _showSettings, height: 50))),
      ]),
      SizedBox(height: 22), Text('v1.6.0', style: TextStyle(color: _palette.muted.withValues(alpha: .65), fontSize: 10, letterSpacing: 1)),
    ])),
  )));

  void _showModeIntro(PlayMode mode) {
    final now = DateTime.now().toUtc(), today = utcDay(DateTime.now());
    final challenge = dailyForDay(today)!;
    final claimable = progress.data.canClaimDaily(today);
    final remaining = parseDay(today)!.add(Duration(days: 1)).difference(now);
    showModalBottomSheet<void>(context: context, useSafeArea: true, isScrollControlled: true,
      backgroundColor: _palette.panel, showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(child: SingleChildScrollView(child: Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(mode == PlayMode.sprint ? Icons.timer_rounded : Icons.today_rounded, color: _palette.accent, size: 28),
            SizedBox(width: 12), Expanded(child: Text(modeName(mode), style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)))]),
          SizedBox(height: 16),
          if (mode == PlayMode.sprint) ...[
            Text('40 lines. One race against yourself.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 12), Text('Your timer counts active play. Pausing or leaving the app stops the clock.', style: TextStyle(color: _palette.muted, height: 1.5)),
            SizedBox(height: 12), Text(progress.data.sprintBestMs == 0 ? 'Set your first personal best.' : 'Personal best · ${formatRunTime(progress.data.sprintBestMs)}', style: TextStyle(color: _palette.accent, fontWeight: FontWeight.w700)),
            SizedBox(height: 12), Text('Finish: 60 coins. Speed bonus: +40 within 3 minutes, +25 within 5, +10 within 8. Improve your record by at least 1 second for +15.', style: TextStyle(color: _palette.muted, height: 1.5)),
          ] else ...[
            Text(challenge.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8), Text(challenge.objective, style: TextStyle(color: _palette.accent, fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 12), Text('$today · Resets at 00:00 UTC\nNext challenge in ${remaining.inHours}h ${remaining.inMinutes % 60}m', style: TextStyle(color: _palette.muted, height: 1.5)),
            SizedBox(height: 12), Text(claimable ? 'Today’s reward: 120 coins + streak bonus' : 'Today’s reward collected · Replays are practice', style: TextStyle(color: _palette.blocks[1], fontWeight: FontWeight.w700)),
            SizedBox(height: 8), Text('Current streak: ${progress.data.activeDailyStreak(today)} days. Consecutive completions add +10 coins per day, up to +60. Everyone starts with the same daily board and piece sequence.', style: TextStyle(color: _palette.muted, height: 1.5)),
          ],
          SizedBox(height: 18),
          Text('Journey replay and repeat Sprint payouts share a 100-coin daily limit. First clears, improved Journey stars, achievements and Sprint record bonuses are extra.', style: TextStyle(color: _palette.muted, fontSize: 12, height: 1.5)),
          SizedBox(height: 18), SizedBox(width: double.infinity, child: _button(mode == PlayMode.sprint ? 'Start Sprint' : claimable ? 'Start challenge' : 'Practice challenge',
            Icons.play_arrow_rounded, () { Navigator.pop(context); _startNewGame(playMode: mode, dailyDay: mode == PlayMode.daily ? today : null); }, primary: true)),
        ])))));
  }

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
    progress.removeListener(_progressChanged);
    progress.dispose();
    game.removeListener(_onGameChanged);
    game.dispose();
    unawaited(audio.dispose());
    super.dispose();
  }

  Widget _stat(String label, String value) => Expanded(child: Container(
    padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    decoration: BoxDecoration(gradient: LinearGradient(colors: _palette.stats), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _palette.accent.withValues(alpha: .26))),
    child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(), style: TextStyle(color: _palette.muted, fontSize: 8, letterSpacing: 1.5)),
      SizedBox(height: 2), Text(value, style: TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.w800)),
    ]))),
  ));

  Widget _control(IconData icon, String label, VoidCallback action) => Expanded(
    child: _button(label, icon, game.canMove ? () => _act(action) : null, stacked: true, height: 64,
      primary: label == 'DROP', accent: label == 'DROP' ? _palette.blocks[1]
        : label == 'ROTATE' ? _palette.blocks[2] : _palette.accent));

  Widget _settingsSection(String label, IconData icon, List<Widget> children) => Container(
    margin: EdgeInsets.only(bottom: 14), padding: EdgeInsets.all(14),
    decoration: BoxDecoration(color: _palette.control.withValues(alpha: .55), borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _palette.accent.withValues(alpha: .15))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _palette.accent, size: 19), SizedBox(width: 9),
        Text(label.toUpperCase(), style: TextStyle(color: _palette.muted, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700))]),
      SizedBox(height: 12), ...children,
    ]));

  InputDecoration _choiceDecoration(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: TextStyle(color: _palette.muted, fontSize: 12),
    prefixIcon: Icon(icon, color: _palette.accent, size: 21),
    filled: true, fillColor: _palette.panel, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _palette.accent.withValues(alpha: .2))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _palette.accent, width: 1.5)));

  Widget _settingToggle(String label, IconData icon, bool value, ValueChanged<bool> change) => Material(
    color: Colors.transparent, borderRadius: BorderRadius.circular(12), child: SwitchListTile(
    contentPadding: EdgeInsets.zero, secondary: Icon(icon, color: _palette.muted, size: 22),
    title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    value: value, onChanged: change, activeColor: _palette.accent));

  void _showSettings() => showModalBottomSheet<void>(context: context,
    useSafeArea: true, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(builder: (context, update) => Theme(data: _themeData,
      child: DraggableScrollableSheet(expand: false, initialChildSize: .9, minChildSize: .55, maxChildSize: .96,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(color: _palette.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: _palette.accent.withValues(alpha: .22))),
          child: Column(children: [
            Padding(padding: EdgeInsets.fromLTRB(20, 10, 14, 12), child: Column(children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: _palette.muted.withValues(alpha: .4), borderRadius: BorderRadius.circular(4))),
              SizedBox(height: 12),
              Row(children: [TBlockMark(size: 30, color: _palette.accent), SizedBox(width: 10),
                Expanded(child: Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                ArcadeIconButton(tooltip: 'Done', icon: Icons.check_rounded, onPressed: () => Navigator.pop(context), palette: _palette),
              ]),
            ])),
            Expanded(child: ListView(controller: scroll, padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom), children: [
              _settingsSection('Appearance', Icons.palette_outlined, [
                DropdownButtonFormField<String>(key: ValueKey('theme-selector'), value: _palette.id, isExpanded: true,
                  dropdownColor: _palette.control, borderRadius: BorderRadius.circular(18),
                  icon: Icon(Icons.expand_more_rounded, color: _palette.accent),
                  style: TextStyle(color: cream, fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _choiceDecoration('Theme', Icons.auto_awesome_rounded),
                  items: gamePalettes.map((theme) => DropdownMenuItem(value: theme.id, child: Row(children: [
                    Expanded(child: Text(theme.name, overflow: TextOverflow.ellipsis)), SizedBox(width: 8),
                    ...[theme.blocks[0], theme.blocks[2], theme.blocks[3]].map((color) => Container(
                      margin: EdgeInsets.only(left: 3), width: 10, height: 14,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
                  ]))).toList(),
                  onChanged: (id) { if (id == null) return; update(() => _palette = paletteForId(id)); setState(() {}); _saveSettings(); }),
                SizedBox(height: 6),
                _settingToggle('Line-clear effects', Icons.auto_awesome_rounded, effectsEnabled, (v) => update(() => _setEffectsEnabled(v))),
              ]),
              _settingsSection('Audio', Icons.graphic_eq_rounded, [
                DropdownButtonFormField<String>(key: ValueKey('music-selector'), value: _musicTrack, isExpanded: true,
                  dropdownColor: _palette.control, borderRadius: BorderRadius.circular(18),
                  icon: Icon(Icons.expand_more_rounded, color: _palette.accent),
                  style: TextStyle(color: cream, fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _choiceDecoration('Soundtrack', Icons.music_note_rounded),
                  items: musicTracks.map((track) => DropdownMenuItem(value: track.id, child: Row(children: [
                    Expanded(child: Text(track.name, overflow: TextOverflow.ellipsis)), SizedBox(width: 8),
                    Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: _palette.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(7)),
                      child: Text('${track.bpm} BPM', style: TextStyle(color: _palette.accent, fontSize: 9, fontWeight: FontWeight.w700))),
                  ]))).toList(),
                  onChanged: (id) { if (id == null) return; update(() => _musicTrack = trackForId(id).id); setState(() {}); _syncAudio(); _saveSettings(); }),
                SizedBox(height: 8),
                _settingToggle('Music', Icons.headphones_rounded, musicEnabled, (v) {
                  update(() => musicEnabled = v); setState(() {}); _syncAudio(); _saveSettings();
                }),
                _volumeSlider('Music volume', musicVolume, musicEnabled, (v) { update(() => musicVolume = v); setState(() {}); _syncAudio(); }),
                _settingToggle('Sound effects', Icons.volume_up_rounded, soundEnabled, (v) {
                  update(() => soundEnabled = v); setState(() {}); _syncAudio(); _saveSettings();
                }),
                _volumeSlider('Effects volume', effectsVolume, soundEnabled, (v) { update(() => effectsVolume = v); setState(() {}); _syncAudio(); }),
              ]),
              _settingsSection('Controls', Icons.sports_esports_rounded, [
                _settingToggle('Joystick', Icons.control_camera_rounded, joystickEnabled, (v) {
                  update(() => joystickEnabled = v); setState(() {}); _saveSettings();
                }),
                if (joystickEnabled) _volumeSlider('Joystick speed', (220 - joystickRepeat) / 140, true, (v) {
                  update(() => joystickRepeat = 220 - (v*140).round()); setState(() {});
                }),
                _settingToggle('Vibration', Icons.vibration_rounded, vibrationEnabled, (v) {
                  update(() => vibrationEnabled = v); setState(() {}); _saveSettings();
                }),
              ]),
              Center(child: Text('T-BLOCK • 1.6.0', style: TextStyle(color: _palette.muted.withValues(alpha: .65), fontSize: 10, letterSpacing: 1))),
            ])),
          ]),
        )),
    )));

  Widget _boardContents() => Stack(children: [
    RepaintBoundary(child: CustomPaint(painter: BoardPainter(game.visibleBoard, ghost: game.ghostPiece, palette: _palette, skin: progress.data.skin, markedRows: game.obstacleRows), size: Size.infinite)),
    if (burstVisible && effectsEnabled && game.canMove) Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: SparkPainter(burst, palette: _palette, effect: progress.data.effect))))),
    if (game.paused || game.over || game.completed) Positioned.fill(child: ColoredBox(color: _palette.overlay,
      child: Center(child: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(game.completed || game.over ? Icons.emoji_events_rounded : Icons.pause_circle_rounded, color: _palette.blocks[1], size: 34),
        SizedBox(height: 8),
        Text(game.completed ? (game.mode == PlayMode.sprint ? 'Sprint complete!' : game.mode == PlayMode.daily ? 'Challenge complete!' : 'Stage complete!') : game.over ? (game.mode == PlayMode.classic ? 'Nice run!' : 'Try again!') : 'Paused',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        if (game.completed && game.stage != null) ...[
          SizedBox(height: 6), Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 3; i++) Icon(i < game.earnedStars ? Icons.star_rounded : Icons.star_outline_rounded, color: _palette.blocks[1], size: 30),
          ]),
        ],
        if (game.over || game.completed) ...[
          SizedBox(height: 8), Text('Score ${game.score}  •  ${game.lines} lines', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          if (game.mode == PlayMode.sprint) Text(formatRunTime(game.elapsedMilliseconds), style: TextStyle(color: _palette.accent, fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${game.piecesLocked} blocks placed', style: TextStyle(color: _palette.muted, fontSize: 12)),
          SizedBox(height: 8),
          if (_settling) Text('Saving rewards…', style: TextStyle(color: _palette.muted, fontSize: 12)),
          if (_runReward != null) ...[
            Text('+${_runReward!.coins} Block Coins', textAlign: TextAlign.center, style: TextStyle(color: _palette.blocks[1], fontWeight: FontWeight.w800)),
            for (final entry in _runReward!.details.entries) Text('${entry.key}: +${entry.value}', textAlign: TextAlign.center, style: TextStyle(color: _palette.muted, fontSize: 10)),
            if (_runReward!.note != null) Text(_runReward!.note!, textAlign: TextAlign.center, style: TextStyle(color: _palette.accent, fontSize: 11)),
            for (final name in _runReward!.achievements) Text('Unlocked: $name', textAlign: TextAlign.center, style: TextStyle(color: _palette.accent, fontSize: 11)),
          ],
          if (_rewardError != null) ...[Text(_rewardError!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            _button('Retry saving', Icons.save_rounded, _settleFinished, height: 48)],
        ],
        SizedBox(height: 16),
        if (game.completed && game.stage != null && game.stage!.id < 30 && progress.data.unlocked(journeyStages[game.stage!.id])) ...[
          _button('Next stage', Icons.arrow_forward_rounded, _settling || _rewardError != null ? null : () =>
            _startNewGame(confirm: false, journeyStage: journeyStages[game.stage!.id]), primary: true, height: 50), SizedBox(height: 8),
        ],
        _button(game.paused ? 'Resume' : game.stage == null ? 'Play again' : 'Replay stage', Icons.play_arrow_rounded,
          _settling || _rewardError != null ? null : () {
            if (game.paused) { game.togglePause(); _scheduleTick(); }
            else { _startNewGame(confirm: false, journeyStage: game.stage, playMode: game.mode, dailyDay: game.daily?.day); }
          }, primary: !game.completed, height: 50),
        if (game.paused) ...[SizedBox(height: 8), _button('Restart', Icons.replay_rounded,
          () => _startNewGame(journeyStage: game.stage, playMode: game.mode, dailyDay: game.daily?.day), height: 48)],
        if (game.stage != null && !game.paused) ...[SizedBox(height: 8), _button('Journey map', Icons.route_rounded,
          _settling || _rewardError != null ? null : () { _returnHome(); _openHub(); }, height: 48)],
        SizedBox(height: 8), _button('Home', Icons.home_rounded, _settling || _rewardError != null ? null : _returnHome, height: 48),
      ])))),
    )),
  ]);

  Widget _buildGame() => LayoutBuilder(builder: (context, constraints) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5).toDouble();
    return Padding(padding: EdgeInsets.all(8), child: Column(children: [
      SizedBox(height: 46 * scale, child: Row(children: [
        TBlockMark(size: 30, color: _palette.accent), SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('T-BLOCK', style: TextStyle(fontSize: 21, letterSpacing: 1.8, fontWeight: FontWeight.w900)),
          Text(game.mode == PlayMode.classic ? gameTagline : '${game.modeLabel} · ${game.objective}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _palette.muted, fontSize: 9, letterSpacing: .2)),
        ])),
        ArcadeIconButton(tooltip: 'Settings', icon: Icons.tune_rounded, onPressed: _showSettings, palette: _palette),
        SizedBox(width: 8),
        ArcadeIconButton(tooltip: game.paused ? 'Resume' : 'Pause', icon: game.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onPressed: () { final resume = game.paused; game.togglePause(); if (resume) _scheduleTick(); }, palette: _palette),
      ])),
      SizedBox(height: 6),
      SizedBox(height: 52 * scale, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (game.mode == PlayMode.sprint) ...[
          _stat('Lines', '${game.lines}/40'), SizedBox(width: 6),
          Expanded(child: Container(padding: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: _palette.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _palette.accent.withValues(alpha: .26))),
            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('TIME', style: TextStyle(color: _palette.muted, fontSize: 8, letterSpacing: 1.5)), SprintTimeText(game: game),
            ]))))), SizedBox(width: 6),
          _stat('Best', progress.data.sprintBestMs == 0 ? '—' : formatRunTime(progress.data.sprintBestMs)),
        ] else ...[
          _stat('Score', '${game.score}'), SizedBox(width: 6), _stat('Level', '${game.level}'), SizedBox(width: 6),
          _stat(game.mode == PlayMode.classic ? 'Best' : 'Goal', game.mode == PlayMode.classic ? '$highScore' : '${game.goalProgress}/${game.goalTarget}'),
        ], SizedBox(width: 6),
        Container(width: 52, padding: EdgeInsets.all(4), decoration: BoxDecoration(color: _palette.panel,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: _palette.accent.withValues(alpha: .26))),
          child: Column(children: [Text('NEXT', style: TextStyle(color: _palette.muted, fontSize: 8, letterSpacing: 1.2)),
            Expanded(child: CustomPaint(painter: NextPainter(game.nextKind, palette: _palette, skin: progress.data.skin), size: Size.infinite)),
          ])),
      ])),
      SizedBox(height: 6),
      Expanded(child: LayoutBuilder(builder: (context, boardSpace) {
        final width = math.min(boardSpace.maxWidth - 12, (boardSpace.maxHeight - 6) / 2).clamp(40.0, 1000.0).toDouble();
        return Center(child: Padding(padding: EdgeInsets.all(6), child: SizedBox(width: width,
          child: GameBoardFrame(palette: _palette, child: AspectRatio(aspectRatio: boardWidth / boardHeight, child: _boardContents())))));
      })),
      SizedBox(height: 6),
      SizedBox(height: joystickEnabled ? 108 : 64, child: Row(children: [
        if (joystickEnabled) ...[
          GameJoystick(size: 104, accent: _palette.accent, surface: _palette.control, muted: _palette.muted,
            enabled: game.canMove, repeatMilliseconds: joystickRepeat, onLeft: () => game.move(-1, 0),
            onRight: () => game.move(1, 0), onDown: game.softDrop, onRotate: _rotate),
          SizedBox(width: 12),
        ] else ...[
          _control(Icons.arrow_back_rounded, 'LEFT', () => game.move(-1, 0)), SizedBox(width: 6),
        ],
        _control(Icons.rotate_right_rounded, 'ROTATE', _rotate), SizedBox(width: 6),
        if (!joystickEnabled) ...[
          _control(Icons.arrow_forward_rounded, 'RIGHT', () => game.move(1, 0)), SizedBox(width: 6),
          _control(Icons.arrow_downward_rounded, 'DOWN', game.softDrop), SizedBox(width: 6),
        ],
        _control(Icons.keyboard_double_arrow_down_rounded, 'DROP', game.hardDrop),
      ])),
    ]));
  });

  @override
  Widget build(BuildContext context) => Theme(data: _themeData, child: PopScope(canPop: _home,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) _returnHome(); },
    child: Scaffold(body: Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _palette.background)),
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: AuroraPainter(aurora, game.level, effectsEnabled, palette: _palette))))),
        SafeArea(child: _home ? _buildHome() : _buildGame()),
      ]),
    )),
  ));
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.cells, {this.ghost, this.palette = neonPalette, this.skin = 'glass', this.markedRows = const {}});
  final String skin;
  final Set<int> markedRows;
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
        if (v > 0) drawBlock(canvas, rect.deflate(1), palette.blocks[v - 1], skin: skin);
        if (markedRows.contains(y) && x == 0) {
          canvas.drawCircle(Offset(rect.left + 4, rect.center.dy), 2, Paint()..color = Colors.white);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

void drawBlock(Canvas canvas, Rect rect, Color color, {String skin = 'glass'}) => paintCosmeticBlock(canvas, rect, color, skin: skin);

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
  SparkPainter(this.animation, {this.palette = neonPalette, this.effect = 'sparks'}) : super(repaint: animation);
  final GamePalette palette;
  final Animation<double> animation;
  final String effect;
  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1) return;
    if (effect == 'nova') {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(size.width / 2, size.height * .65), (progress * size.width * .5 + i * 10),
          Paint()..color = palette.blocks[i].withValues(alpha: (1-progress) * .8)..style = PaintingStyle.stroke..strokeWidth = 3*(1-progress)+1);
      }
    }
    if (effect == 'lightning') {
      for (var i = 0; i < 5; i++) {
        final x = size.width * (i + 1) / 6;
        final y = size.height * .65;
        final path = Path()..moveTo(x + 12, y - progress * 75)..lineTo(x - 7, y)..lineTo(x + 7, y)..lineTo(x - 12, y + progress * 75);
        canvas.drawPath(path, Paint()..color = palette.blocks[i].withValues(alpha: 1-progress)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
      return;
    }
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24;
      final distance = 15 + progress * size.width * .48;
      final center = Offset(size.width / 2, size.height * .65);
      final point = center + Offset(math.cos(a) * distance, math.sin(a) * distance * .5);
      canvas.drawCircle(point, 1.5 + (1 - progress) * 2.5, Paint()..color = palette.blocks[i % palette.blocks.length].withValues(alpha: 1 - progress));
    }
  }
  @override
  bool shouldRepaint(covariant SparkPainter old) => old.animation != animation || old.palette != palette || old.effect != effect;
}

class NextPainter extends CustomPainter {
  NextPainter(this.kind, {this.palette = neonPalette, this.skin = 'glass'});
  final String skin;
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
          Rect.fromLTWH(startX + c * unit, startY + r * unit, unit - 1, unit - 1), palette.blocks[kind!], skin: skin);
      }
    }
  }
  @override
  bool shouldRepaint(covariant NextPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.palette != palette || oldDelegate.skin != skin;
}
