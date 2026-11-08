import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'arcade_ui.dart';
import 'customization.dart';
import 'playful_style.dart';
import 'engagement.dart';
import 'play_modes.dart';
import 'progress_store.dart';

Future<void> shareFriendChallenge(String day, DailyRecord? record) async {
  await SharePlus.instance.share(
    ShareParams(
      text: challengeShareText(day, record),
      title: 'T-BLOCK friend challenge',
    ),
  );
}

class FriendChallenges extends StatefulWidget {
  const FriendChallenges({
    super.key,
    required this.palette,
    required this.progress,
    required this.onChallenge,
  });
  final GamePalette palette;
  final ProgressStore progress;
  final ValueChanged<String> onChallenge;
  @override
  State<FriendChallenges> createState() => _FriendChallengesState();
}

class _FriendChallengesState extends State<FriendChallenges> {
  final code = TextEditingController();
  String? error;
  bool sharing = false;
  GamePalette get p => widget.palette.playful;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Widget button(String label, IconData icon, VoidCallback? action) =>
      ArcadeButton(
        label: label,
        icon: icon,
        onPressed: action,
        accent: p.accent,
        surface: p.control,
        height: 50,
      );
  Future<void> share(String day) async {
    setState(() => sharing = true);
    try {
      await shareFriendChallenge(day, widget.progress.data.dailyRecords[day]);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing is unavailable. You can copy the challenge code.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  void open(String day) {
    Navigator.pop(context);
    widget.onChallenge(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = utcDay(widget.progress.now),
        challenge = dailyForDay(utcDay(widget.progress.now))!;
    final records = widget.progress.data.dailyRecords;
    final days = records.keys.toList()..sort((a, b) => b.compareTo(a));
    Widget card(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.accent.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    return Theme(data: buddyTheme(p), child: Scaffold(
      backgroundColor: p.background.first,
      appBar: AppBar(
        title: const Text('Friend challenges'),
        backgroundColor: p.panel,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            card([
              Text(
                'Same puzzle. Your best time.',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Send a challenge to a friend. Play separately with the same block sequence, then share your results. Fastest completion wins your friendly race.',
              ),
              const SizedBox(height: 16),
              Text(
                challenge.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(challenge.objective),
              const SizedBox(height: 12),
              SelectableText(
                friendChallengeCode(today),
                style: TextStyle(
                  color: buddyGold,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                records[today] == null
                    ? 'Complete today’s challenge to set your time.'
                    : 'Your best: ${formatRunTime(records[today]!.elapsedMs)} · ${records[today]!.pieces} blocks',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: button(
                  'Play today’s challenge',
                  Icons.play_arrow_rounded,
                  () => open(today),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: button(
                  'Share with a friend',
                  Icons.share_rounded,
                  sharing ? null : () => share(today),
                ),
              ),
            ]),
            card([
              Text(
                'Got a challenge code?',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                maxLength: 12,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Challenge code',
                  hintText: friendChallengeCode(today),
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: button(
                  'Open challenge',
                  Icons.sports_esports_rounded,
                  () {
                    final day = dayFromFriendCode(code.text);
                    if (day == null || day.compareTo(today) > 0) {
                      setState(
                        () => error =
                            'Enter a valid code for today or an earlier day.',
                      );
                      return;
                    }
                    open(day);
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Earlier challenges are practice. Daily coins are awarded only for today’s first completion.',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ]),
            card([
              Text(
                'Your recent Daily times',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Results stay on this device. Share a result to compare with your friend.',
                style: TextStyle(color: p.muted),
              ),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'Your first completed Daily Challenge will appear here.',
                  ),
                ),
              for (final day in days)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(day),
                  subtitle: Text(
                    '${formatRunTime(records[day]!.elapsedMs)} · ${records[day]!.pieces} blocks',
                  ),
                  trailing: IconButton(
                    tooltip: 'Share result for $day',
                    onPressed: sharing ? null : () => share(day),
                    icon: const Icon(Icons.share_rounded),
                  ),
                ),
            ]),
          ],
        ),
      ),
    ));
  }
}
