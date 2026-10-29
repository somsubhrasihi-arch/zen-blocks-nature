import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'campaign.dart';
import 'play_modes.dart';

class PlayerProgress {
  int coins = 0, lifetimeLines = 0, runs = 0;
  int sprintBestMs = 0, sprintWins = 0, dailyWins = 0, dailyStreak = 0, bestDailyStreak = 0;
  String? lastDailyDay, practiceDay;
  int practiceCoins = 0;
  int activeDailyStreak(String day) {
    final previous = parseDay(lastDailyDay), current = parseDay(day);
    if (previous == null || current == null) return 0;
    final gap = current.difference(previous).inDays;
    return gap >= 0 && gap <= 1 ? dailyStreak : 0;
  }
  bool canClaimDaily(String day) => parseDay(day) != null && (lastDailyDay == null || day.compareTo(lastDailyDay!) > 0);
  final Map<int, int> stars = {};
  final Set<String> owned = {'skin:glass', 'effect:sparks'};
  final Set<String> earned = {};
  final List<String> settledRuns = [];
  String skin = 'glass', effect = 'sparks';
  int get totalStars => stars.values.fold(0, (a, b) => a + b);
  bool unlocked(JourneyStage stage) => (stage.id == 1 || (stars[stage.id - 1] ?? 0) > 0) && totalStars >= stage.requiredStars;
  int achievementValue(String id) => switch (id) {
    'firstLine' || 'hundredLines' => lifetimeLines,
    'tenRuns' => runs,
    'firstStage' || 'tenStages' || 'allStages' => stars.length,
    'sixtyStars' => totalStars,
    'sprintFirst' => sprintWins,
    'sprintSwift' => sprintBestMs > 0 && sprintBestMs <= 300000 ? 1 : 0,
    'dailyFirst' || 'dailySeven' => dailyWins,
    'streakSeven' => bestDailyStreak,
    _ => 0,
  };
  Map<String, dynamic> toJson() => {'version': 1, 'coins': coins, 'lines': lifetimeLines, 'runs': runs,
    'stars': stars.map((k, v) => MapEntry('$k', v)), 'owned': owned.toList(), 'earned': earned.toList(),
    'settled': settledRuns, 'skin': skin, 'effect': effect,
    'sprintBestMs': sprintBestMs, 'sprintWins': sprintWins, 'dailyWins': dailyWins,
    'dailyStreak': dailyStreak, 'bestDailyStreak': bestDailyStreak, 'lastDailyDay': lastDailyDay,
    'practiceDay': practiceDay, 'practiceCoins': practiceCoins};
  static PlayerProgress fromJson(Object? raw) {
    final p = PlayerProgress();
    if (raw is! Map || raw['version'] != 1) return p;
    int count(String key) => raw[key] is int ? (raw[key] as int).clamp(0, 1000000000).toInt() : 0;
    p.sprintBestMs = count('sprintBestMs'); p.sprintWins = count('sprintWins');
    p.dailyWins = count('dailyWins'); p.dailyStreak = count('dailyStreak'); p.bestDailyStreak = count('bestDailyStreak');
    if (raw['lastDailyDay'] is String && parseDay(raw['lastDailyDay']) != null) p.lastDailyDay = raw['lastDailyDay'];
    if (raw['practiceDay'] is String && parseDay(raw['practiceDay']) != null) p.practiceDay = raw['practiceDay'];
    p.practiceCoins = count('practiceCoins').clamp(0, 100).toInt();
    p.coins = count('coins'); p.lifetimeLines = count('lines'); p.runs = count('runs');
    if (raw['stars'] is Map) {
      (raw['stars'] as Map).forEach((k, v) {
        final id = int.tryParse('$k');
        if (stageForId(id) != null && v is int && v >= 1 && v <= 3) p.stars[id!] = v;
      });
    }
    if (raw['owned'] is List) p.owned.addAll((raw['owned'] as List).whereType<String>().where((id) => itemForId(id) != null));
    if (raw['earned'] is List) p.earned.addAll((raw['earned'] as List).whereType<String>().where((id) => achievements.any((a) => a.id == id)));
    if (raw['settled'] is List) p.settledRuns.addAll((raw['settled'] as List).whereType<String>().take(256));
    if (p.owned.contains('skin:${raw['skin']}')) p.skin = raw['skin'];
    if (p.owned.contains('effect:${raw['effect']}')) p.effect = raw['effect'];
    return p;
  }
}

class RunReward {
  const RunReward(this.coins, this.stars, this.achievements, {this.duplicate = false, this.details = const {}, this.note});
  final Map<String, int> details;
  final String? note;
  final int coins, stars;
  final List<String> achievements;
  final bool duplicate;
}

enum PurchaseResult { purchased, owned, insufficient, unavailable }

