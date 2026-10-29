import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';

/// Ordered writes prevent an older delayed save from replacing a newer game.
class SessionStore {
  static const key = 'savedGame.v1';
  Future<void> _writes = Future.value();

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final probe = ZenGame();
    try {
      if (probe.restoreState(jsonDecode(raw))) return probe.saveState();
    } catch (_) {
      // A damaged or obsolete save should never prevent a new game.
    } finally {
      probe.dispose();
    }
    await prefs.remove(key);
    return null;
  }

  Future<void> save(Map<String, dynamic>? snapshot) {
    // Serialize immediately, before any subsequent game movement.
    final encoded = snapshot == null ? null : jsonEncode(snapshot);
    _writes = _writes.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (encoded == null) { await prefs.remove(key); }
      else { await prefs.setString(key, encoded); }
    });
    return _writes;
  }
}
