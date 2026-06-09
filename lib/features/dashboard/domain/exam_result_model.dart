import 'package:cloud_firestore/cloud_firestore.dart';

class ExamResult {
  final String id;
  final String subject;
  final String examName; // e.g. "Midterm", "Quiz 1"
  final double score; // 0-20
  final DateTime date;
  final String? schoolYear; // e.g. "2024-2025" — null for legacy records

  const ExamResult({
    required this.id,
    required this.subject,
    required this.examName,
    required this.score,
    required this.date,
    this.schoolYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'examName': examName,
      'score': score,
      'date': Timestamp.fromDate(date),
      if (schoolYear != null) 'schoolYear': schoolYear,
    };
  }

  factory ExamResult.fromMap(Map<String, dynamic> map, String id) {
    return ExamResult(
      id: id,
      subject: map['subject'] ?? '',
      examName: map['examName'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      schoolYear: map['schoolYear'] as String?,
    );
  }

  ExamResult copyWith({
    String? id,
    String? subject,
    String? examName,
    double? score,
    DateTime? date,
    String? schoolYear,
  }) {
    return ExamResult(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      examName: examName ?? this.examName,
      score: score ?? this.score,
      date: date ?? this.date,
      schoolYear: schoolYear ?? this.schoolYear,
    );
  }
}
