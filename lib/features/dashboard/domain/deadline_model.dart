import 'package:cloud_firestore/cloud_firestore.dart';

class Deadline {
  final String id;
  final String title;
  final String subject;
  final DateTime date;
  final String description;
  final String classId;
  final bool isPresentation;

  const Deadline({
    required this.id,
    required this.title,
    required this.subject,
    required this.date,
    this.description = '',
    required this.classId,
    this.isPresentation = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subject': subject,
      'date': Timestamp.fromDate(date),
      'description': description,
      'classId': classId,
      'isPresentation': isPresentation,
    };
  }

  factory Deadline.fromMap(Map<String, dynamic> map, String id) {
    return Deadline(
      id: id,
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
      classId: map['classId'] ?? '',
      isPresentation: map['isPresentation'] ?? false,
    );
  }
}
