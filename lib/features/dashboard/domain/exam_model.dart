import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String id;
  final String subject;
  final DateTime date;
  final String description;
  final String classId;

  const Exam({
    required this.id,
    required this.subject,
    required this.date,
    this.description = '',
    required this.classId,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'date': Timestamp.fromDate(date),
      'description': description,
      'classId': classId,
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map, String id) {
    return Exam(
      id: id,
      subject: map['subject'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
      classId: map['classId'] ?? '',
    );
  }
}
