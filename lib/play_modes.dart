import 'campaign.dart';

enum PlayMode { classic, journey, sprint, daily }
String modeName(PlayMode mode) => switch (mode) {
  PlayMode.classic => 'Classic', PlayMode.journey => 'Journey', PlayMode.sprint => 'Sprint', PlayMode.daily => 'Daily Challenge',
};
String utcDay(DateTime time) => time.toUtc().toIso8601String().substring(0, 10);
DateTime? parseDay(String? day) {
  if (day == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return null;
  final date = DateTime.tryParse('${day}T00:00:00Z');
  return date != null && utcDay(date) == day && date.year >= 2020 && date.year < 2200 ? date : null;
}
String formatRunTime(int milliseconds) {
  final ms = milliseconds.clamp(0, 864000000).toInt();
  return '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${ms ~/ 100 % 10}';
}

class DailyChallenge {
  const DailyChallenge(this.day, this.name, this.goal, this.target, this.seed);
  final String day, name;
  final StageGoal goal;
  final int target, seed;
  int get startLevel => 2;
  int get obstacleCount => goal == StageGoal.excavation ? target : 0;
  String get objective => switch (goal) {
    StageGoal.lines => 'Clear $target lines', StageGoal.score => 'Reach $target points',
    StageGoal.excavation => 'Clear $target marked rows',
  };
}
DailyChallenge? dailyForDay(String? day) {
  final date = parseDay(day);
  if (date == null) return null;
  final index = date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  final seed = date.year * 10000 + date.month * 100 + date.day;
  return switch (index % 3) {
    0 => DailyChallenge(day!, 'Daily Line Quest', StageGoal.lines, 8 + (index ~/ 3) % 3, seed),
    1 => DailyChallenge(day!, 'Daily Score Quest', StageGoal.score, 2000 + (index % 4) * 250, seed),
    _ => DailyChallenge(day!, 'Daily Dig', StageGoal.excavation, 4 + index % 2, seed),
  };
}
