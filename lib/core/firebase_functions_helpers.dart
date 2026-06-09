import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Refreshes the Firebase Auth ID token before HTTPS callable invocations.
/// Helps web and long-lived sessions where the first callable call fails with a generic `internal` error.
Future<void> refreshAuthTokenForCallable() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await user.getIdToken(true);
  } catch (e, st) {
    debugPrint('refreshAuthTokenForCallable failed: $e\n$st');
    rethrow;
  }
}

/// Same region as `functions/src/index.ts` (`setGlobalOptions({ region: 'us-central1' })`).
HttpsCallable chatWithAiCallable() {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  ).httpsCallable(
    'chatWithAi',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
  );
}

HttpsCallable getSparkStatusCallable() {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  ).httpsCallable(
    'getSparkStatus',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
  );
}

HttpsCallable sendProActivationCodeCallable() {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  ).httpsCallable(
    'sendProActivationCode',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );
}

HttpsCallable verifyProActivationAndUnlockCallable() {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  ).httpsCallable(
    'verifyProActivationAndUnlock',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
  );
}

/// User-facing hint when [FirebaseFunctionsException.code] is `internal` (often masks HTTP 403 on web).
String callableInternalErrorUserMessage() {
  if (kIsWeb) {
    return 'ScholiLink AI could not run from the browser. If Cloud logs show OPTIONS 403 on '
        'chatWithAi, open Google Cloud Console → Cloud Run → the chatWithAi service → '
        'Permissions → grant role "Cloud Run Invoker" to principal "allUsers". '
        'That only opens the HTTPS endpoint; Firebase Auth is still required inside the function.';
  }
  return 'ScholiLink AI hit a server error (internal). If this persists, check Cloud Functions '
      'logs for chatWithAi.';
}
