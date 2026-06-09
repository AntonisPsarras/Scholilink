import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config.dart';
import 'core/firebase_app_options.dart';
import 'core/firebase_runtime.dart';
import 'theme/app_theme.dart';
import 'theme/theme_providers.dart';
import 'shared/app_locale.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/presentation/auth_wrapper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final app = await _initializeFirebaseApp();
  await configureFirebaseRuntime(app: app);
}

Future<FirebaseApp> _initializeFirebaseApp() async {
  if (kIsWeb) {
    return Firebase.initializeApp(options: firebaseOptionsForCurrentPlatform());
  }

  // Native fallback: if dotenv config is missing/placeholder, rely on
  // google-services.json / GoogleService-Info.plist so release APK/IPA still boots.
  final envError = Config.firebaseEnvErrorForAiIfAny();
  if (envError == null) {
    try {
      return await Firebase.initializeApp(
        options: firebaseOptionsForCurrentPlatform(),
      );
    } catch (_) {
      // Fall through to native default init.
    }
  }
  return Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native splash uses fullscreen; restore system bars once Flutter runs
  // (see flutter_native_splash README — iOS Info.plist UIStatusBarHidden).
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }
  final prefs = await SharedPreferences.getInstance();

  // Must complete before Firebase.initializeApp — [Config] reads dotenv for [FirebaseOptions].
  // On open-source clones, private .env may be missing, so we fall back to .env.example.
  var loadedEnv = false;
  try {
    await dotenv.load(fileName: 'assets/.env');
    loadedEnv = true;
  } catch (e, st) {
    debugPrint('Warning: assets/.env not found or failed to load: $e');
    if (kDebugMode) debugPrint('$st');
  }
  if (!loadedEnv) {
    try {
      await dotenv.load(fileName: 'assets/.env.example');
      loadedEnv = true;
    } catch (e, st) {
      debugPrint(
        'Warning: assets/.env.example not found or failed to load: $e',
      );
      if (kDebugMode) debugPrint('$st');
    }
  }
  if (kDebugMode) {
    final misconfigured = Config.firebaseEnvErrorForAiIfAny();
    if (misconfigured != null) {
      debugPrint('Warning: $misconfigured');
    } else if (loadedEnv) {
      debugPrint('Environment loaded for this platform.');
    }
  }

  // Disable runtime font fetching so the bundled package assets are always used.
  // Without this, google_fonts attempts a network download on first launch which
  // causes a flash of unstyled text and adds startup latency.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Detect device capability before any widgets are built
  PerformanceConfig.initialize();

  final app = await _initializeFirebaseApp();
  await configureFirebaseRuntime(app: app);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const StudentDashboardApp(),
    ),
  );
}

class StudentDashboardApp extends ConsumerWidget {
  const StudentDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePref = ref.watch(themePreferenceProvider);
    final appLocale = ref.watch(appLocaleProvider);
    return MaterialApp(
      title: 'ScholiLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themePref.themeMode,
      locale: appLocale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthWrapper(),
    );
  }
}
