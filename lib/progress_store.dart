import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'campaign.dart';

class PlayerProgress {
  int coins = 0, lifetimeLines = 0, runs = 0;
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
    _ => 0,
  };
  Map<String, dynamic> toJson() => {'version': 1, 'coins': coins, 'lines': lifetimeLines, 'runs': runs,
    'stars': stars.map((k, v) => MapEntry('$k', v)), 'owned': owned.toList(), 'earned': earned.toList(),
    'settled': settledRuns, 'skin': skin, 'effect': effect};
  static PlayerProgress fromJson(Object? raw) {
    final p = PlayerProgress();
    if (raw is! Map || raw['version'] != 1) return p;
    int count(String key) => raw[key] is int ? (raw[key] as int).clamp(0, 1000000000).toInt() : 0;
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
  const RunReward(this.coins, this.stars, this.achievements, {this.duplicate = false});
  final int coins, stars;
  final List<String> achievements;
  final bool duplicate;
}

enum PurchaseResult { purchased, owned, insufficient, unavailable }

/// One durable record commits the wallet, ownership and reward receipt together.
/// This offline wallet is for earned coins. Paid balances require a verified backend.
class ProgressStore extends ChangeNotifier {
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
    int? stageId, bool completed = false, int stars = 0}) => _transaction((p) {
      if (p.settledRuns.contains(runId)) return const RunReward(0, 0, [], duplicate: true);
      final stage = stageForId(stageId);
      final won = completed && stage != null && p.unlocked(stage);
      final oldStars = stage == null ? 0 : p.stars[stage.id] ?? 0;
      final earnedStars = won ? stars.clamp(1, 3).toInt() : 0;
      var coins = stage == null ? (lines.clamp(0, 200) * 5 + (pieces ~/ 10).clamp(0, 20)).toInt()
        : won ? (oldStars == 0 ? 70 + earnedStars * 10 : 12 + (earnedStars - oldStars).clamp(0, 3).toInt() * 10)
        : (lines * 2).clamp(0, 20).toInt();
      if (won && earnedStars > oldStars) p.stars[stage.id] = earnedStars;
      p.lifetimeLines += lines.clamp(0, 10000).toInt();
      p.runs++;
      final unlocked = <String>[];
      for (final a in achievements) {
        if (!p.earned.contains(a.id) && p.achievementValue(a.id) >= a.target) {
          p.earned.add(a.id); unlocked.add(a.name); coins += a.reward;
        }
      }
      p.coins += coins;
      p.settledRuns.add(runId);
      if (p.settledRuns.length > 256) p.settledRuns.removeAt(0);
      return RunReward(coins, earnedStars, unlocked);
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
