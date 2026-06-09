import 'package:flutter/material.dart';

/// Persisted user choice for app appearance (maps to [ThemeMode]).
enum ThemePreference {
  light,
  dark,
  system;

  static const String _storageKey = 'app_theme_preference_v1';

  static String get storageKey => _storageKey;

  ThemeMode get themeMode => switch (this) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  };

  /// Deserialize from [SharedPreferences] string (null or unknown → system).
  static ThemePreference fromStorage(String? raw) {
    switch (raw) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      case 'system':
        return ThemePreference.system;
      default:
        return ThemePreference.system;
    }
  }

  String toStorageString() => name;
}
