import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Device / animation budget (blur, breathing, liquid background, jelly scroll).
/// Initialized in [main] via [PerformanceConfig.initialize].
export '../shared/performance_config.dart';

class Config {
  /// Prefer [canonical], then any [aliases] (e.g. names used in `assets/.env.example`).
  static String _envFirst(
    String canonical,
    List<String> aliases,
    String fallback,
  ) {
    final keys = [canonical, ...aliases];
    try {
      for (final k in keys) {
        final v = dotenv.env[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
    } catch (_) {
      // Dotenv is not initialized yet (or file missing). Use safe fallback.
    }
    return fallback;
  }

  // Firebase API Keys
  static String get webApiKey =>
      _envFirst('FIREBASE_WEB_API_KEY', const [], 'YOUR_API_KEY');
  static String get androidApiKey =>
      _envFirst('FIREBASE_ANDROID_API_KEY', const [], 'YOUR_API_KEY');
  static String get iosApiKey =>
      _envFirst('FIREBASE_IOS_API_KEY', const [], 'YOUR_API_KEY');
  static String get macosApiKey => _envFirst('FIREBASE_MACOS_API_KEY', const [
    'FIREBASE_IOS_API_KEY',
  ], 'YOUR_API_KEY');

  // Firebase Identifiers (aliases match `assets/.env.example` / common Firebase export names)
  static String get webAppId => _envFirst('FIREBASE_WEB_APP_ID', const [
    'FIREBASE_APP_ID_WEB',
  ], 'YOUR_APP_ID');
  static String get androidAppId => _envFirst('FIREBASE_ANDROID_APP_ID', const [
    'FIREBASE_APP_ID_ANDROID',
  ], 'YOUR_APP_ID');
  static String get iosAppId => _envFirst('FIREBASE_IOS_APP_ID', const [
    'FIREBASE_APP_ID_IOS',
  ], 'YOUR_APP_ID');
  static String get macosAppId => _envFirst('FIREBASE_MACOS_APP_ID', const [
    'FIREBASE_APP_ID_MACOS',
    'FIREBASE_IOS_APP_ID',
    'FIREBASE_APP_ID_IOS',
  ], 'YOUR_APP_ID');

  /// Windows (Flutter desktop) app id from Firebase — often a second "Web" app in the console.
  /// Falls back to [webAppId] if unset (may be wrong for your project; set explicitly).
  static String get windowsAppId {
    final v = _envFirst('FIREBASE_WINDOWS_APP_ID', const [
      'FIREBASE_APP_ID_WINDOWS',
    ], '');
    if (v.isNotEmpty) return v;
    return webAppId;
  }

  static String get messagingSenderId =>
      _envFirst('FIREBASE_MESSAGING_SENDER_ID', const [], 'YOUR_SENDER_ID');
  static String get projectId =>
      _envFirst('FIREBASE_PROJECT_ID', const [], 'YOUR_PROJECT_ID');
  static String get storageBucket =>
      _envFirst('FIREBASE_STORAGE_BUCKET', const [], 'YOUR_STORAGE_BUCKET');
  static String get iosBundleId =>
      _envFirst('FIREBASE_IOS_BUNDLE_ID', const [], 'com.example.app');

  // Google OAuth
  static String get googleClientId => _envFirst('GOOGLE_CLIENT_ID', const [
    'GOOGLE_WEB_CLIENT_ID',
  ], 'YOUR_CLIENT_ID');

  /// reCAPTCHA v3 site key for Firebase App Check on web (Firebase Console → App Check).
  static String get firebaseAppCheckRecaptchaSiteKey => _envFirst(
    'FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY',
    const [],
    'YOUR_RECAPTCHA_SITE_KEY',
  );

  static bool _toBool(String raw, {required bool fallback}) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return fallback;
    if (v == '1' || v == 'true' || v == 'yes' || v == 'on') return true;
    if (v == '0' || v == 'false' || v == 'no' || v == 'off') return false;
    return fallback;
  }

  static int _toInt(String raw, {required int fallback}) {
    final v = int.tryParse(raw.trim());
    return v ?? fallback;
  }

  static const String _defineUseLocalEmulators = String.fromEnvironment(
    'USE_LOCAL_EMULATORS',
    defaultValue: '',
  );
  static const String _defineEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );
  static const String _defineAuthEmulatorPort = String.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: '',
  );
  static const String _defineFirestoreEmulatorPort = String.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: '',
  );
  static const String _defineFunctionsEmulatorPort = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_PORT',
    defaultValue: '',
  );
  static const String _defineStorageEmulatorPort = String.fromEnvironment(
    'FIREBASE_STORAGE_EMULATOR_PORT',
    defaultValue: '',
  );

  /// Dual-environment switch.
  ///
  /// Priority: --dart-define USE_LOCAL_EMULATORS > assets/.env USE_LOCAL_EMULATORS > false.
  static bool get useLocalEmulators => _toBool(
    _defineUseLocalEmulators.isNotEmpty
        ? _defineUseLocalEmulators
        : (dotenv.env['USE_LOCAL_EMULATORS'] ?? ''),
    fallback: false,
  );

  /// Android emulators need 10.0.2.2 to reach host machine.
  /// iOS simulators, desktop and web can use loopback.
  static String get emulatorHost {
    final override = _defineEmulatorHost.isNotEmpty
        ? _defineEmulatorHost
        : (dotenv.env['FIREBASE_EMULATOR_HOST'] ?? '').trim();
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'localhost';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return '127.0.0.1';
    }
  }

  static int get authEmulatorPort => _toInt(
    _defineAuthEmulatorPort.isNotEmpty
        ? _defineAuthEmulatorPort
        : (dotenv.env['FIREBASE_AUTH_EMULATOR_PORT'] ?? ''),
    fallback: 9099,
  );
  static int get firestoreEmulatorPort => _toInt(
    _defineFirestoreEmulatorPort.isNotEmpty
        ? _defineFirestoreEmulatorPort
        : (dotenv.env['FIRESTORE_EMULATOR_PORT'] ?? ''),
    fallback: 8080,
  );
  static int get functionsEmulatorPort => _toInt(
    _defineFunctionsEmulatorPort.isNotEmpty
        ? _defineFunctionsEmulatorPort
        : (dotenv.env['FIREBASE_FUNCTIONS_EMULATOR_PORT'] ?? ''),
    fallback: 5001,
  );
  static int get storageEmulatorPort => _toInt(
    _defineStorageEmulatorPort.isNotEmpty
        ? _defineStorageEmulatorPort
        : (dotenv.env['FIREBASE_STORAGE_EMULATOR_PORT'] ?? ''),
    fallback: 9199,
  );

  /// True when [value] is missing or still a template placeholder from a fresh clone.
  static bool _isPlaceholder(String value) {
    if (value.isEmpty) return true;
    return value.startsWith('YOUR_');
  }

  static String _apiKeyForPlatform() {
    if (kIsWeb) return webApiKey;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidApiKey;
      case TargetPlatform.iOS:
        return iosApiKey;
      case TargetPlatform.macOS:
        return macosApiKey;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return webApiKey;
    }
  }

  /// Non-null when Firebase client config is unusable — Cloud Functions AI calls often fail with
  /// `FirebaseFunctionsException` code `internal` when app id / API key never matched the project.
  static String? firebaseEnvErrorForAiIfAny() {
    if (_isPlaceholder(projectId)) {
      return 'Firebase env: FIREBASE_PROJECT_ID is missing or still a placeholder. '
          'Ensure assets/.env loaded (see main.dart) and contains your Firebase project id.';
    }
    if (_isPlaceholder(_apiKeyForPlatform())) {
      return 'Firebase env: Firebase API key for this platform is missing or placeholder in assets/.env.';
    }

    String appIdForPlatform() {
      if (kIsWeb) return webAppId;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return androidAppId;
        case TargetPlatform.iOS:
          return iosAppId;
        case TargetPlatform.macOS:
          return macosAppId;
        case TargetPlatform.windows:
          return windowsAppId;
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return webAppId;
      }
    }

    final appId = appIdForPlatform();
    if (_isPlaceholder(appId)) {
      return 'Firebase env: app id for this platform is missing or placeholder. '
          'Check FIREBASE_*_APP_ID / FIREBASE_APP_ID_* keys in assets/.env match Config.';
    }
    return null;
  }

  /// Debug-only: logs whether env looks loaded (no secret values).
  static void debugLogAiEnvSnapshot(String label) {
    assert(() {
      final err = firebaseEnvErrorForAiIfAny();
      debugPrint(
        '[AI env $label] projectId=${projectId.isEmpty ? "(empty)" : "(set)"} '
        'apiKeyForPlatform=${_isPlaceholder(_apiKeyForPlatform()) ? "MISSING/placeholder" : "set"} '
        'androidAppId=${_isPlaceholder(androidAppId) ? "MISSING/placeholder" : "set"} '
        'configOk=${err == null}',
      );
      if (err != null) {
        debugPrint('[AI env $label] $err');
      }
      return true;
    }());
  }
}
