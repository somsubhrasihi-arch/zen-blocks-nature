import 'dart:math';
import 'package:flutter/foundation.dart';
import 'campaign.dart';
import 'play_modes.dart';

const int boardWidth = 10;
const int boardHeight = 20;

const List<List<List<int>>> shapes = [
  [[1, 1, 1, 1]],
  [[1, 1], [1, 1]],
  [[0, 1, 0], [1, 1, 1]],
  [[0, 1, 1], [1, 1, 0]],
  [[1, 1, 0], [0, 1, 1]],
  [[1, 0, 0], [1, 1, 1]],
  [[0, 0, 1], [1, 1, 1]],
];

class Piece {
  Piece(this.kind, this.cells, this.x, this.y);
  final int kind;
  List<List<int>> cells;
  int x;
  int y;
}

class ZenGame extends ChangeNotifier {
  ZenGame({Random? random, int Function()? nowMilliseconds}) : _random = random ?? Random() {
    _now = nowMilliseconds ?? () => _clock.elapsedMilliseconds;
    reset();
  }
  final Random _random;
  final Stopwatch _clock = Stopwatch()..start();
  late final int Function() _now;
  int _elapsed = 0;
  int? _segment;
  int _dailyBag = 0;
  PlayMode mode = PlayMode.classic;
  DailyChallenge? daily;
  int get elapsedMilliseconds => _elapsed + (_segment == null ? 0 : max(0, _now() - _segment!));
  void _freezeClock() { _elapsed = elapsedMilliseconds; _segment = null; }
  void _resumeClock() { if (mode == PlayMode.sprint && _segment == null && started && !paused && !over && !completed) _segment = _now(); }
  int get initialLevel => stage?.startLevel ?? daily?.startLevel ?? 1;
  int get initialObstacles => stage?.obstacleCount ?? daily?.obstacleCount ?? 0;
  StageGoal? get objectiveGoal => mode == PlayMode.sprint ? StageGoal.lines : stage?.goal ?? daily?.goal;
  int get goalTarget => mode == PlayMode.sprint ? 40 : stage?.target ?? daily?.target ?? 0;
  String get objective => mode == PlayMode.sprint ? 'Clear 40 lines' : stage?.objective ?? daily?.objective ?? '';
  String get modeLabel => stage != null ? 'Journey · Stage ${stage!.id}' : modeName(mode);
  void _finishGoal() {
    if (goalTarget > 0 && goalProgress >= goalTarget) { completed = true; active = null; _freezeClock(); }
  }
  late List<List<int>> board;
  Piece? active;
  int? nextKind;
  JourneyStage? stage;
  String runId = '';
  bool completed = false;
  Set<int> obstacleRows = {};
  int get obstaclesCleared => initialObstacles - obstacleRows.length;
  int get goalProgress => switch (objectiveGoal) {
    StageGoal.lines => lines, StageGoal.score => score, StageGoal.excavation => obstaclesCleared, _ => 0,
  };
  int get earnedStars => completed && stage != null ? stage!.starsFor(piecesLocked) : 0;
  int score = 0;
  int piecesLocked = 0;
  int lines = 0;
  int level = 1;
  int combo = -1;
  bool over = false;
  bool paused = false;
  bool started = false;
  final List<int> _bag = [];

  int get fallMilliseconds => max(95, (850 * pow(0.84, level - 1)).round());

  int _drawKind() {
    if (_bag.isEmpty) {
      _bag.addAll(List.generate(7, (i) => i)..shuffle(daily == null ? _random : Random(daily!.seed + _dailyBag++ * 7919)));
    }
    return _bag.removeLast();
  }

  void reset() {
    board = List.generate(boardHeight, (_) => List.filled(boardWidth, 0));
    _elapsed = 0; _segment = null; _dailyBag = 0;
    mode = PlayMode.classic; daily = null;
    stage = null; completed = false; obstacleRows = {}; runId = '';
    score = 0;
    piecesLocked = 0;
    lines = 0;
    level = 1;
    combo = -1;
    over = false;
    paused = false;
    started = false;
    _bag.clear();
    nextKind = _drawKind();
    active = null;
    notifyListeners();
  }

