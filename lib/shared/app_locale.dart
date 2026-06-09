import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../theme/theme_providers.dart';

const String _localeStorageKey = 'app_locale';
const String _defaultLanguage = 'el';
const Set<String> _supportedLanguageCodes = {'el', 'en'};

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedLanguage =
        prefs.getString(_localeStorageKey) ?? _defaultLanguage;
    final userLanguage = ref.watch(
      authStateProvider.select((async) => async.valueOrNull?.preferredLanguage),
    );
    final activeLanguage = _normalizeLanguage(userLanguage ?? storedLanguage);
    return Locale(activeLanguage);
  }

  Future<void> setLanguage(
    String languageCode, {
    bool persistToProfile = true,
  }) async {
    final normalized = _normalizeLanguage(languageCode);
    state = Locale(normalized);

    await ref
        .read(sharedPreferencesProvider)
        .setString(_localeStorageKey, normalized);

    if (!persistToProfile) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.preferredLanguage == normalized) return;

    await ref
        .read(authRepositoryProvider)
        .updateUserProfile(user.copyWith(preferredLanguage: normalized));
  }

  String _normalizeLanguage(String languageCode) {
    if (_supportedLanguageCodes.contains(languageCode)) return languageCode;
    return _defaultLanguage;
  }
}
