import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase_functions_helpers.dart';
import '../../../core/social_callables.dart';

enum PenaltyType { profanity, cyberbullying, reported }

class SafetyService {
  /// Applies a penalty via Cloud Function (Firestore rules block client writes to moderation fields).
  Future<void> applyPenalty(String userId, PenaltyType type) async {
    if (userId != FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    await refreshAuthTokenForCallable();
    final callable =
        FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'us-central1',
        ).httpsCallable(
          'applySafetyPenalty',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
    await callable.call({'penaltyType': type.name});
  }

  /// Checks if a user is currently banned.
  bool isUserBanned(AppUser? user) {
    if (user == null || user.isBannedUntil == null) return false;
    return DateTime.now().isBefore(user.isBannedUntil!);
  }

  /// Gets remaining ban time in a readable string (e.g. "14:23")
  String getRemainingBanTime(AppUser user) {
    if (user.isBannedUntil == null) return '';
    final diff = user.isBannedUntil!.difference(DateTime.now());
    if (diff.isNegative) return '';

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Server-side Gemini moderation (Cloud Function applies cyberbullying penalty when needed).
  Future<void> checkBullyingAndPenalize(String userId, String text) async {
    if (text.trim().isEmpty) return;

    if (userId != FirebaseAuth.instance.currentUser?.uid) {
      return;
    }

    try {
      await callModerateStudentMessage(text);
    } catch (e) {
      debugPrint('Safety moderation callable error: $e');
    }
  }
}

final safetyServiceProvider = Provider<SafetyService>((ref) {
  return SafetyService();
});
