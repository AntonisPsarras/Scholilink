import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/ai_key_store.dart';
import '../../../core/firebase_functions_helpers.dart';
import '../domain/exam_quiz.dart';
import '../domain/quiz_attempt.dart';
import '../domain/quiz_question.dart';
import '../domain/readiness_score.dart';

abstract class ExamReadinessRepository {
  Future<ExamQuiz> generateExamQuiz({
    required String userId,
    required String subjectName,
    required List<String> topics,
    required List<QuizQuestionType> questionTypes,
    required int count,
    required String difficulty,
    String syllabusText = '',
    List<File> scannedImages = const <File>[],
    String language = 'el',
    String? subscriptionType,
  });

  Future<Map<String, dynamic>> scoreOpenQuizAttempt({
    required String quizId,
    required String attemptId,
    required List<Map<String, dynamic>> openQuestions,
    required Map<String, String> answers,
    String language = 'el',
    String? subscriptionType,
  });

  Future<void> saveQuizAttempt(String userId, QuizAttempt attempt);
  Future<void> scoreQuizAttempt({
    required String userId,
    required String subjectId,
    required String subjectName,
    required QuizAttempt attempt,
  });

  Stream<List<ReadinessScore>> watchReadinessScores(String userId);
  Stream<List<QuizAttempt>> watchAttemptsBySubject({
    required String userId,
    required String subjectId,
  });
}

