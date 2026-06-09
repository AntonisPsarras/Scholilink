import 'package:cloud_firestore/cloud_firestore.dart';

class QuizAttempt {
  final String attemptId;
  final String quizId;
  final Map<String, String> answers;
  final double score;
  final Map<String, double> topicBreakdown;
  final DateTime timestamp;

  const QuizAttempt({
    required this.attemptId,
    required this.quizId,
    required this.answers,
    required this.score,
    required this.topicBreakdown,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'answers': answers,
      'score': score,
      'topicBreakdown': topicBreakdown,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory QuizAttempt.fromMap(Map<String, dynamic> map, String id) {
    final rawTopic = Map<String, dynamic>.from(
      map['topicBreakdown'] ?? const <String, dynamic>{},
    );
    return QuizAttempt(
      attemptId: id,
      quizId: (map['quizId'] ?? '').toString(),
      answers: Map<String, String>.from(
        map['answers'] ?? const <String, String>{},
      ),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      topicBreakdown: rawTopic.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0),
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