/// One durable record commits the wallet, ownership and reward receipt together.
/// This offline wallet is for earned coins. Paid balances require a verified backend.
class ProgressStore extends ChangeNotifier {
  ProgressStore({DateTime Function()? utcNow}) : _utcNow = utcNow ?? DateTime.now;
  final DateTime Function() _utcNow;
  static const key = 'tblock.progress.v1';
  PlayerProgress data = PlayerProgress();
  Future<void> _writes = Future.value();
  Future<void>? _load;
  bool _disposed = false;
  Future<void> load() => _load ??= _loadData();
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    try { data = PlayerProgress.fromJson(jsonDecode(prefs.getString(key) ?? 'null')); }
    catch (_) { data = PlayerProgress(); }
  }
  Future<T> _transaction<T>(T Function(PlayerProgress) action) {
    final result = _writes.catchError((_) {}).then((_) async {
      await load();
      final next = PlayerProgress.fromJson(data.toJson());
      final value = action(next);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, jsonEncode(next.toJson()))) throw StateError('Progress could not be saved');
      data = next;
      if (!_disposed) notifyListeners();
      return value;
    });
    _writes = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }
  Future<RunReward> settle({required String runId, required int lines, required int pieces,
    int? stageId, bool completed = false, int stars = 0, PlayMode? mode,
    String? dailyDay, int elapsedMs = 0, int score = 0, int obstaclesCleared = 0}) => _transaction((p) {
      if (runId.isEmpty) throw ArgumentError('A run receipt is required');
      if (p.settledRuns.contains(runId)) return const RunReward(0, 0, [], duplicate: true, note: 'Reward already saved');
      final today = utcDay(_utcNow());
      final selectedMode = mode ?? (stageId == null ? PlayMode.classic : PlayMode.journey);
      final stage = selectedMode == PlayMode.journey ? stageForId(stageId) : null;
      final won = completed && stage != null && p.unlocked(stage);
      final oldStars = stage == null ? 0 : p.stars[stage.id] ?? 0;
      final earnedStars = won ? stars.clamp(1, 3).toInt() : 0;
      final details = <String, int>{};
      String? note;
      void add(String label, int amount) { if (amount > 0) details[label] = amount; }
      int practice(int requested) {
        if (p.practiceDay != null && today.compareTo(p.practiceDay!) < 0) return 0;
        if (p.practiceDay != today) { p.practiceDay = today; p.practiceCoins = 0; }
        final amount = requested.clamp(0, 100 - p.practiceCoins).toInt();
        p.practiceCoins += amount;
        if (amount < requested) note = 'Replay coin limit: 100 per UTC day';
        return amount;
      }
      switch (selectedMode) {
        case PlayMode.classic:
          add('Lines cleared', lines.clamp(0, 200).toInt() * 5);
          break;
        case PlayMode.journey:
          if (won) {
            if (oldStars == 0) { add('First stage clear', 70); add('Stage stars', earnedStars * 10); }
            else { add('Replay', practice(12)); add('Improved stars', (earnedStars-oldStars).clamp(0, 3).toInt()*10); }
            if (earnedStars > oldStars) p.stars[stage.id] = earnedStars;
          } else { add('Lines cleared', practice((lines * 2).clamp(0, 20).toInt())); }
          break;
        case PlayMode.sprint:
          if (completed && lines >= 40 && elapsedMs > 0) {
            final first = p.sprintWins == 0;
            final best = p.sprintBestMs;
            final speed = elapsedMs <= 180000 ? 40 : elapsedMs <= 300000 ? 25 : elapsedMs <= 480000 ? 10 : 0;
            if (first) { add('Sprint finish', 60); add('Speed bonus', speed); }
            else { add('Sprint finish + speed', practice(60 + speed)); }
            if (best > 0 && elapsedMs <= best - 1000) add('New personal best', 15);
            if (best == 0 || elapsedMs < best) p.sprintBestMs = elapsedMs;
            p.sprintWins++;
            if (best == 0 || elapsedMs < best) note = 'New Sprint personal best!';
          } else {
            note = 'Finish all 40 lines to earn Sprint coins';
          }
          break;
        case PlayMode.daily:
          final challenge = dailyForDay(dailyDay);
          final goal = switch (challenge?.goal) {
            StageGoal.lines => lines, StageGoal.score => score, StageGoal.excavation => obstaclesCleared, _ => 0,
          };
          final success = completed && challenge != null && goal >= challenge.target;
          if (success && dailyDay == today && p.canClaimDaily(today)) {
            final previous = parseDay(p.lastDailyDay);
            p.dailyStreak = previous != null && parseDay(today)!.difference(previous).inDays == 1 ? p.dailyStreak + 1 : 1;
            if (p.dailyStreak > p.bestDailyStreak) p.bestDailyStreak = p.dailyStreak;
            p.lastDailyDay = today; p.dailyWins++;
            add('Daily Challenge', 120); add('Daily streak', (p.dailyStreak-1).clamp(0, 6).toInt()*10);
          } else if (dailyDay != today) { note = 'Past challenge · Practice only'; }
          else if (!p.canClaimDaily(today)) { note = 'Daily reward collected · Practice only'; }
          else { note = 'Complete the objective to earn today’s reward'; }
          break;
      }
      p.lifetimeLines += lines.clamp(0, 10000).toInt();
      if (lines > 0 || completed) p.runs++;
      final unlocked = <String>[];
      for (final a in achievements) {
        if (!p.earned.contains(a.id) && p.achievementValue(a.id) >= a.target) {
          p.earned.add(a.id); unlocked.add(a.name); add(a.name, a.reward);
        }
      }
      final coins = details.values.fold(0, (a, b) => a + b);
      p.coins += coins;
      p.settledRuns.add(runId);
      if (p.settledRuns.length > 256) p.settledRuns.removeAt(0);
      return RunReward(coins, earnedStars, unlocked, details: details, note: note);
    });
  Future<PurchaseResult> buy(String id) => _transaction((p) {
    final item = itemForId(id);
    if (item == null) return PurchaseResult.unavailable;
    if (p.owned.contains(id)) return PurchaseResult.owned;
    if (p.coins < item.price) return PurchaseResult.insufficient;
    p.coins -= item.price;
    p.owned.add(id);
    return PurchaseResult.purchased;
  });
  Future<bool> equip(String id) => _transaction((p) {
    final item = itemForId(id);
    if (item == null || !p.owned.contains(id)) return false;
    if (item.kind == CosmeticKind.skin) { p.skin = id.split(':').last; }
    else { p.effect = id.split(':').last; }
    return true;
  });
  @override
  void dispose() { _disposed = true; super.dispose(); }
}