  void start({JourneyStage? journeyStage, PlayMode playMode = PlayMode.classic, String? dailyDay}) {
    if (started && !over && !completed) return;
    reset();
    stage = journeyStage;
    mode = journeyStage != null ? PlayMode.journey : playMode == PlayMode.journey ? PlayMode.classic : playMode;
    daily = mode == PlayMode.daily ? dailyForDay(dailyDay ?? utcDay(DateTime.now())) : null;
    if (mode == PlayMode.daily && daily == null) mode = PlayMode.classic;
    if (daily != null) { _bag.clear(); _dailyBag = 0; nextKind = _drawKind(); }
    runId = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';
    level = initialLevel;
    if (initialObstacles > 0) {
      for (var row = 0; row < initialObstacles; row++) {
        final y = boardHeight - 1 - row;
        final hole = (row * 3 + (stage?.id ?? daily!.seed)) % (boardWidth - 1);
        board[y] = List.generate(boardWidth, (x) => x == hole || x == hole + 1 ? 0 : (row % 7) + 1);
        obstacleRows.add(y);
      }
    }
    started = true;
    _resumeClock();
    _spawn();
    notifyListeners();
  }

  void togglePause() {
    if (!started || over || completed) return;
    if (!paused) _freezeClock();
    paused = !paused;
    if (!paused) _resumeClock();
    notifyListeners();
  }

  bool get canMove => started && !over && !completed && !paused && active != null;

  Piece? get ghostPiece {
    final piece = active;
    if (!started || over || completed || piece == null) return null;
    var landingY = piece.y;
    while (_fits(piece.cells, piece.x, landingY + 1)) { landingY++; }
    return Piece(piece.kind, piece.cells, piece.x, landingY);
  }

  Map<String, dynamic>? saveState() {
    final piece = active;
    if (!started || over || completed || piece == null) return null;
    return {
      'version': 1, 'mode': mode.name, 'dailyDay': daily?.day, 'dailyBag': _dailyBag, 'elapsedMs': elapsedMilliseconds, 'stageId': stage?.id, 'runId': runId, 'obstacleRows': obstacleRows.toList(),
      'board': board.map((row) => List<int>.from(row)).toList(),
      'piece': {'kind': piece.kind, 'x': piece.x, 'y': piece.y,
        'cells': piece.cells.map((row) => List<int>.from(row)).toList()},
      'nextKind': nextKind, 'bag': List<int>.from(_bag),
      'score': score, 'lines': lines, 'level': level, 'combo': combo,
      'piecesLocked': piecesLocked,
    };
  }

