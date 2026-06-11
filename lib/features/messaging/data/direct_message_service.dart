import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/social_callables.dart';
import '../domain/direct_chat_model.dart';
import '../../../shared/utils/profanity_filter.dart';
import 'safety_service.dart';
import '../../auth/data/auth_repository.dart';

class DirectMessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref _ref;

  DirectMessageService(this._ref);

  /// Stable doc id for a two-user chat (new chats). Legacy random ids are still resolved.
  static String directChatDocId(String user1Id, String user2Id) {
    final sorted = [user1Id, user2Id]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  /// Returns existing deterministic chat doc id for a pair, if any (does not create).
  Future<String?> findDirectChatId(String user1Id, String user2Id) async {
    final chatId = directChatDocId(user1Id, user2Id);
    final snap = await _firestore.collection('direct_chats').doc(chatId).get();
    if (!snap.exists) return null;

    final participants = List<String>.from(snap.data()?['participants'] ?? []);
    if (participants.length == 2 &&
        participants.contains(user1Id) &&
        participants.contains(user2Id)) {
      return chatId;
    }
    return null;
  }

  /// Gets or creates a direct chat between two users.
  Future<String> getOrCreateDirectChat(String user1Id, String user2Id) async {
    final existingId = await findDirectChatId(user1Id, user2Id);
    if (existingId != null) {
      return existingId;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw StateError('Not authenticated');
    }
    final otherUid = user1Id == currentUid
        ? user2Id
        : user2Id == currentUid
        ? user1Id
        : user2Id;

    // Server path: validates friendship and repairs orphan deterministic docs
    // the client cannot read under Firestore rules.
    return callDirectChatGetOrCreate(otherUid);
  }

  /// Sends a direct message in a specific chat
  Future<void> sendDirectMessage(String chatId, DirectMessage msg) async {
    if (ProfanityFilter.containsProfanity(msg.text)) {
      await _ref
          .read(safetyServiceProvider)
          .applyPenaltyForText(msg.senderId, msg.text);
      throw const FormatException('profanity_detected');
    }

    // Add exactly to subcollection
    await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .add(msg.toMap());

    // Update the parent chat document with latest message info
    // For rich messages, we might want to store something like "Photo" or "Voice Message" if text is empty
    String lastText = msg.text;
    if (lastText.isEmpty) {
      if (msg.voiceUrl != null) {
        lastText = '🎤 Voice Message';
      } else if (msg.imageUrls.isNotEmpty) {
        lastText = '📷 Photo';
      }
    }

    await _firestore.collection('direct_chats').doc(chatId).update({
      'lastMessageText': lastText,
      'lastMessageSenderId': msg.senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Unread counts are incremented server-side in notifyDirectMessage (after moderation).
  }

  /// Marks a chat as read for a specific user.
  Future<void> markAsRead(String chatId, String userId) async {
    final chatDoc = await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .get();
    if (chatDoc.exists) {
      final unreadCounts = Map<String, int>.from(
        chatDoc.data()?['unreadCounts'] ?? {},
      );
      unreadCounts[userId] = 0;

      await _firestore.collection('direct_chats').doc(chatId).update({
        'unreadCounts': unreadCounts,
      });
    }
  }

  /// Deletes a direct message (marks as deleted).
  Future<void> deleteMessage(
    String chatId,
    String messageId, {
    String deletedText = '🚫 Διαγραμμένο μήνυμα',
  }) async {
    await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isDeleted': true,
          'text': '',
          'imageUrls': [],
          'voiceUrl': null,
        });

    // Update last message preview if needed
    final latestQuery = await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (latestQuery.docs.isNotEmpty) {
      final lastDoc = latestQuery.docs.first;
      final data = lastDoc.data();
      final isDeleted = data['isDeleted'] == true;
      String lastText = data['text'] ?? '';

      if (isDeleted) {
        lastText = deletedText;
      } else if (lastText.isEmpty) {
        if (data['voiceUrl'] != null) {
          lastText = '🎤 Voice Message';
        } else if ((data['imageUrls'] as List?)?.isNotEmpty == true) {
          lastText = '📷 Photo';
        }
      }

      await _firestore.collection('direct_chats').doc(chatId).update({
        'lastMessageText': lastText,
        'updatedAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
      });
    }
  }

  /// Edits a direct message.
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    if (ProfanityFilter.containsProfanity(newText)) {
      throw const FormatException('profanity_detected');
    }

    await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});

    // Update last message preview reliably
    final latestQuery = await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (latestQuery.docs.isNotEmpty) {
      final lastDoc = latestQuery.docs.first;
      final data = lastDoc.data();
      final isDeleted = data['isDeleted'] == true;
      String lastText = data['text'] ?? '';

      if (isDeleted) {
        lastText =
            '🚫 Διαγραμμένο μήνυμα'; // Note: edit doesn't take localized text, but deleted message can't be edited anyway
      } else if (lastText.isEmpty) {
        if (data['voiceUrl'] != null) {
          lastText = '🎤 Voice Message';
        } else if ((data['imageUrls'] as List?)?.isNotEmpty == true) {
          lastText = '📷 Photo';
        }
      }

      await _firestore.collection('direct_chats').doc(chatId).update({
        'lastMessageText': lastText,
        'updatedAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
      });
    }
  }

  /// Reports a direct message
  Future<void> reportMessage({
    required String reporterId,
    required String reportedUserId,
    required String messageId,
    required String chatId,
    required String messageText,
    String? reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'messageId': messageId,
      'contextId': chatId,
      'contextType': 'direct_chat',
      'messageText': messageText,
      'reason': reason,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Watches the most recent [limit] messages for a specific direct chat.
  Stream<List<DirectMessage>> watchDirectMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => DirectMessage.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Watch a specific chat to get metadata
  Stream<DirectChat?> watchDirectChat(String chatId) {
    return _firestore.collection('direct_chats').doc(chatId).snapshots().map((
      snap,
    ) {
      if (!snap.exists) return null;
      return DirectChat.fromMap(snap.data()!, snap.id);
    });
  }

  /// Single inbox listener for all direct chats the user participates in.
  Stream<List<DirectChat>> watchDirectChatsInbox(String userId) {
    return _firestore
        .collection('direct_chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => DirectChat.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  static DirectChat? chatWithFriend(
    List<DirectChat> inbox,
    String friendUid,
  ) {
    for (final chat in inbox) {
      final participants = chat.participants;
      if (participants.length == 2 && participants.contains(friendUid)) {
        return chat;
      }
    }
    return null;
  }

  static int sumUnreadForUser(List<DirectChat> inbox, String userId) {
    var total = 0;
    for (final chat in inbox) {
      total += chat.unreadCounts[userId] ?? 0;
    }
    return total;
  }

  /// Derived from [watchDirectChatsInbox] — do not attach a second Firestore listener.
  Stream<int> watchTotalUnreadCount(String userId) {
    return watchDirectChatsInbox(userId)
        .map((inbox) => sumUnreadForUser(inbox, userId));
  }

  /// Deletes all messages in a direct chat and resets preview metadata.
  Future<void> clearConversation(String chatId) async {
    final messagesRef = _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages');
    while (true) {
      final snap = await messagesRef.limit(250).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _firestore.collection('direct_chats').doc(chatId).update({
      'lastMessageText': '',
      'lastMessageSenderId': null,
      'lastMessageTime': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': <String, int>{},
    });
  }
}

final directMessageServiceProvider = Provider<DirectMessageService>((ref) {
  return DirectMessageService(ref);
});

/// Tracks how many DM messages to load for a given chat.
/// Increment by 50 to paginate older history.
final dmMessageLimitProvider = StateProvider.autoDispose
    .family<int, String>((ref, chatId) => 50);

final directMessagesProvider = StreamProvider.autoDispose
    .family<List<DirectMessage>, String>((ref, chatId) {
      final blockedUsers = ref.watch(
        authStateProvider.select(
          (async) => async.valueOrNull?.blockedUsers ?? const <String>[],
        ),
      );
      final limit = ref.watch(dmMessageLimitProvider(chatId));
      return ref
          .watch(directMessageServiceProvider)
          .watchDirectMessages(chatId, limit: limit)
          .map((messages) {
            return messages
                .where((msg) => !blockedUsers.contains(msg.senderId))
                .toList();
          });
    });

final directChatProvider = StreamProvider.autoDispose
    .family<DirectChat?, String>((ref, chatId) {
      return ref.watch(directMessageServiceProvider).watchDirectChat(chatId);
    });

/// One cached Firestore inbox listener per user — shared by nav badge and friend tiles.
final directChatsInboxProvider = StreamProvider.autoDispose
    .family<List<DirectChat>, String>((ref, userId) {
      return ref
          .watch(directMessageServiceProvider)
          .watchDirectChatsInbox(userId);
    });

/// Lookup a friend's chat row from the shared inbox snapshot (no extra listener).
final directChatWithFriendProvider = Provider.autoDispose
    .family<DirectChat?, (String userId, String friendUid)>((ref, pair) {
      final inbox = ref.watch(directChatsInboxProvider(pair.$1));
      return inbox.maybeWhen(
        data: (chats) =>
            DirectMessageService.chatWithFriend(chats, pair.$2),
        orElse: () => null,
      );
    });

final totalUnreadCountProvider = Provider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  final inbox = ref.watch(directChatsInboxProvider(userId));
  return inbox.maybeWhen(
    data: (chats) => DirectMessageService.sumUnreadForUser(chats, userId),
    orElse: () => 0,
  );
});
