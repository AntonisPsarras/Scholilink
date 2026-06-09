import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/firebase_functions_helpers.dart';
import '../../../core/social_callables.dart';
import 'user_public_sync.dart';
import '../domain/user_model.dart';

// Abstract Interface
abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> createUserWithEmailAndPassword(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> updateUserProfile(AppUser user);
  Future<void> updatePassword(String currentPassword, String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> deleteAccount(String password);
  Future<AppUser?> getUserById(String uid);
  Future<void> blockUser(String blockedUid);
  Future<void> unblockUser(String blockedUid);
  Future<void> requestParentalConsent(String parentEmail, {String? lang});
  Future<bool> verifyParentalConsent({
    required String uid,
    required String token,
  });
  Future<void> resetParentalConsent();

  /// Returns `true` if the server marked the profile as already Pro.
  Future<bool> sendProActivationCode(String email);

  /// Returns `true` if the server resolved to Pro without redeeming (e.g. duplicate submit).
  Future<bool> verifyProActivationAndUnlock(String code);
}

// Firebase Implementation
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _googleSignInInitialized = false;

  Future<GoogleSignIn> _googleSignIn() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleSignInInitialized) {
      await signIn.initialize();
      _googleSignInInitialized = true;
    }
    return signIn;
  }

  @override
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;

    if (user != null) {
      // Create initial user document in Firestore
      final appUser = AppUser(
        uid: user.uid,
        email: email,
        schoolRole: 'student',
        currentClass: 'A-Lykeio-General', // Default class
        absences: 0,
      );
      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
      await mergeUserPublicProfile(_firestore, appUser);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    User? user;

    if (kIsWeb) {
      // Use Firebase Auth's built-in web popup for Google Sign-In
      try {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        user = userCredential.user;
      } catch (e) {
        rethrow;
      }
    } else {
      // Use google_sign_in package for native (Android/iOS/macOS).
      final googleSignIn = await _googleSignIn();
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
    }

    if (user != null) {
      // Check if user doc already exists
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // First-time Google login — create Firestore user profile
        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? '',
          schoolRole: 'student',
          currentClass: 'A-Lykeio-General',
          profilePictureUrl:
              null, // Always use null so the initial-based avatar is shown
          absences: 0,
        );
        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
        await mergeUserPublicProfile(_firestore, appUser);
      }
      // Removed the else block that updated profilePictureUrl, to ensure
      // existing users with blank photos stay blank and use the initial-based avatar.
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final signIn = await _googleSignIn();
        await signIn.signOut();
      }
    } catch (_) {
      // Google Sign-In may not be initialized, ignore
    }
    await _auth.signOut();
  }

  @override
  Future<void> updateUserProfile(AppUser user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
    await mergeUserPublicProfile(_firestore, user);
  }

  @override
  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated');
    }

    // Re-authenticate first
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // Re-authenticate
    if (user.email != null) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }

    await callDeleteOwnUserFirestoreData();
    await user.delete();
  }

  @override
  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore
          .collection(kUserPublicCollection)
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return appUserFromPublicMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> blockUser(String blockedUid) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    });
  }

  @override
  Future<void> unblockUser(String blockedUid) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    });
  }

  @override
  Future<void> requestParentalConsent(
    String parentEmail, {
    String? lang,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    await refreshAuthTokenForCallable();
    final callable =
        FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'us-central1',
        ).httpsCallable(
          'requestParentalConsent',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
    await callable.call({
      'parentEmail': parentEmail.trim(),
      if (lang != null) 'lang': lang,
    });
  }

  @override
  Future<bool> verifyParentalConsent({
    required String uid,
    required String token,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: 'us-central1',
          ).httpsCallable(
            'verifyParentalConsent',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      final result = await callable.call({'uid': uid, 'token': token});
      final data = result.data;
      if (data is Map && data['ok'] == true) return true;
      return false;
    } on FirebaseFunctionsException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> resetParentalConsent() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // Firestore rules block client writes to consent fields; use the Cloud
    // Function which runs with Admin SDK and bypasses those restrictions.
    await refreshAuthTokenForCallable();
    final callable =
        FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'us-central1',
        ).httpsCallable(
          'resetParentalConsent',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
    await callable.call();
  }

  @override
  Future<bool> sendProActivationCode(String email) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await refreshAuthTokenForCallable();
    final callable = sendProActivationCodeCallable();
    final result = await callable.call({'email': email.trim()});
    final data = result.data;
    return data is Map && data['alreadyPro'] == true;
  }

  @override
  Future<bool> verifyProActivationAndUnlock(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await refreshAuthTokenForCallable();
    final callable = verifyProActivationAndUnlockCallable();
    final result = await callable.call({'code': code.trim()});
    final data = result.data;
    return data is Map && data['alreadyPro'] == true;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final firebaseUserProvider = StreamProvider.autoDispose<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final authStateProvider = StreamProvider.autoDispose<AppUser?>((ref) {
  final firebaseUserAsync = ref.watch(firebaseUserProvider);

  // While Firebase Auth is still initializing, return a stream that never emits so
  // the provider stays in AsyncLoading — preventing a false "logged out" flash on
  // cold start before the persisted session is restored.
  if (firebaseUserAsync.isLoading) {
    return StreamController<AppUser?>(sync: true).stream;
  }

  if (firebaseUserAsync.hasError) {
    return Stream.error(
      firebaseUserAsync.error!,
      firebaseUserAsync.stackTrace!,
    );
  }

  final firebaseUser = firebaseUserAsync.value;
  if (firebaseUser == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(firebaseUser.uid)
      .snapshots()
      .map((snapshot) {
            if (snapshot.exists) {
              final appUser = AppUser.fromMap(snapshot.data()!);

              unawaited(
                mergeUserPublicProfile(FirebaseFirestore.instance, appUser),
              );

              // Lazy migration: Update older DiceBear avatar styles to a neutral non-face style when the user logs in.
              // This is safe and fires an update to Firestore, which then triggers a new stream event.
              if (appUser.profilePictureUrl != null &&
                  appUser.profilePictureUrl!.contains('dicebear.com/7.x/')) {
                final newUrl = appUser.profilePictureUrl!.replaceAll(
                  RegExp(r'/7\.x/[^/]+/'),
                  '/7.x/shapes/',
                );

                FirebaseFirestore.instance
                    .collection('users')
                    .doc(appUser.uid)
                    .update({'profilePictureUrl': newUrl});

                final migrated = appUser.copyWith(profilePictureUrl: newUrl);
                unawaited(
                  mergeUserPublicProfile(FirebaseFirestore.instance, migrated),
                );
                return migrated;
              }

              return appUser;
            }
            return AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              schoolRole: 'student',
              preferredLanguage: 'el',
              isProfileComplete: false,
              profilePictureUrl: firebaseUser.photoURL,
            );
          });
});

/// Preferred UI language from the signed-in user (`el` when unavailable).
final userLanguageProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.preferredLanguage ?? 'el';
});

/// Narrow auth-derived providers to reduce rebuild fan-out on unrelated profile updates.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider.select((async) => async.valueOrNull));
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((async) => async.valueOrNull?.uid));
});

final currentUserClassroomIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(
        authStateProvider.select((async) => async.valueOrNull?.classroomIds),
      ) ??
      const <String>[];
});

final userProvider = FutureProvider.autoDispose.family<AppUser?, String>((
  ref,
  uid,
) async {
  return ref.read(authRepositoryProvider).getUserById(uid);
});
