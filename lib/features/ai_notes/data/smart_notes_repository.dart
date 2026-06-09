import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/smart_notes_models.dart';

final smartNotesRepositoryProvider = Provider<SmartNotesRepository>((ref) {
  return SmartNotesRepository(FirebaseFirestore.instance);
});

class SmartNotesRepository {
  final FirebaseFirestore _firestore;

  SmartNotesRepository(this._firestore);

  CollectionReference _sessionsRef(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('smart_notes_sessions');

  CollectionReference _interactionsRef(String userId, String sessionId) =>
      _sessionsRef(userId).doc(sessionId).collection('interactions');

  Stream<List<SmartNoteSession>> watchSessions(String userId) {
    return _sessionsRef(userId)
        .orderBy('lastInteractionAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SmartNoteSession.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<SmartNoteSession> createSession(String userId, String title) async {
    final docRef = _sessionsRef(userId).doc();
    final session = SmartNoteSession(
      id: docRef.id,
      userId: userId,
      title: title,
      createdAt: DateTime.now(),
      lastInteractionAt: DateTime.now(),
    );
    await docRef.set(session.toMap());
    return session;
  }

  Future<void> addInteraction(
    String userId,
    String sessionId,
    String prompt,
    List<SmartNoteCard> cards, {
    List<Map<String, dynamic>> attachments = const [],
    String lengthOption = 'short',
    String depthOption = 'basic',
    int sparkCostUsed = 1,
  }) async {
    final docRef = _interactionsRef(userId, sessionId).doc();
    final interaction = SmartNoteInteraction(
      id: docRef.id,
      prompt: prompt,
      cards: cards,
      createdAt: DateTime.now(),
      attachments: attachments,
      lengthOption: lengthOption,
      depthOption: depthOption,
      sparkCostUsed: sparkCostUsed,
    );

    await Future.wait([
      docRef.set(interaction.toMap()),
      _sessionsRef(userId).doc(sessionId).update({
        'lastInteractionAt': Timestamp.now(),
        // Update title if it's the first interaction and title is generic
        if (prompt.length < 50) 'title': prompt,
      }),
    ]);
  }

  Future<List<SmartNoteInteraction>> getInteractions(
    String userId,
    String sessionId,
  ) async {
    final snapshot = await _interactionsRef(
      userId,
      sessionId,
    ).orderBy('createdAt', descending: false).get();
    return snapshot.docs
        .map(
          (doc) => SmartNoteInteraction.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<void> deleteSession(String userId, String sessionId) async {
    await _sessionsRef(userId).doc(sessionId).delete();
  }
}
