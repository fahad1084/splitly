import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

// ── Last loaded data, kept on the phone for opening without internet ──────────
// Only the groups list and the balances (small JSON), one copy per user.
// Read ONLY when loading from the server fails because there is no internet.
// Cleared on sign out, so the next person on this phone never sees it.
class OfflineCache {
  static const _prefix = 'offline_cache:';

  static String _key(String name, String userId) => '$_prefix$name:$userId';

  static Future<void> save(String name, String userId, Object json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(name, userId), jsonEncode(json));
    } catch (e) {
      logDebug('=== OFFLINE CACHE save $name: $e ===');
    }
  }

  /// The saved JSON, or null when there is none (or it can't be read).
  static Future<dynamic> load(String name, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_key(name, userId));
      return text == null ? null : jsonDecode(text);
    } catch (e) {
      logDebug('=== OFFLINE CACHE load $name: $e ===');
      return null;
    }
  }

  /// Removes every saved copy (all users).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        await prefs.remove(key);
      }
    } catch (e) {
      logDebug('=== OFFLINE CACHE clear: $e ===');
    }
  }
}
