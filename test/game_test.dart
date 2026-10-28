import 'package:flutter_test/flutter_test.dart';
import 'package:zen_blocks/game.dart';

void main() {
  test('game initializes with empty board and level one', () {
    final game = ZenGame();
    expect(game.board.length, 20);
    expect(game.board.first.length, 10);
    expect(game.level, 1);
    expect(game.score, 0);
    expect(game.started, false);
  });

  test('starting, pausing and resetting work', () {
    final game = ZenGame()..start();
    expect(game.started, true);
    expect(game.active, isNotNull);
    game.togglePause();
    expect(game.paused, true);
    expect(game.move(1, 0), false);
    game.reset();
    expect(game.started, false);
    expect(game.paused, false);
  });

  test('hard drop locks blocks on board', () {
    final game = ZenGame()..start();
    game.hardDrop();
    expect(game.board.expand((r) => r).where((v) => v > 0).length, 4);
  });
}
