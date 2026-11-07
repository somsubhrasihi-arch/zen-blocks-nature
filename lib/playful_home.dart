import 'package:flutter/material.dart';

import 'arcade_ui.dart';
import 'customization.dart';
import 't_block_mark.dart';

/// A quiet opening screen; secondary features live one tab away.
class PlayfulHome extends StatefulWidget {
  const PlayfulHome({
    super.key,
    required this.palette,
    required this.coins,
    required this.best,
    required this.stage,
    required this.loading,
    required this.hasSave,
    required this.showPractice,
    required this.onPlay,
    required this.onContinue,
    required this.onJourney,
    required this.onSprint,
    required this.onDaily,
    required this.onShop,
    required this.onRewards,
    required this.onFriends,
    required this.onAchievements,
    required this.onSettings,
    required this.onHelp,
    required this.onPractice,
  });
  final GamePalette palette;
  final int coins, best, stage;
  final bool loading, hasSave, showPractice;
  final VoidCallback onPlay,
      onContinue,
      onJourney,
      onSprint,
      onDaily,
      onShop,
      onRewards,
      onFriends,
      onAchievements,
      onSettings,
      onHelp,
      onPractice;
  @override
  State<PlayfulHome> createState() => _PlayfulHomeState();
}

class _PlayfulHomeState extends State<PlayfulHome> {
  int tab = 0;
  static const ink = Color(0xFF41255F);
  static const secondary = Color(0xFF695775);
  Widget tile(
    String title,
    String detail,
    IconData icon,
    Color color,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xFFFFFBF4),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.loading ? null : action,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: secondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: secondary),
            ],
          ),
        ),
      ),
    ),
  );
  Widget playButton(
    String label,
    VoidCallback callback, {
    Color color = const Color(0xFFD32B79),
  }) => SizedBox(
    width: double.infinity,
    child: ArcadeButton(
      label: label,
      icon: Icons.play_arrow_rounded,
      onPressed: widget.loading ? null : callback,
      accent: color,
      surface: color,
      primary: true,
      height: 66,
    ),
  );
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
          child: Row(
            children: [
              TBlockMark(size: 30, color: const Color(0xFFFFCD55)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'T-BLOCK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Semantics(
                label: '${widget.coins} Block Coins',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9A4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFA76100),
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.coins}',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: widget.onSettings,
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('home-tab-$tab'),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0) ...[
                      const SizedBox(height: 4),
                      const Text(
                        gameTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFE6FA),
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Semantics(
                        label: 'A smiling tower of colorful toy blocks',
                        image: true,
                        child: AspectRatio(
                          aspectRatio: 2.2,
                          child: CustomPaint(painter: ToyIslandPainter()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF4),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22331B53),
                              offset: Offset(0, 7),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'A little play. A big smile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.hasSave
                                  ? 'Your game is right where you left it.'
                                  : 'Find your flow, one block at a time.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: secondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            playButton(
                              widget.hasSave ? 'Continue' : 'Play Classic',
                              widget.hasSave
                                  ? widget.onContinue
                                  : widget.onPlay,
                            ),
                            if (widget.hasSave)
                              TextButton(
                                onPressed: widget.loading
                                    ? null
                                    : widget.onPlay,
                                child: const Text(
                                  'Start new game',
                                  style: TextStyle(color: ink),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Your best · ${widget.best}',
                              style: const TextStyle(
                                color: secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      tile(
                        'Journey · Stage ${widget.stage}',
                        'Explore worlds. Collect stars.',
                        Icons.route_rounded,
                        const Color(0xFF7250B8),
                        widget.onJourney,
                      ),
                      if (widget.showPractice)
                        Align(
                          child: TextButton.icon(
                            onPressed: widget.onPractice,
                            icon: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            label: const Text(
                              'Practice',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (tab == 1) ...[
                      heading(
                        'Pick a little challenge',
                        'A fresh goal, at your own pace.',
                      ),
                      tile(
                        'Daily Challenge',
                        'One new puzzle every day.',
                        Icons.today_rounded,
                        const Color(0xFF167B64),
                        widget.onDaily,
                      ),
                      tile(
                        'Sprint',
                        'Clear 40 lines. Beat your best time.',
                        Icons.timer_rounded,
                        const Color(0xFFCA4B2B),
                        widget.onSprint,
                      ),
                      tile(
                        'Friend challenges',
                        'Share a puzzle. Compare your results.',
                        Icons.people_alt_rounded,
                        const Color(0xFF7250B8),
                        widget.onFriends,
                      ),
                      tile(
                        'Daily rewards & lives',
                        'Daily quests, weekly missions and gifts.',
                        Icons.card_giftcard_rounded,
                        const Color(0xFFAD3476),
                        widget.onRewards,
                      ),
                    ],
                    if (tab == 2) ...[
                      heading(
                        'Your little clubhouse',
                        'All your extras, together.',
                      ),
                      tile(
                        'Daily rewards & lives',
                        'Collect gifts and check your goals.',
                        Icons.card_giftcard_rounded,
                        const Color(0xFFAD3476),
                        widget.onRewards,
                      ),
                      tile(
                        'Achievements',
                        'Celebrate your favorite milestones.',
                        Icons.emoji_events_rounded,
                        const Color(0xFFA76100),
                        widget.onAchievements,
                      ),
                      tile(
                        'Practice',
                        'Learn the moves with a friendly guide.',
                        Icons.school_rounded,
                        const Color(0xFF167B64),
                        widget.onPractice,
                      ),
                      tile(
                        'How to play',
                        'A quick reminder of the rules.',
                        Icons.sports_esports_rounded,
                        const Color(0xFF7250B8),
                        widget.onHelp,
                      ),
                    ],
                    if (widget.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Material(
          color: const Color(0xFFFFFBF4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                nav(
                  'Home',
                  Icons.home_rounded,
                  0,
                  () => setState(() => tab = 0),
                ),
                nav(
                  'Challenges',
                  Icons.extension_rounded,
                  1,
                  () => setState(() => tab = 1),
                ),
                nav('Shop', Icons.shopping_bag_rounded, -1, widget.onShop),
                nav(
                  'More',
                  Icons.grid_view_rounded,
                  2,
                  () => setState(() => tab = 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget heading(String title, String detail) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: const TextStyle(color: Color(0xFFFFE6FA), fontSize: 14),
        ),
      ],
    ),
  );
  Widget nav(String label, IconData icon, int index, VoidCallback action) =>
      Expanded(
        child: Semantics(
          selected: tab == index,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.loading ? null : action,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: tab == index ? const Color(0xFFB32972) : secondary,
                    size: 25,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tab == index ? const Color(0xFFB32972) : secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Original, resolution-independent artwork: no downloaded or branded assets.
class ToyIslandPainter extends CustomPainter {
  const ToyIslandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 178);
    canvas.drawOval(
      const Rect.fromLTWH(30, 138, 260, 30),
      Paint()..color = const Color(0xFFB8EDBC),
    );
    canvas.drawOval(
      const Rect.fromLTWH(45, 135, 230, 20),
      Paint()..color = const Color(0xFFE2F4B6),
    );
    void block(double x, double y, Color color, {bool face = false}) {
      final rect = Rect.fromLTWH(x, y, 43, 43);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(0, 4),
          const Radius.circular(12),
        ),
        Paint()..color = Color.lerp(color, const Color(0xFF41255F), .3)!,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, .25)!, color],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 7, y + 5, 22, 4),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: .5),
      );
      if (face) {
        final eyes = Paint()..color = const Color(0xFF41255F);
        canvas.drawCircle(Offset(x + 14, y + 22), 2.4, eyes);
        canvas.drawCircle(Offset(x + 29, y + 22), 2.4, eyes);
        canvas.drawArc(
          Rect.fromLTWH(x + 17, y + 24, 10, 8),
          0,
          3.14,
          false,
          Paint()
            ..color = const Color(0xFF41255F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    block(92, 91, const Color(0xFFFFC44D));
    block(138, 91, const Color(0xFFFFC44D), face: true);
    block(184, 91, const Color(0xFFFFC44D));
    block(138, 45, const Color(0xFFFFC44D));
    block(46, 91, const Color(0xFF48C9CF), face: true);
    block(230, 91, const Color(0xFFF487B1), face: true);
    for (final point in [
      const Offset(70, 45),
      const Offset(247, 39),
      const Offset(212, 15),
    ]) {
      final path = Path()
        ..moveTo(point.dx, point.dy - 8)
        ..lineTo(point.dx + 3, point.dy - 2)
        ..lineTo(point.dx + 8, point.dy)
        ..lineTo(point.dx + 3, point.dy + 2)
        ..lineTo(point.dx, point.dy + 8)
        ..lineTo(point.dx - 3, point.dy + 2)
        ..lineTo(point.dx - 8, point.dy)
        ..lineTo(point.dx - 3, point.dy - 2)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFE8A0));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ToyIslandPainter oldDelegate) => false;
}

class PlayfulBackdrop extends CustomPainter {
  const PlayfulBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .07);
    canvas.drawCircle(
      Offset(size.width * .05, size.height * .22),
      size.width * .55,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * .7),
      size.width * .7,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * .4, size.height * 1.15),
      size.width * .8,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PlayfulBackdrop oldDelegate) => false;
}
