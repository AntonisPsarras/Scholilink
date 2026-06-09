import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_preference.dart';

/// Injected in [main] after [SharedPreferences.getInstance].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden via ProviderScope in main()',
  );
});

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceNotifier, ThemePreference>(
      ThemePreferenceNotifier.new,
    );

class ThemePreferenceNotifier extends Notifier<ThemePreference> {
  @override
  ThemePreference build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(ThemePreference.storageKey);
    return ThemePreference.fromStorage(raw);
  }

  Future<void> setPreference(ThemePreference value) async {
    state = value;
    await ref
        .read(sharedPreferencesProvider)
        .setString(ThemePreference.storageKey, value.toStorageString());
  }
}
