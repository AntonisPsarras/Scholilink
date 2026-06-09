import 'package:cloud_firestore/cloud_firestore.dart';

class AIChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl; // Optional image for note scanning

  AIChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
    };
  }

  factory AIChatMessage.fromMap(Map<String, dynamic> map) {
    return AIChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
    );
  }
}

class AIChatSession {
  final String id;
  final String userId;
  final String title;
  final List<AIChatMessage> messages;
  final DateTime lastUpdated;
  final String? type; // 'general', 'notes', etc.

  AIChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.messages,
    required this.lastUpdated,
    this.type = 'general',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'type': type,
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  factory AIChatSession.fromMap(String id, Map<String, dynamic> map) {
    return AIChatSession(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'New Chat',
      type: map['type'] ?? 'general',
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      messages: (map['messages'] as List? ?? [])
          .map((m) => AIChatMessage.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
