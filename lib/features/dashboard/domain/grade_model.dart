import 'package:cloud_firestore/cloud_firestore.dart';

class GradeRecord {
  final String id;
  final String subject;
  final double grade; // 0-20
  final String term; // e.g. "1ο Τετράμηνο", "2ο Τετράμηνο", "Τελικές Εξετάσεις"
  final DateTime date;
  final String schoolYear; // e.g. "2025-2026"

  const GradeRecord({
    required this.id,
    required this.subject,
    required this.grade,
    required this.term,
    required this.date,
    required this.schoolYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'grade': grade,
      'term': term,
      'date': Timestamp.fromDate(date),
      'schoolYear': schoolYear,
    };
  }

  factory GradeRecord.fromMap(Map<String, dynamic> map, String id) {
    return GradeRecord(
      id: id,
      subject: map['subject'] ?? '',
      grade: (map['grade'] ?? 0).toDouble(),
      term: map['term'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      schoolYear: map['schoolYear'] ?? '',
    );
  }
}
