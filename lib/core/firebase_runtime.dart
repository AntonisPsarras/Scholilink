import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

bool _emulatorsConfigured = false;
bool _appCheckActivated = false;

/// Activates App Check immediately after [Firebase.initializeApp].
///
/// Debug builds use debug providers; release uses Play Integrity (Android),
/// App Attest with DeviceCheck fallback (Apple), and reCAPTCHA v3 (web).
Future<void> activateFirebaseAppCheck() async {
  if (_appCheckActivated) return;

  try {
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
        providerWeb: WebDebugProvider(),
      );
      debugPrint(
        'Firebase App Check: debug providers active. Register the debug token '
        'from device logs in Firebase Console → App Check → Manage debug tokens.',
      );
    } else if (kIsWeb) {
      final siteKey = Config.firebaseAppCheckRecaptchaSiteKey;
      if (siteKey.isEmpty || siteKey.startsWith('YOUR_')) {
        debugPrint(
          'Warning: FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY is not configured; '
          'App Check web provider was not activated.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(siteKey),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    _appCheckActivated = true;
  } catch (e, st) {
    debugPrint('Firebase App Check activation failed: $e');
    if (kDebugMode) debugPrint('$st');
  }
}

Future<void> configureFirebaseRuntime({required FirebaseApp app}) async {
  if (!Config.useLocalEmulators) return;
  if (_emulatorsConfigured) return;

  final host = Config.emulatorHost;
  final authPort = Config.authEmulatorPort;
  final firestorePort = Config.firestoreEmulatorPort;
  final functionsPort = Config.functionsEmulatorPort;
  final storagePort = Config.storageEmulatorPort;

  await FirebaseAuth.instance.useAuthEmulator(host, authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
  FirebaseFunctions.instanceFor(
    app: app,
    region: 'us-central1',
  ).useFunctionsEmulator(host, functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(host, storagePort);

  _emulatorsConfigured = true;
  if (kDebugMode) {
    debugPrint(
      'Firebase emulators enabled host=$host auth=$authPort firestore=$firestorePort functions=$functionsPort storage=$storagePort',
    );
  }
}