class FirestoreExamReadinessRepository implements ExamReadinessRepository {
  FirestoreExamReadinessRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AiKeyStore? aiKeyStore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             app: Firebase.app(),
             region: 'us-central1',
           ),
       _aiKeyStore = aiKeyStore ?? const AiKeyStore(FlutterSecureStorage());

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final AiKeyStore _aiKeyStore;

  @override
  Future<ExamQuiz> generateExamQuiz({
    required String userId,
    required String subjectName,
    required List<String> topics,
    required List<QuizQuestionType> questionTypes,
    required int count,
    required String difficulty,
    String syllabusText = '',
    List<File> scannedImages = const <File>[],
    String language = 'el',
    String? subscriptionType,
  }) async {
    await refreshAuthTokenForCallable();
    final callable = _functions.httpsCallable(
      'generateExamQuiz',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    try {
      final base64Images = <String>[];
      for (final file in scannedImages) {
        final bytes = await file.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }
      final userApiKey = await _aiKeyStore.readGeminiApiKeyIfEligible(
        subscriptionType,
      );
      final res = await callable.call({
        'topics': topics,
        'questionType': questionTypes.map(quizQuestionTypeToString).toList(),
        'count': count,
        'difficulty': difficulty,
        'subjectName': subjectName,
        'syllabusText': syllabusText,
        'base64Images': base64Images,
        'language': language,
        if (userApiKey != null) 'userApiKey': userApiKey,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final quizId = (data['quizId'] ?? '').toString();
      final quizMapRaw = data['quiz'];
      if (quizId.isEmpty || quizMapRaw is! Map) {
        throw StateError(
          language == 'el'
              ? 'Το τεστ δεν επιστράφηκε σωστά από τον server.'
              : 'The test was not returned correctly by the server.',
        );
      }
      final quizMap = Map<String, dynamic>.from(quizMapRaw);
      return ExamQuiz.fromMap(quizMap, quizId);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception(
          language == 'el'
              ? 'Έφτασες το ημερήσιο όριο Sparks για δημιουργία τεστ.'
              : 'You reached your daily Spark limit for test generation.',
        );
      }
      final msg = (e.message ?? '').trim();
      if (msg.isNotEmpty) {
        throw Exception(msg);
      }
      throw Exception(
        language == 'el'
            ? 'Αποτυχία δημιουργίας τεστ (${e.code}).'
            : 'Failed to generate test (${e.code}).',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> scoreOpenQuizAttempt({
    required String quizId,
    required String attemptId,
    required List<Map<String, dynamic>> openQuestions,
    required     Map<String, String> answers,
    String language = 'el',
    String? subscriptionType,
  }) async {
    await refreshAuthTokenForCallable();
    final callable = _functions.httpsCallable(
      'scoreOpenQuizAttempt',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    try {
      final userApiKey = await _aiKeyStore.readGeminiApiKeyIfEligible(
        subscriptionType,
      );
      final res = await callable.call({
        'quizId': quizId,
        'attemptId': attemptId,
        'openQuestions': openQuestions,
        'answers': answers,
        'language': language,
        if (userApiKey != null) 'userApiKey': userApiKey,
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception(
          language == 'el'
              ? 'Έφτασες το ημερήσιο όριο Sparks για AI διόρθωση.'
              : 'You reached your daily Spark limit for AI grading.',
        );
      }
      final msg = (e.message ?? '').trim();
      if (msg.isNotEmpty) {
        throw Exception(msg);
      }
      throw Exception('Open-answer scoring failed (${e.code}).');
    }
  }

  @override
  Future<void> saveQuizAttempt(String userId, QuizAttempt attempt) async {
    await _firestore.collection('quiz_attempts').doc(attempt.attemptId).set({
      ...attempt.toMap(),
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> scoreQuizAttempt({
    required String userId,
    required String subjectId,
    required String subjectName,
    required QuizAttempt attempt,
  }) async {
    await _firestore.collection('quiz_attempts').doc(attempt.attemptId).set({
      ...attempt.toMap(),
      'userId': userId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Fetch only the most recent 200 attempts to avoid full-collection scans.
    // This is sufficient: we only need the last 3 scores per subject for the
    // rolling average, and 200 covers any realistic usage across all subjects.
    // A composite index (userId + createdAt) would allow server-side ordering,
    // but is avoided here to keep the index config simple for a portfolio project.
    final recentByUser = await _firestore
        .collection('quiz_attempts')
        .where('userId', isEqualTo: userId)
        .limit(200)
        .get();

    final scores = recentByUser.docs.toList()
      ..sort((a, b) {
        final aTs = (a.data()['timestamp'] as Timestamp?)?.toDate();
        final bTs = (b.data()['timestamp'] as Timestamp?)?.toDate();
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });
    final recentScores = scores
        .where((doc) => (doc.data()['subjectId'] ?? '') == subjectId)
        .take(3)
        .map((doc) => (doc.data()['score'] as num?)?.toDouble() ?? 0)
        .toList();
    final weighted = _calculateWeightedRollingAverage(recentScores);
    final docId = '${userId}_$subjectId';
    await _firestore.collection('readiness_scores').doc(docId).set({
      'userId': userId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'rollingAverage': weighted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  double _calculateWeightedRollingAverage(List<double> scores) {
    if (scores.isEmpty) return 0;
    final max = scores.length > 3 ? 3 : scores.length;
    final trimmed = scores.take(max).toList();
    if (trimmed.length == 1) return trimmed.first;
    if (trimmed.length == 2) {
      return ((trimmed[0] * 0.6) + (trimmed[1] * 0.4)).clamp(0, 100);
    }
    return ((trimmed[0] * 0.5) + (trimmed[1] * 0.3) + (trimmed[2] * 0.2)).clamp(
      0,
      100,
    );
  }

  @override
  Stream<List<ReadinessScore>> watchReadinessScores(String userId) {
    return _firestore
        .collection('readiness_scores')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ReadinessScore.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.rollingAverage.compareTo(a.rollingAverage)),
        );
  }

  @override
  Stream<List<QuizAttempt>> watchAttemptsBySubject({
    required String userId,
    required String subjectId,
  }) {
    return _firestore
        .collection('quiz_attempts')
        .where('userId', isEqualTo: userId)
        .limit(200)
        .snapshots()
        .map((snap) {
          final filtered = snap.docs
              .where((doc) => (doc.data()['subjectId'] ?? '') == subjectId)
              .map((doc) => QuizAttempt.fromMap(doc.data(), doc.id))
              .toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return filtered;
        });
  }
}

final examReadinessRepositoryProvider = Provider<ExamReadinessRepository>((
  ref,
) {
  return FirestoreExamReadinessRepository();
});
