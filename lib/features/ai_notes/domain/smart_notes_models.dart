import 'package:cloud_firestore/cloud_firestore.dart';

class SmartNoteSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime lastInteractionAt;

  SmartNoteSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.lastInteractionAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastInteractionAt': Timestamp.fromDate(lastInteractionAt),
    };
  }

  factory SmartNoteSession.fromMap(Map<String, dynamic> map, String id) {
    return SmartNoteSession(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Νέες Σημειώσεις',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastInteractionAt: (map['lastInteractionAt'] as Timestamp).toDate(),
    );
  }

  SmartNoteSession copyWith({String? title, DateTime? lastInteractionAt}) {
    return SmartNoteSession(
      id: id,
      userId: userId,
      title: title ?? this.title,
      createdAt: createdAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }
}

class SmartNoteInteraction {
  final String id;
  final String prompt;
  final List<SmartNoteCard> cards;
  final DateTime createdAt;
  final List<Map<String, dynamic>> attachments;
  final String lengthOption;
  final String depthOption;
  final int sparkCostUsed;

  SmartNoteInteraction({
    required this.id,
    required this.prompt,
    required this.cards,
    required this.createdAt,
    this.attachments = const [],
    this.lengthOption = 'short',
    this.depthOption = 'basic',
    this.sparkCostUsed = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'cards': cards.map((c) => c.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'attachments': attachments,
      'lengthOption': lengthOption,
      'depthOption': depthOption,
      'sparkCostUsed': sparkCostUsed,
    };
  }

  factory SmartNoteInteraction.fromMap(Map<String, dynamic> map, String id) {
    return SmartNoteInteraction(
      id: id,
      prompt: map['prompt'] ?? '',
      cards: (map['cards'] as List<dynamic>? ?? [])
          .map((c) => SmartNoteCard.fromMap(c as Map<String, dynamic>))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      attachments: (map['attachments'] as List<dynamic>? ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList(),
      lengthOption: map['lengthOption'] ?? 'short',
      depthOption: map['depthOption'] ?? 'basic',
      sparkCostUsed: map['sparkCostUsed']?.toInt() ?? 1,
    );
  }
}

class SmartNoteCard {
  final String title;
  final String content;
  final List<String> bulletPoints;

  SmartNoteCard({
    required this.title,
    required this.content,
    required this.bulletPoints,
  });

  Map<String, dynamic> toMap() {
    return {'title': title, 'content': content, 'bulletPoints': bulletPoints};
  }

  factory SmartNoteCard.fromMap(Map<String, dynamic> map) {
    return SmartNoteCard(
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      bulletPoints: List<String>.from(map['bulletPoints'] ?? []),
    );
  }
}
