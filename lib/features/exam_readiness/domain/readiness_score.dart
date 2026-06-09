import 'package:cloud_firestore/cloud_firestore.dart';

enum ReadinessBand { weak, moderate, good, excellent }

ReadinessBand readinessBandFromScore(double score) {
  if (score < 50) return ReadinessBand.weak;
  if (score < 70) return ReadinessBand.moderate;
  if (score < 85) return ReadinessBand.good;
  return ReadinessBand.excellent;
}

class ReadinessScore {
  final String id;
  final String userId;
  final String subjectId;
  final String subjectName;
  final double rollingAverage;
  final DateTime updatedAt;

  const ReadinessScore({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.subjectName,
    required this.rollingAverage,
    required this.updatedAt,
  });

  ReadinessBand get band => readinessBandFromScore(rollingAverage);

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'rollingAverage': rollingAverage,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ReadinessScore.fromMap(Map<String, dynamic> map, String id) {
    return ReadinessScore(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      subjectId: (map['subjectId'] ?? '').toString(),
      subjectName: (map['subjectName'] ?? '').toString(),
      rollingAverage: (map['rollingAverage'] as num?)?.toDouble() ?? 0,
      // Missing server timestamp should be treated as stale (not "just now").
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
