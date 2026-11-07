import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';

/// Ordered writes prevent an older delayed save from replacing a newer game.
class SessionStore {
  static const key = 'savedGame.v1';
  static const backupKey = '$key.backup';
  bool recoveredFromBackup = false;
  Future<void> _writes = Future.value();

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    final probe = ZenGame();
    try { if (probe.restoreState(jsonDecode(raw))) return probe.saveState(); }
    catch (_) {} finally { probe.dispose(); }
    return null;
  }
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = _decode(prefs.getString(key));
    if (primary != null) {
      try { await prefs.setString(backupKey, jsonEncode(primary)); } catch (_) {}
      return primary;
    }
    final backup = _decode(prefs.getString(backupKey));
    if (backup != null) {
      recoveredFromBackup = true;
      try { await prefs.setString(key, jsonEncode(backup)); } catch (_) {}
      return backup;
    }
    await prefs.remove(backupKey); await prefs.remove(key);
    return null;
  }

  Future<void> save(Map<String, dynamic>? snapshot) {
    // Serialize immediately, before any subsequent game movement.
    final encoded = snapshot == null ? null : jsonEncode(snapshot);
    _writes = _writes.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (encoded == null) {
        // Remove recovery first so a deliberate clear cannot resurrect an old run.
        await prefs.remove(backupKey); await prefs.remove(key);
      } else {
        if (!await prefs.setString(key, encoded)) throw StateError('Game could not be saved');
        try { await prefs.setString(backupKey, encoded); } catch (_) {}
      }
    });
    return _writes;
  }
}