  /// Validate the complete snapshot before changing the running game.
  /// Restored games always wait for an explicit resume.
  bool restoreState(Object? value) {
    try {
      if (value is! Map || value['version'] != 1) return false;
      List<List<int>> matrix(Object? source) => (source as List)
          .map((row) => (row as List).cast<int>().toList()).toList();
      final stageId = value['stageId'];
      if (stageId != null && (stageId is! int || stageForId(stageId) == null)) return false;
      final savedStage = stageForId(stageId as int?);
      final rawMode = value['mode'] ?? (savedStage == null ? 'classic' : 'journey');
      if (!PlayMode.values.any((m) => m.name == rawMode)) return false;
      final savedMode = PlayMode.values.firstWhere((m) => m.name == rawMode);
      if ((savedMode == PlayMode.journey) != (savedStage != null)) return false;
      final day = value['dailyDay'];
      if (day != null && day is! String) return false;
      final savedDaily = savedMode == PlayMode.daily ? dailyForDay(day as String?) : null;
      if (savedMode == PlayMode.daily && savedDaily == null || savedMode != PlayMode.daily && day != null) return false;
      final savedElapsed = value['elapsedMs'] ?? 0;
      final savedDailyBag = value['dailyBag'] ?? 0;
      if (savedElapsed is! int || savedElapsed < 0 || savedElapsed > 864000000 || savedDailyBag is! int ||
          savedDailyBag < 0 || savedDailyBag > 1000000 || savedMode == PlayMode.daily && savedDailyBag == 0) return false;
      final obstacleSource = value['obstacleRows'] ?? <int>[];
      if (obstacleSource is! List || obstacleSource.any((v) => v is! int || v < 0 || v >= boardHeight)) return false;
      final savedObstacles = obstacleSource.cast<int>().toSet();
      if (savedObstacles.length > (savedStage?.obstacleCount ?? savedDaily?.obstacleCount ?? 0)) return false;
      final savedRunId = value['runId'];
      if (savedRunId != null && (savedRunId is! String || savedRunId.length > 100 || savedRunId.isEmpty)) return false;
      final savedBoard = matrix(value['board']);
      if (savedBoard.length != boardHeight || savedBoard.any((row) =>
          row.length != boardWidth || row.any((cell) => cell < 0 || cell > 7))) return false;
      final savedPiece = value['piece'] as Map;
      final kind = savedPiece['kind'] as int;
      final x = savedPiece['x'] as int;
      final y = savedPiece['y'] as int;
      if (kind < 0 || kind >= shapes.length || y < 0 || y >= boardHeight) return false;
      final cells = matrix(savedPiece['cells']);
      var rotation = shapes[kind];
      var validShape = false;
      bool same(List<List<int>> a, List<List<int>> b) => a.length == b.length &&
          List.generate(a.length, (r) => a[r].length == b[r].length &&
            List.generate(a[r].length, (c) => a[r][c] == b[r][c]).every((v) => v)).every((v) => v);
      for (var i = 0; i < 4; i++) {
        if (same(cells, rotation)) validShape = true;
        rotation = List.generate(rotation.first.length,
          (r) => List.generate(rotation.length, (c) => rotation[rotation.length - 1 - c][r]));
      }
      if (!validShape) return false;
      for (var r = 0; r < cells.length; r++) {
        for (var c = 0; c < cells[r].length; c++) {
          if (cells[r][c] == 0) continue;
          final bx = x + c, by = y + r;
          if (bx < 0 || bx >= boardWidth || by >= boardHeight || savedBoard[by][bx] != 0) return false;
        }
      }
      final next = value['nextKind'] as int;
      final bag = (value['bag'] as List).cast<int>().toList();
      if (next < 0 || next > 6 || bag.length > 7 || bag.toSet().length != bag.length ||
          bag.any((item) => item < 0 || item > 6)) return false;
      final savedScore = value['score'] as int;
      final savedLines = value['lines'] as int;
      final savedLevel = value['level'] as int;
      final savedCombo = value['combo'] as int;
      final locks = value['piecesLocked'] as int;
      if (savedScore < 0 || savedLines < 0 || savedLevel != (savedStage?.startLevel ?? savedDaily?.startLevel ?? 1) + savedLines ~/ 10 ||
          savedCombo < -1 || locks < 0) return false;
      final progress = switch (savedMode == PlayMode.sprint ? StageGoal.lines : savedStage?.goal ?? savedDaily?.goal) {
        StageGoal.lines => savedLines, StageGoal.score => savedScore,
        StageGoal.excavation => (savedStage?.obstacleCount ?? savedDaily!.obstacleCount) - savedObstacles.length, _ => 0,
      };
      final target = savedMode == PlayMode.sprint ? 40 : savedStage?.target ?? savedDaily?.target ?? 0;
      if (target > 0 && progress >= target) return false;
      if (savedObstacles.any((r) => savedBoard[r].every((v) => v == 0))) return false;
      mode = savedMode; daily = savedDaily; _dailyBag = savedDailyBag;
      _elapsed = savedElapsed; _segment = null;
      stage = savedStage; obstacleRows = savedObstacles; completed = false;
      runId = savedRunId as String? ?? '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';
      board = savedBoard;
      active = Piece(kind, cells, x, y);
      nextKind = next;
      _bag..clear()..addAll(bag);
      score = savedScore; lines = savedLines; level = savedLevel;
      combo = savedCombo; piecesLocked = locks;
      started = true; paused = true; over = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _fits(List<List<int>> cells, int x, int y) {
    for (var row = 0; row < cells.length; row++) {
      for (var col = 0; col < cells[row].length; col++) {
        if (cells[row][col] == 0) continue;
        final bx = x + col;
        final by = y + row;
        if (bx < 0 || bx >= boardWidth || by >= boardHeight) return false;
        if (by >= 0 && board[by][bx] != 0) return false;
      }
    }
    return true;
  }

  void _spawn() {
    final kind = nextKind ?? _drawKind();
    nextKind = _drawKind();
    final cells = shapes[kind].map((row) => List<int>.from(row)).toList();
    final x = (boardWidth - cells.first.length) ~/ 2;
    active = Piece(kind, cells, x, 0);
    if (!_fits(cells, x, 0)) {
      over = true;
      _freezeClock();
      active = null;
    }
  }

  bool move(int dx, int dy) {
    if (!canMove) return false;
    final p = active!;
    if (!_fits(p.cells, p.x + dx, p.y + dy)) return false;
    p.x += dx;
    p.y += dy;
    notifyListeners();
    return true;
  }

  void rotate() {
    if (!canMove) return;
    final p = active!;
    final old = p.cells;
    final rotated = List.generate(old.first.length,
        (r) => List.generate(old.length, (c) => old[old.length - 1 - c][r]));
    for (final dx in [0, -1, 1, -2, 2]) {
      if (_fits(rotated, p.x + dx, p.y)) {
        p.cells = rotated;
        p.x += dx;
        notifyListeners();
        return;
      }
    }
  }

  void tick() {
    if (!canMove) return;
    if (!move(0, 1)) _lock();
  }

  void softDrop() {
    if (!canMove) return;
    if (move(0, 1)) {
      score += 1;
      if (objectiveGoal == StageGoal.score) _finishGoal();
      notifyListeners();
    } else {
      _lock();
    }
  }

  void hardDrop() {
    if (!canMove) return;
    var steps = 0;
    while (move(0, 1)) {
      steps++;
    }
    score += steps * 2;
    _lock();
  }

  void _lock() {
    final p = active;
    if (p == null) return;
    for (var r = 0; r < p.cells.length; r++) {
      for (var c = 0; c < p.cells[r].length; c++) {
        if (p.cells[r][c] == 0) continue;
        final y = p.y + r;
        if (y < 0) {
          over = true;
          _freezeClock();
          active = null;
          notifyListeners();
          return;
        }
        board[y][p.x + c] = p.kind + 1;
      }
    }
    piecesLocked++;
    final remaining = board.where((row) => row.any((v) => v == 0)).toList();
    final cleared = boardHeight - remaining.length;
    if (cleared > 0) {
      combo++;
      final base = [0, 100, 300, 500, 800][cleared];
      score += base * level + combo * 50 * level;
      lines += cleared;
      level = initialLevel + lines ~/ 10;
      final fullRows = <int>{for (var y = 0; y < boardHeight; y++) if (board[y].every((v) => v != 0)) y};
      obstacleRows = {for (final y in obstacleRows) if (!fullRows.contains(y)) y + fullRows.where((r) => r > y).length};
      board = [
        ...List.generate(cleared, (_) => List.filled(boardWidth, 0)),
        ...remaining,
      ];
    } else {
      combo = -1;
    }
    _finishGoal();
    if (!completed) _spawn();
    notifyListeners();
  }

  List<List<int>> get visibleBoard {
    final result = board.map((row) => List<int>.from(row)).toList();
    final p = active;
    if (p != null) {
      for (var r = 0; r < p.cells.length; r++) {
        for (var c = 0; c < p.cells[r].length; c++) {
          if (p.cells[r][c] == 0) continue;
          final x = p.x + c;
          final y = p.y + r;
          if (x >= 0 && x < boardWidth && y >= 0 && y < boardHeight) {
            result[y][x] = p.kind + 1;
          }
        }
      }
    }
    return result;
  }
}
