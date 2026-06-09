import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

bool _emulatorsConfigured = false;

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
