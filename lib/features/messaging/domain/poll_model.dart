import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String text;
  final List<String> voterIds;

  const PollOption({required this.text, this.voterIds = const []});

  Map<String, dynamic> toMap() {
    return {'text': text, 'voterIds': voterIds};
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      text: map['text'] ?? '',
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }
}

class Poll {
  final String id;
  final String classroomId;
  final String creatorId;
  final String creatorName;
  final String question;
  final List<PollOption> options;
  final bool isAnonymous;
  final bool allowMultiple;
  final DateTime createdAt;

  const Poll({
    required this.id,
    required this.classroomId,
    required this.creatorId,
    required this.creatorName,
    required this.question,
    required this.options,
    this.isAnonymous = false,
    this.allowMultiple = false,
    required this.createdAt,
  });

  int get totalVotes {
    final allVoters = <String>{};
    for (final opt in options) {
      allVoters.addAll(opt.voterIds);
    }
    return allVoters.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'question': question,
      'options': options.map((o) => o.toMap()).toList(),
      'isAnonymous': isAnonymous,
      'allowMultiple': allowMultiple,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map, String docId) {
    return Poll(
      id: docId,
      classroomId: map['classroomId'] ?? '',
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      question: map['question'] ?? '',
      options:
          (map['options'] as List<dynamic>?)
              ?.map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
              .toList() ??
          [],
      isAnonymous: map['isAnonymous'] ?? false,
      allowMultiple: map['allowMultiple'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
