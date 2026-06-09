import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/app_locale.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/exam_quiz.dart';
import '../domain/quiz_attempt.dart';
import '../domain/quiz_question.dart';
import '../domain/readiness_score.dart';
import '../repository/exam_readiness_repository.dart';

class ExamGenerationState {
  final bool isLoading;
  final String? error;
  final ExamQuiz? generatedQuiz;

  const ExamGenerationState({
    this.isLoading = false,
    this.error,
    this.generatedQuiz,
  });

  ExamGenerationState copyWith({
    bool? isLoading,
    String? error,
    ExamQuiz? generatedQuiz,
  }) {
    return ExamGenerationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      generatedQuiz: generatedQuiz ?? this.generatedQuiz,
    );
  }
}

class ExamGenerationNotifier extends StateNotifier<ExamGenerationState> {
  ExamGenerationNotifier(this._ref) : super(const ExamGenerationState());

  final Ref _ref;

  Future<ExamQuiz?> generateQuiz({
    required String subjectName,
    required List<String> topics,
    required List<QuizQuestionType> questionTypes,
    required int count,
    required String difficulty,
    String syllabusText = '',
    List<File> scannedImages = const <File>[],
    String language = 'el',
  }) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      final isGreek = _ref.read(appLocaleProvider).languageCode == 'el';
      state = state.copyWith(
        error: isGreek
            ? 'Πρέπει να συνδεθείς πρώτα.'
            : 'You need to sign in first.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final quiz = await _ref
          .read(examReadinessRepositoryProvider)
          .generateExamQuiz(
            userId: user.uid,
            subjectName: subjectName,
            topics: topics,
            questionTypes: questionTypes,
            count: count,
            difficulty: difficulty,
            syllabusText: syllabusText,
            scannedImages: scannedImages,
            language: language,
          );
      state = state.copyWith(isLoading: false, generatedQuiz: quiz);
      return quiz;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<QuizAttempt?> submitAttempt({
    required ExamQuiz quiz,
    required String subjectId,
    required String subjectName,
    required Map<int, String> answersByIndex,
    String language = 'el',
  }) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      final isGreek = _ref.read(appLocaleProvider).languageCode == 'el';
      state = state.copyWith(
        error: isGreek
            ? 'Πρέπει να συνδεθείς πρώτα.'
            : 'You need to sign in first.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final openQuestions = <Map<String, dynamic>>[];
      var objectiveCorrect = 0;
      final topicTotal = <String, int>{};
      final topicCorrect = <String, int>{};

      for (var i = 0; i < quiz.generatedQuestions.length; i++) {
        final q = quiz.generatedQuestions[i];
        final userAnswer = answersByIndex[i]?.trim() ?? '';
        topicTotal[q.topicTag] = (topicTotal[q.topicTag] ?? 0) + 1;
        if (q.type == QuizQuestionType.multipleChoice ||
            q.type == QuizQuestionType.trueFalse) {
          if (_answersEquivalent(userAnswer, q.correctAnswer)) {
            objectiveCorrect++;
            topicCorrect[q.topicTag] = (topicCorrect[q.topicTag] ?? 0) + 1;
          }
        } else {
          openQuestions.add({
            'index': i,
            'questionText': q.questionText,
            'topicTag': q.topicTag,
            'expected': q.correctAnswer,
            'studentAnswer': userAnswer,
          });
        }
      }

      var openPoints = 0.0;
      final attemptId = const Uuid().v4();
      if (openQuestions.isNotEmpty) {
        final openResult = await _ref
            .read(examReadinessRepositoryProvider)
            .scoreOpenQuizAttempt(
              quizId: quiz.id,
              attemptId: attemptId,
              openQuestions: openQuestions,
              answers: {
                for (final q in openQuestions)
                  (q['index'] as int).toString(): (q['studentAnswer'] ?? '')
                      .toString(),
              },
              language: language,
            );
        final scored = List<Map<String, dynamic>>.from(
          openResult['questionScores'] ?? const <Map<String, dynamic>>[],
        );
        for (final row in scored) {
          final idx = (row['index'] as num?)?.toInt();
          final perQ = (row['score'] as num?)?.toDouble() ?? 0;
          openPoints += perQ;
          if (idx != null && idx >= 0 && idx < quiz.generatedQuestions.length) {
            final topic = quiz.generatedQuestions[idx].topicTag;
            topicCorrect[topic] =
                (topicCorrect[topic] ?? 0) + (perQ >= 0.5 ? 1 : 0);
          }
        }
      }

      final totalQuestions = quiz.generatedQuestions.length;
      final totalEarned = objectiveCorrect + openPoints;
      final score = totalQuestions == 0
          ? 0
          : (totalEarned / totalQuestions) * 100;

      final topicBreakdown = <String, double>{};
      for (final entry in topicTotal.entries) {
        final correct = topicCorrect[entry.key] ?? 0;
        topicBreakdown[entry.key] = entry.value == 0
            ? 0
            : (correct / entry.value) * 100;
      }

      final attempt = QuizAttempt(
        attemptId: attemptId,
        quizId: quiz.id,
        answers: {
          for (final a in answersByIndex.entries) a.key.toString(): a.value,
        },
        score: score.clamp(0, 100).toDouble(),
        topicBreakdown: topicBreakdown,
        timestamp: DateTime.now(),
      );

      await _ref
          .read(examReadinessRepositoryProvider)
          .saveQuizAttempt(user.uid, attempt);
      try {
        await _ref
            .read(examReadinessRepositoryProvider)
            .scoreQuizAttempt(
              userId: user.uid,
              subjectId: subjectId,
              subjectName: subjectName,
              attempt: attempt,
            );
      } catch (_) {
        // Do not block test completion if readiness recomputation fails.
      }

      state = state.copyWith(isLoading: false);
      return attempt;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  bool _answersEquivalent(String a, String b) {
    String norm(String value) => value.trim().toLowerCase();
    final na = norm(a);
    final nb = norm(b);
    if (na == nb) return true;
    const trueSynonyms = <String>{'true', 'σωστό'};
    const falseSynonyms = <String>{'false', 'λάθος'};
    if (trueSynonyms.contains(na) && trueSynonyms.contains(nb)) return true;
    if (falseSynonyms.contains(na) && falseSynonyms.contains(nb)) return true;
    return false;
  }
}

final examGenerationProvider =
    StateNotifierProvider<ExamGenerationNotifier, ExamGenerationState>(
      (ref) => ExamGenerationNotifier(ref),
    );

final readinessScoresProvider =
    StreamProvider.autoDispose<List<ReadinessScore>>((ref) {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) return Stream.value(const <ReadinessScore>[]);
      return ref
          .read(examReadinessRepositoryProvider)
          .watchReadinessScores(user.uid);
    });

final quizAttemptsBySubjectProvider = StreamProvider.autoDispose
    .family<List<QuizAttempt>, String>((ref, subjectId) {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) return Stream.value(const <QuizAttempt>[]);
      return ref
          .read(examReadinessRepositoryProvider)
          .watchAttemptsBySubject(userId: user.uid, subjectId: subjectId);
    });
