import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ai_chat_models.dart';

final aiChatRepositoryProvider = Provider<AIChatRepository>((ref) {
  return AIChatRepository(FirebaseFirestore.instance);
});

class AIChatRepository {
  final FirebaseFirestore _firestore;

  AIChatRepository(this._firestore);

  CollectionReference _sessionsRef(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('ai_tutor_sessions');

  CollectionReference _messagesRef(String userId, String sessionId) =>
      _sessionsRef(userId).doc(sessionId).collection('messages');

  Stream<List<AIChatSession>> watchSessions(String userId) {
    return _sessionsRef(userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AIChatSession.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<AIChatSession> createSession(String userId, String title) async {
    final docRef = _sessionsRef(userId).doc();
    final session = AIChatSession(
      id: docRef.id,
      userId: userId,
      title: title,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
    );
    await docRef.set(session.toMap());
    return session;
  }

  Future<void> addMessage(
    String userId,
    String sessionId,
    String text,
    bool isUser, {
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final docRef = _messagesRef(userId, sessionId).doc();
    final message = AIChatMessage(
      id: docRef.id,
      text: text,
      isUser: isUser,
      createdAt: DateTime.now(),
      attachments: attachments,
    );

    await Future.wait([
      docRef.set(message.toMap()),
      _sessionsRef(userId).doc(sessionId).update({
        'lastMessageAt': Timestamp.now(),
        if (isUser && text.length < 30)
          'title': text, // Simple auto-title update for small first messages
      }),
    ]);
  }

  Future<List<AIChatMessage>> getMessages(
    String userId,
    String sessionId,
  ) async {
    final snapshot = await _messagesRef(
      userId,
      sessionId,
    ).orderBy('createdAt', descending: false).get();
    return snapshot.docs
        .map(
          (doc) =>
              AIChatMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<void> deleteSession(String userId, String sessionId) async {
    // Note: In production, we'd also delete sub-collection messages
    // but Firestore doesn't do cascading deletes automatically via SDK.
    // For MVP, we just delete the session doc.
    await _sessionsRef(userId).doc(sessionId).delete();
  }
}
