import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/storage_service.dart';
import '../domain/chat_message_model.dart';
import '../domain/poll_model.dart';
import '../../../shared/utils/profanity_filter.dart';
import '../../dashboard/domain/homework_post_model.dart';
import '../../dashboard/data/dashboard_repository.dart';
import 'safety_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService;
  final Ref _ref;

  ChatService(this._storageService, this._ref);

  // ─── Messages ───

  /// Sends a chat message to a classroom.
  Future<void> sendMessage(String classroomId, ChatMessage message) async {
    if (ProfanityFilter.containsProfanity(message.text)) {
      await _ref
          .read(safetyServiceProvider)
          .applyPenaltyForText(message.authorId, message.text);
      throw const FormatException('profanity_detected');
    }

    await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('messages')
        .add(message.toMap());

    // Bullying moderation runs server-side via moderateClassroomMessageOnCreate.
  }

  /// Watches messages in a classroom, ordered by timestamp.
  Stream<List<ChatMessage>> watchMessages(
    String classroomId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Deletes a message (marks as deleted).
  Future<void> deleteMessage(String classroomId, String messageId) async {
    await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isDeleted': true,
          'text': '',
          'imageUrls': [],
          'voiceUrl': null,
        });
  }

  /// Edits an existing message.
  Future<void> editMessage(
    String classroomId,
    String messageId,
    String newText,
  ) async {
    if (ProfanityFilter.containsProfanity(newText)) {
      throw const FormatException('profanity_detected');
    }

    await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});
  }

  /// Toggles verify/disapprove status for an academic message
  Future<void> toggleMessageVerification(
    String classroomId,
    String messageId,
    String userId,
    bool isVerify,
  ) async {
    final docRef = _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('messages')
        .doc(messageId);

    // Initial transaction to update the message's internal counts
    final updatedMessage = await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return null;

      final message = ChatMessage.fromMap(snap.data()!, snap.id);

      List<String> verifiedBy = List.from(message.verifiedBy);
      List<String> disapprovedBy = List.from(message.disapprovedBy);

      if (isVerify) {
        if (verifiedBy.contains(userId)) {
          verifiedBy.remove(userId);
        } else {
          verifiedBy.add(userId);
          disapprovedBy.remove(userId);
        }
      } else {
        if (disapprovedBy.contains(userId)) {
          disapprovedBy.remove(userId);
        } else {
          disapprovedBy.add(userId);
          verifiedBy.remove(userId);
        }
      }

      final updated = message.copyWith(
        verifiedBy: verifiedBy,
        disapprovedBy: disapprovedBy,
      );

      transaction.update(docRef, {
        'verifiedBy': verifiedBy,
        'disapprovedBy': disapprovedBy,
      });

      return updated;
    });

    if (updatedMessage == null) return;

    // 1. Personal Addition (Immediate for the student who clicked "Approve")
    if (isVerify &&
        updatedMessage.verifiedBy.contains(userId) &&
        updatedMessage.type == MessageType.academic) {
      final homework = HomeworkPost(
        postId: updatedMessage.id,
        classId: classroomId,
        subject: updatedMessage.subject ?? 'General',
        content: updatedMessage.text,
        dueDate:
            updatedMessage.dueDate ??
            DateTime.now().add(const Duration(days: 1)),
        isOfficial: true, // Personal choice is always "official" for them
        timestamp: updatedMessage.timestamp,
        authorId: updatedMessage.authorId,
        verificationCount: updatedMessage.verifiedBy.length,
        verifiedBy: updatedMessage.verifiedBy,
        disapprovedBy: updatedMessage.disapprovedBy,
      );

      await _ref
          .read(dashboardRepositoryProvider)
          .addPersonalHomework(userId, homework);
    }

    // 2. Consensus Logic (75% threshold)
    if (!updatedMessage.isBroadcasted &&
        updatedMessage.type == MessageType.academic) {
      final classroomSnap = await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .get();
      final members = List<String>.from(classroomSnap.data()?['members'] ?? []);

      if (members.isNotEmpty) {
        const threshold = 0.75;
        final currentRatio = updatedMessage.verifiedBy.length / members.length;

        if (currentRatio >= threshold) {
          // Mark as broadcasted to avoid multiple triggers
          await docRef.update({'isBroadcasted': true});

          // Broadcast logic: By marking as broadcasted, this homework will now
          // automatically appear in the dashboard of every classmate whose
          // dashboard is listening for broadcasted messages.
          // Note: We no longer "push" to individual collections to respect security rules.
        }
      }
    }
  }

  /// Reports a message
  Future<void> reportMessage({
    required String reporterId,
    required String reportedUserId,
    required String messageId,
    required String contextId, // classroomId or directChatId
    required String contextType, // 'classroom' or 'direct_chat'
    required String messageText,
    String? reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'messageId': messageId,
      'contextId': contextId,
      'contextType': contextType,
      'messageText': messageText,
      'reason': reason,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ─── File Uploads (Web-compatible, uses bytes) ───

  /// Uploads image bytes scoped to a classroom (Storage rules enforce membership).
  Future<String> uploadImageBytes(
    Uint8List bytes, {
    String ext = 'jpg',
    required String ownerUid,
    required String classroomId,
  }) async {
    return await _storageService.uploadImageBytes(
      bytes,
      'chat_images',
      ext: ext,
      ownerUid: ownerUid,
      scopeId: classroomId,
    );
  }

  /// Uploads voice recording bytes scoped to a classroom.
  Future<String> uploadVoiceBytes(
    Uint8List bytes, {
    String ext = 'webm',
    required String ownerUid,
    required String classroomId,
  }) async {
    return await _storageService.uploadVoiceBytes(
      bytes,
      'chat_voice',
      ext: ext,
      ownerUid: ownerUid,
      scopeId: classroomId,
    );
  }

  // ─── Polls ───

  /// Creates a poll in a classroom.
  Future<String> createPoll(String classroomId, Poll poll) async {
    final docRef = await _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('polls')
        .add(poll.toMap());
    return docRef.id;
  }

  /// Votes on a poll option. Handles single/multi select.
  Future<void> votePoll(
    String classroomId,
    String pollId,
    int optionIndex,
    String userId,
  ) async {
    final docRef = _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('polls')
        .doc(pollId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final poll = Poll.fromMap(snap.data()!, snap.id);

      // Build updated options
      final updatedOptions = <Map<String, dynamic>>[];
      for (int i = 0; i < poll.options.length; i++) {
        final opt = poll.options[i];
        List<String> voters = List.from(opt.voterIds);

        if (i == optionIndex) {
          // Toggle vote on this option
          if (voters.contains(userId)) {
            voters.remove(userId);
          } else {
            voters.add(userId);
          }
        } else if (!poll.allowMultiple) {
          // Remove vote from other options if single-select
          voters.remove(userId);
        }

        updatedOptions.add({'text': opt.text, 'voterIds': voters});
      }

      transaction.update(docRef, {'options': updatedOptions});
    });
  }

  /// Watches a specific poll in real time.
  Stream<Poll?> watchPoll(String classroomId, String pollId) {
    return _firestore
        .collection('classrooms')
        .doc(classroomId)
        .collection('polls')
        .doc(pollId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return Poll.fromMap(snap.data()!, snap.id);
        });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ChatService(storageService, ref);
});
