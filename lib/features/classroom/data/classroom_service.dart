import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/social_callables.dart';
import '../../auth/data/user_public_sync.dart';
import '../../dashboard/domain/classroom_model.dart';
import '../../dashboard/domain/homework_post_model.dart';

class ClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new classroom with the creator as first admin.
  Future<Classroom> createClassroom(
    String name,
    String creatorId, {
    String description = '',
  }) async {
    final inviteCode = _generateInviteCode();

    final docRef = await _firestore.collection('classrooms').add({
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'adminIds': [creatorId],
      'members': [creatorId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await callClassroomRegisterMembership(docRef.id);

    return Classroom(
      id: docRef.id,
      name: name,
      description: description,
      inviteCode: inviteCode,
      adminIds: [creatorId],
      members: [creatorId],
      createdAt: DateTime.now(),
    );
  }

  /// Joins an existing classroom by invite code (server validates the code).
  Future<Classroom?> joinClassroom(String inviteCode, String userId) async {
    try {
      final result = await callClassroomJoinWithInviteCode(inviteCode.trim());
      if (result['ok'] != true) return null;

      return Classroom(
        id: result['classroomId'] as String? ?? '',
        name: result['name'] as String? ?? '',
        description: result['description'] as String? ?? '',
        inviteCode: result['inviteCode'] as String? ?? inviteCode,
        adminIds: List<String>.from(result['adminIds'] ?? []),
        members: List<String>.from(result['members'] ?? []),
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('joinClassroom: $e');
      return null;
    }
  }

  /// Leaves a classroom (server updates membership + Auth custom claims).
  Future<void> leaveClassroom(String classroomId, String userId) async {
    await callClassroomLeaveMember(classroomId);
  }

  /// Deletes a classroom (admin only).
  Future<void> deleteClassroom(String classroomId, String userId) async {
    final doc = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .get();
    if (!doc.exists) return;

    final classroom = Classroom.fromMap(doc.data()!, doc.id);
    if (!classroom.isAdmin(userId))
      throw Exception('Only admins can delete a classroom');

    await callClassroomDeleteWithCleanup(classroomId);
  }

  /// Updates classroom details (admin only).
  Future<void> updateClassroom(
    String classroomId,
    String userId, {
    String? name,
    String? description,
    String? profileImageUrl,
  }) async {
    final doc = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .get();
    if (!doc.exists) return;

    final classroom = Classroom.fromMap(doc.data()!, doc.id);
    if (!classroom.isAdmin(userId))
      throw Exception('Only admins can edit a classroom');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

    if (updates.isNotEmpty) {
      await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .update(updates);
    }
  }

  /// Promotes a member to admin (admin only).
  Future<void> promoteToAdmin(
    String classroomId,
    String userId,
    String targetUserId,
  ) async {
    final doc = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .get();
    if (!doc.exists) return;

    final classroom = Classroom.fromMap(doc.data()!, doc.id);
    if (!classroom.isAdmin(userId))
      throw Exception('Only admins can promote members');

    await _firestore.collection('classrooms').doc(classroomId).update({
      'adminIds': FieldValue.arrayUnion([targetUserId]),
    });
  }

  /// Demotes an admin to regular member (admin only).
  Future<void> demoteAdmin(
    String classroomId,
    String userId,
    String targetUserId,
  ) async {
    final doc = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .get();
    if (!doc.exists) return;

    final classroom = Classroom.fromMap(doc.data()!, doc.id);
    if (!classroom.isAdmin(userId)) throw Exception('Only admins can demote');
    if (classroom.adminIds.length <= 1)
      throw Exception('Cannot remove the last admin');

    await _firestore.collection('classrooms').doc(classroomId).update({
      'adminIds': FieldValue.arrayRemove([targetUserId]),
    });
  }

  /// Removes a member from the classroom (admin only).
  Future<void> removeMember(
    String classroomId,
    String userId,
    String targetUserId,
  ) async {
    final doc = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .get();
    if (!doc.exists) return;

    final classroom = Classroom.fromMap(doc.data()!, doc.id);
    if (!classroom.isAdmin(userId))
      throw Exception('Only admins can remove members');

    await callClassroomRemoveMemberAdmin(
      classroomId: classroomId,
      targetUserId: targetUserId,
    );
  }

  /// Watches a single classroom document in real time.
  Stream<Classroom?> watchClassroom(String classroomId) {
    return _firestore.collection('classrooms').doc(classroomId).snapshots().map(
      (snap) {
        if (!snap.exists) return null;
        return Classroom.fromMap(snap.data()!, snap.id);
      },
    );
  }

  /// Watches all classrooms for a user.
  /// Firestore's `whereIn` is capped at 30 items, so large lists are split into
  /// parallel chunks and merged into a single sorted stream.
  Stream<List<Classroom>> watchUserClassrooms(List<String> classroomIds) {
    if (classroomIds.isEmpty) return Stream.value([]);

    // Split into chunks of 30 (Firestore whereIn limit).
    final chunks = <List<String>>[];
    for (var i = 0; i < classroomIds.length; i += 30) {
      chunks.add(classroomIds.sublist(i, (i + 30).clamp(0, classroomIds.length)));
    }

    if (chunks.length == 1) {
      return _firestore
          .collection('classrooms')
          .where(FieldPath.documentId, whereIn: chunks.first)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((doc) => Classroom.fromMap(doc.data(), doc.id))
                .toList(),
          );
    }

    // Merge all chunk streams, re-emit whenever any chunk changes.
    final chunkStreams = chunks
        .map(
          (chunk) => _firestore
              .collection('classrooms')
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map((doc) => Classroom.fromMap(doc.data(), doc.id))
                    .toList(),
              ),
        )
        .toList();

    // Track the latest value from each chunk stream and re-emit the flat list.
    final controller = StreamController<List<Classroom>>();
    final latestValues = List<List<Classroom>>.filled(chunkStreams.length, []);
    final subscriptions = <StreamSubscription<List<Classroom>>>[];

    for (var i = 0; i < chunkStreams.length; i++) {
      final index = i;
      subscriptions.add(
        chunkStreams[index].listen(
          (classrooms) {
            latestValues[index] = classrooms;
            if (!controller.isClosed) {
              controller.add(latestValues.expand((c) => c).toList());
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          },
        ),
      );
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Watches the homework feed for a classroom (most recent 100 posts).
  Stream<List<HomeworkPost>> watchClassroomHomework(String classroomId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('homework_feed')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) =>
                    HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}),
              )
              .toList(),
        );
  }

  /// Posts homework to a classroom's feed.
  Future<void> postHomework(String classroomId, HomeworkPost post) async {
    await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('homework_feed')
        .add(post.toMap());
  }

  /// Verifies a homework post (adds user to verifiedBy, sets isOfficial at 3).
  Future<void> verifyHomework(
    String classroomId,
    String postId,
    String userId,
  ) async {
    final docRef = _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('homework_feed')
        .doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final verifiedBy = List<String>.from(data['verifiedBy'] ?? []);

      if (verifiedBy.contains(userId)) return; // Already verified

      verifiedBy.add(userId);
      final isOfficial = verifiedBy.length >= 3;

      transaction.update(docRef, {
        'verifiedBy': verifiedBy,
        'verificationCount': verifiedBy.length,
        'isVerified': isOfficial,
        'isOfficial': isOfficial,
      });
    });
  }

  /// Flags a homework post as false. If flagged, the verification count resets.
  Future<void> flagHomeworkAsFalse(String classroomId, String postId) async {
    final docRef = _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('homework_feed')
        .doc(postId);

    await docRef.update({
      'flaggedFalse': FieldValue.increment(1),
      'verifiedBy': [],
      'verificationCount': 0,
      'isVerified': false,
      'isOfficial': false,
    });
  }

  /// Gets member info for a classroom (name, email, profile picture).
  Future<List<Map<String, String>>> getMembers(List<String> memberUids) async {
    if (memberUids.isEmpty) return [];

    final results = <Map<String, String>>[];
    // Firestore 'in' queries limited to 30 items
    for (int i = 0; i < memberUids.length; i += 30) {
      final batch = memberUids.sublist(
        i,
        i + 30 > memberUids.length ? memberUids.length : i + 30,
      );
      final snap = await _firestore
          .collection(kUserPublicCollection)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        results.add({
          'uid': d['uid'] ?? doc.id,
          'fullName': d['fullName'] ?? '',
          'email': '',
          'profilePictureUrl': d['profilePictureUrl'] ?? '',
        });
      }
    }
    return results;
  }

  String _generateInviteCode() {
    // Alphanumeric, excluding visually ambiguous chars (0/O, 1/I/L).
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

final classroomServiceProvider = Provider<ClassroomService>((ref) {
  return ClassroomService();
});
