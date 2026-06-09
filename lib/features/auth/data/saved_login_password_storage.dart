import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the "remember me" login password outside of [SharedPreferences].
class SavedLoginPasswordStorage {
  SavedLoginPasswordStorage._();

  static const _prefsKey = 'saved_password';
  static const _secureKey = 'saved_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Moves any legacy plaintext password from SharedPreferences into secure
  /// storage, then removes it from prefs (upgrade migration).
  static Future<void> migrateLegacyFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_prefsKey);
    if (legacy == null) return;

    try {
      await _storage.write(key: _secureKey, value: legacy);
    } catch (_) {
      // Keystore / secure storage unavailable; still remove insecure copy.
    }
    await prefs.remove(_prefsKey);
  }

  static Future<String?> read() async {
    try {
      return await _storage.read(key: _secureKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String password) async {
    try {
      await _storage.write(key: _secureKey, value: password);
    } catch (_) {
      // Ignore; remember-me password may not persist if secure storage fails.
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _secureKey);
    } catch (_) {
      // Ignore.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
