import 'package:cloud_firestore/cloud_firestore.dart';

class AIChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  AIChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
    };
  }

  factory AIChatSession.fromMap(Map<String, dynamic> map, String id) {
    return AIChatSession(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Νέα Συζήτηση',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (map['lastMessageAt'] as Timestamp).toDate(),
    );
  }

  AIChatSession copyWith({String? title, DateTime? lastMessageAt}) {
    return AIChatSession(
      id: id,
      userId: userId,
      title: title ?? this.title,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}

class AIChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final List<Map<String, dynamic>> attachments;

  AIChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'createdAt': Timestamp.fromDate(createdAt),
      'attachments': attachments,
    };
  }

  factory AIChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return AIChatMessage(
      id: id,
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      attachments: (map['attachments'] as List<dynamic>? ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList(),
    );
  }
}
