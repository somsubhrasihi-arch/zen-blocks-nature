import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_blocks/customization.dart';
import 'package:zen_blocks/playful_home.dart';

import 'product_ui_test.dart' show capture, captureKey, loadPreviewFonts;

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('quiet home keeps every feature reachable through its tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final actions = <String>[];
    VoidCallback call(String id) =>
        () => actions.add(id);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            backgroundColor: toyPalette.background.first,
            body: SafeArea(
              child: PlayfulHome(
                palette: toyPalette,
                coins: 250,
                best: 1000,
                stage: 12,
                loading: false,
                hasSave: false,
                showPractice: false,
                onPlay: call('play'),
                onContinue: call('continue'),
                onJourney: call('journey'),
                onSprint: call('sprint'),
                onDaily: call('daily'),
                onShop: call('shop'),
                onRewards: call('rewards'),
                onFriends: call('friends'),
                onAchievements: call('achievements'),
                onSettings: call('settings'),
                onHelp: call('help'),
                onPractice: call('practice'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Play Classic'), findsOneWidget);
    expect(find.text('Sprint'), findsNothing);
    expect(find.text('Daily Challenge'), findsNothing);
    expect(find.text('Daily rewards & lives'), findsNothing);
    expect(find.text('Achievements'), findsNothing);
    await tester.tap(find.text('Play Classic'));
    await tester.tap(find.text('Journey · Stage 12'));
    await tester.tap(find.text('Shop'));
    await tester.tap(find.byTooltip('Settings'));
    await tester.tap(find.text('Challenges'));
    await tester.pump();
    await capture(tester, '27-challenges-new');
    for (final label in [
      'Daily Challenge',
      'Sprint',
      'Friend challenges',
      'Daily rewards & lives',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    await tester.tap(find.text('More'));
    await tester.pump();
    await capture(tester, '28-clubhouse-new');
    for (final label in ['Achievements', 'Practice', 'How to play']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(actions, [
      'play',
      'journey',
      'shop',
      'settings',
      'daily',
      'sprint',
      'friends',
      'rewards',
      'achievements',
      'practice',
      'help',
    ]);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Play Classic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
