import 'play_modes.dart';

String utcWeek(DateTime now) {
  final day = DateTime.utc(
    now.toUtc().year,
    now.toUtc().month,
    now.toUtc().day,
  );
  return utcDay(day.subtract(Duration(days: day.weekday - 1)));
}

int visitReward(int collectedDays) => (collectedDays + 1) % 7 == 0 ? 100 : 25;

class WeeklyMission {
  const WeeklyMission(this.id, this.title, this.target, this.coins);
  final String id, title;
  final int target, coins;
}

const weeklyMissions = [
  WeeklyMission('runs', 'Finish 10 qualifying runs', 10, 100),
  WeeklyMission('lines', 'Clear 75 lines', 75, 150),
  WeeklyMission('wins', 'Complete 5 objectives', 5, 150),
];

class DailyRecord {
  const DailyRecord({
    required this.elapsedMs,
    required this.pieces,
    required this.score,
  });
  final int elapsedMs, pieces, score;
  bool beats(DailyRecord old) =>
      elapsedMs < old.elapsedMs ||
      (elapsedMs == old.elapsedMs &&
          (pieces < old.pieces || (pieces == old.pieces && score > old.score)));
  Map<String, dynamic> toJson() => {
    'elapsedMs': elapsedMs,
    'pieces': pieces,
    'score': score,
  };
  static DailyRecord? fromJson(Object? raw) {
    if (raw is! Map ||
        raw['elapsedMs'] is! int ||
        raw['pieces'] is! int ||
        raw['score'] is! int)
      return null;
    final ms = raw['elapsedMs'] as int,
        pieces = raw['pieces'] as int,
        score = raw['score'] as int;
    if (ms < 1 || ms > 864000000 || pieces < 1 || pieces > 100000 || score < 0)
      return null;
    return DailyRecord(elapsedMs: ms, pieces: pieces, score: score);
  }
}

String friendChallengeCode(String day) => 'TBD-${day.replaceAll('-', '')}';
String? dayFromFriendCode(String input) {
  final match = RegExp(r'^TBD-(\d{4})(\d{2})(\d{2})$')
      .firstMatch(input.trim().toUpperCase());
  if (match == null) return null;
  final day = '${match[1]}-${match[2]}-${match[3]}';
  return parseDay(day) == null ? null : day;
}

String challengeShareText(String day, DailyRecord? record) {
  final challenge = dailyForDay(day)!;
  final result = record == null
      ? 'Can you complete it?'
      : 'My best: ${formatRunTime(record.elapsedMs)} · ${record.pieces} blocks · ${record.score} points. Can you beat my time?';
  return 'T-BLOCK friend challenge\n${challenge.name} · ${challenge.objective}\nCode: ${friendChallengeCode(day)}\n$result\nOpen Friend challenges in T-BLOCK and enter the code. Same puzzle and block sequence for both players.\nGet T-BLOCK: https://github.com/somsubhrasihi-arch/zen-blocks-nature';
}
