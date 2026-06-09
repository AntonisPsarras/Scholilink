import 'package:cloud_firestore/cloud_firestore.dart';

import 'quiz_question.dart';

class ExamQuiz {
  final String id;
  final String examReference;
  final List<String> topics;
  final QuizQuestionType questionType;
  final String difficulty;
  final List<QuizQuestion> generatedQuestions;
  final DateTime timestamp;

  const ExamQuiz({
    required this.id,
    required this.examReference,
    required this.topics,
    required this.questionType,
    required this.difficulty,
    required this.generatedQuestions,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'examReference': examReference,
      'topics': topics,
      'questionType': quizQuestionTypeToString(questionType),
      'difficulty': difficulty,
      'generatedQuestions': generatedQuestions.map((q) => q.toMap()).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ExamQuiz.fromMap(Map<String, dynamic> map, String id) {
    final rawQuestions = List<Map<String, dynamic>>.from(
      (map['generatedQuestions'] ?? const <Map<String, dynamic>>[]).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final ts = map['timestamp'];
    DateTime parsedTimestamp = DateTime.now();
    if (ts is Timestamp) {
      parsedTimestamp = ts.toDate();
    } else if (ts is DateTime) {
      parsedTimestamp = ts;
    } else if (ts is String) {
      parsedTimestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else if (ts is Map && ts['_seconds'] != null) {
      final secs = (ts['_seconds'] as num?)?.toInt() ?? 0;
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    }
    return ExamQuiz(
      id: id,
      examReference: (map['examReference'] ?? '').toString(),
      topics: List<String>.from(map['topics'] ?? const <String>[]),
      questionType: quizQuestionTypeFromString(
        (map['questionType'] ?? '').toString(),
      ),
      difficulty: (map['difficulty'] ?? '').toString(),
      generatedQuestions: rawQuestions
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
      timestamp: parsedTimestamp,
    );
  }
}
