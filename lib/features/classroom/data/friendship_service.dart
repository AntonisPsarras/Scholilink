import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import 'package:flutter/foundation.dart';
import '../../../core/social_callables.dart';
import '../../auth/data/user_public_sync.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Searches `user_public` by full name prefix (no email — not exposed publicly).
  Future<List<AppUser>> searchUsers(String query, String currentUid) async {
    if (query.trim().length < 2) return [];

    final queryTrim = query.trim();
    final results = <AppUser>[];
    final seenUids = <String>{};

    try {
      final nameSnap = await _firestore
          .collection(kUserPublicCollection)
          .orderBy('fullName')
          .startAt([queryTrim])
          .endAt(['$queryTrim\uf8ff'])
          .limit(15)
          .get();

      for (final doc in nameSnap.docs) {
        final user = appUserFromPublicMap(doc.data(), doc.id);
        if (user.uid != currentUid && !seenUids.contains(user.uid)) {
          results.add(user);
          seenUids.add(user.uid);
        }
      }
    } catch (_) {}

    return results;
  }

  /// Sends a friend request from one user to another (Cloud Function updates both user docs).
  Future<bool> sendFriendRequest(String fromUid, String toUid) async {
    if (fromUid == toUid) return false;

    try {
      final targetDoc = await _firestore
          .collection(kUserPublicCollection)
          .doc(toUid)
          .get();
      if (!targetDoc.exists) return false;

      await callFriendSendRequest(toUid);
      return true;
    } catch (e) {
      debugPrint('sendFriendRequest: $e');
      return false;
    }
  }

  /// Accepts a friend request.
  Future<void> acceptFriendRequest(String currentUid, String fromUid) async {
    await callFriendAcceptRequest(fromUid);
  }

  /// Declines a friend request received from [fromUid].
  Future<void> declineFriendRequest(String currentUid, String fromUid) async {
    await callFriendDeclineRequest(fromUid);
  }

  /// Withdraws a friend request the current user sent to [toUid].
  Future<void> cancelFriendRequest(String senderUid, String toUid) async {
    await callFriendCancelRequest(toUid);
  }

  /// Removes a friend.
  Future<void> removeFriend(String currentUid, String friendUid) async {
    await callFriendRemove(friendUid);
  }

  /// Toggles grade sharing for the current user.
  Future<void> toggleGradeSharing(String uid, bool enabled) async {
    await _firestore.collection('users').doc(uid).update({
      'shareGrades': enabled,
    });
    await _firestore.collection(kUserPublicCollection).doc(uid).set({
      'shareGrades': enabled,
    }, SetOptions(merge: true));
  }

  /// Gets friend profiles from `user_public`.
  Future<List<AppUser>> getFriends(List<String> friendUids) async {
    if (friendUids.isEmpty) return [];

    final results = <AppUser>[];
    final foundUids = <String>{};
    try {
      for (int i = 0; i < friendUids.length; i += 30) {
        final batch = friendUids.sublist(
          i,
          i + 30 > friendUids.length ? friendUids.length : i + 30,
        );
        final snap = await _firestore
            .collection(kUserPublicCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          results.add(appUserFromPublicMap(doc.data(), doc.id));
          foundUids.add(doc.id);
        }
      }

      final missing = friendUids
          .where((uid) => !foundUids.contains(uid))
          .toList();
      if (missing.isNotEmpty) {
        try {
          final backfilled = await callResolveFriendProfiles(missing);
          for (final row in backfilled) {
            final uid = row['uid'] as String? ?? '';
            if (uid.isEmpty || foundUids.contains(uid)) continue;
            results.add(appUserFromPublicMap(row, uid));
            foundUids.add(uid);
          }
        } catch (e) {
          debugPrint('resolveFriendProfiles skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting friends: $e');
      rethrow;
    }
    return results;
  }

  /// Gets a single user by UID from `user_public` (for resolving pending request names).
  Future<AppUser?> getUserByUid(String uid) async {
    final doc = await _firestore
        .collection(kUserPublicCollection)
        .doc(uid)
        .get();
    if (doc.exists && doc.data() != null) {
      return appUserFromPublicMap(doc.data()!, doc.id);
    }
    return null;
  }
}

final friendshipServiceProvider = Provider<FriendshipService>((ref) {
  return FriendshipService();
});
