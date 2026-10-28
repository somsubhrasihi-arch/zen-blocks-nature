import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zen_blocks/joystick.dart';
import 'package:zen_blocks/main.dart';

void main() {
  testWidgets('holding moves repeatedly and release stops movement', (tester) async {
    var left = 0;
    var right = 0;
    await tester.pumpWidget(MaterialApp(home: Center(child: GameJoystick(
      enabled: true, onLeft: () => left++, onRight: () => right++,
      onDown: () {}, onRotate: () {}))));
    final center = tester.getCenter(find.byType(GameJoystick));
    final touch = await tester.startGesture(center + const Offset(-35, 0));
    expect(left, 1);
    await tester.pump(const Duration(milliseconds: 360));
    expect(left, 4);
    await touch.moveTo(center + const Offset(35, 0));
    expect(right, 1);
    final stoppedLeft = left;
    await tester.pump(const Duration(milliseconds: 240));
    expect(right, 3);
    expect(left, stoppedLeft);
    await touch.up();
    await tester.pump(const Duration(milliseconds: 360));
    expect(right, 3);
  });

  testWidgets('center is neutral, up rotates once and down repeats', (tester) async {
    var rotations = 0;
    var drops = 0;
    await tester.pumpWidget(MaterialApp(home: Center(child: GameJoystick(
      enabled: true, onLeft: () {}, onRight: () {},
      onDown: () => drops++, onRotate: () => rotations++))));
    final center = tester.getCenter(find.byType(GameJoystick));
    final touch = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 360));
    expect(rotations + drops, 0);
    await touch.moveTo(center + const Offset(0, -35));
    await tester.pump(const Duration(milliseconds: 360));
    expect(rotations, 1);
    await touch.moveTo(center + const Offset(0, 35));
    await tester.pump(const Duration(milliseconds: 240));
    expect(drops, 3);
    await touch.cancel();
    await tester.pump(const Duration(milliseconds: 360));
    expect(drops, 3);
  });

  testWidgets('disabling joystick cancels a held direction', (tester) async {
    var count = 0;
    Widget controls(bool enabled) => MaterialApp(home: Center(child: GameJoystick(
      enabled: enabled, onLeft: () => count++, onRight: () {},
      onDown: () {}, onRotate: () {})));
    await tester.pumpWidget(controls(true));
    final touch = await tester.startGesture(
      tester.getCenter(find.byType(GameJoystick)) + const Offset(-35, 0));
    expect(count, 1);
    await tester.pumpWidget(controls(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(count, 1);
    await touch.up();
  });

  testWidgets('saved button preference keeps original controls available', (tester) async {
    SharedPreferences.setMockInitialValues({'joystickEnabled': false});
    await tester.pumpWidget(const ZenBlocksApp());
    await tester.pump();
    expect(find.byType(GameJoystick), findsNothing);
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('DOWN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('joystick moves pieces while gravity continues falling', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ZenBlocksApp());
    await tester.pump();
    await tester.tap(find.text('Start playing'));
    await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    final initialX = state.game.active.x as int;
    final initialY = state.game.active.y as int;
    final touch = await tester.startGesture(
      tester.getCenter(find.byType(GameJoystick)) + const Offset(-35, 0));
    await tester.pump(const Duration(milliseconds: 900));
    expect(state.game.active.x as int, lessThan(initialX));
    expect(state.game.active.y as int, greaterThan(initialY));
    await touch.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
