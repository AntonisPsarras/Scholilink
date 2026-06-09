import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// Firebase options derived from [Config] (assets/.env), so the app does not
/// depend on a generated [firebase_options.dart] that is often gitignored.
FirebaseOptions firebaseOptionsForCurrentPlatform() {
  if (kIsWeb) {
    return FirebaseOptions(
      apiKey: Config.webApiKey,
      appId: Config.webAppId,
      messagingSenderId: Config.messagingSenderId,
      projectId: Config.projectId,
      storageBucket: Config.storageBucket,
      authDomain: '${Config.projectId}.firebaseapp.com',
    );
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return FirebaseOptions(
        apiKey: Config.androidApiKey,
        appId: Config.androidAppId,
        messagingSenderId: Config.messagingSenderId,
        projectId: Config.projectId,
        storageBucket: Config.storageBucket,
      );
    case TargetPlatform.iOS:
      return FirebaseOptions(
        apiKey: Config.iosApiKey,
        appId: Config.iosAppId,
        messagingSenderId: Config.messagingSenderId,
        projectId: Config.projectId,
        storageBucket: Config.storageBucket,
        iosBundleId: Config.iosBundleId,
      );
    case TargetPlatform.macOS:
      return FirebaseOptions(
        apiKey: Config.macosApiKey,
        appId: Config.macosAppId,
        messagingSenderId: Config.messagingSenderId,
        projectId: Config.projectId,
        storageBucket: Config.storageBucket,
        iosBundleId: Config.iosBundleId,
      );
    case TargetPlatform.windows:
      // FlutterFire registers Windows with a separate "web" app id in the console.
      return FirebaseOptions(
        apiKey: Config.webApiKey,
        appId: Config.windowsAppId,
        messagingSenderId: Config.messagingSenderId,
        projectId: Config.projectId,
        storageBucket: Config.storageBucket,
      );
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return FirebaseOptions(
        apiKey: Config.webApiKey,
        appId: Config.webAppId,
        messagingSenderId: Config.messagingSenderId,
        projectId: Config.projectId,
        storageBucket: Config.storageBucket,
      );
  }
}
