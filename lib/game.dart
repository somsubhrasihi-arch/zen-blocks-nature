import 'dart:math';
import 'package:flutter/foundation.dart';

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
  ZenGame({Random? random}) : _random = random ?? Random() {
    reset();
  }
  final Random _random;
  late List<List<int>> board;
  Piece? active;
  int? nextKind;
  int score = 0;
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
      _bag.addAll(List.generate(7, (i) => i)..shuffle(_random));
    }
    return _bag.removeLast();
  }

  void reset() {
    board = List.generate(boardHeight, (_) => List.filled(boardWidth, 0));
    score = 0;
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

  void start() {
    if (started && !over) return;
    reset();
    started = true;
    _spawn();
    notifyListeners();
  }

  void togglePause() {
    if (!started || over) return;
    paused = !paused;
    notifyListeners();
  }

  bool get canMove => started && !over && !paused && active != null;

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
          active = null;
          notifyListeners();
          return;
        }
        board[y][p.x + c] = p.kind + 1;
      }
    }
    final remaining = board.where((row) => row.any((v) => v == 0)).toList();
    final cleared = boardHeight - remaining.length;
    if (cleared > 0) {
      combo++;
      final base = [0, 100, 300, 500, 800][cleared];
      score += base * level + combo * 50 * level;
      lines += cleared;
      level = 1 + lines ~/ 10;
      board = [
        ...List.generate(cleared, (_) => List.filled(boardWidth, 0)),
        ...remaining,
      ];
    } else {
      combo = -1;
    }
    _spawn();
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
