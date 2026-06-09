import 'package:cloud_firestore/cloud_firestore.dart';

class DirectChat {
  final String id;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessageText;
  final String lastMessageSenderId;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCounts; // userId -> count

  const DirectChat({
    required this.id,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageText = '',
    this.lastMessageSenderId = '',
    this.lastMessageTime,
    this.unreadCounts = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      if (lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
      'unreadCounts': unreadCounts,
    };
  }

  factory DirectChat.fromMap(Map<String, dynamic> map, String id) {
    return DirectChat(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageText: map['lastMessageText'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
    );
  }
}

class DirectMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'social', 'academic', 'voiceMessage'
  final String? subject;
  final List<String> imageUrls;
  final String? voiceUrl;
  final int? voiceDurationMs;
  final List<double>? voiceAmplitudes;
  final bool isDeleted;
  final bool isEdited;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = 'social',
    this.subject,
    this.imageUrls = const [],
    this.voiceUrl,
    this.voiceDurationMs,
    this.voiceAmplitudes,
    this.isDeleted = false,
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      if (subject != null) 'subject': subject,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (voiceUrl != null) 'voiceUrl': voiceUrl,
      if (voiceDurationMs != null) 'voiceDurationMs': voiceDurationMs,
      if (voiceAmplitudes != null && voiceAmplitudes!.isNotEmpty)
        'voiceAmplitudes': voiceAmplitudes,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
    };
  }

  factory DirectMessage.fromMap(Map<String, dynamic> map, String id) {
    return DirectMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'social',
      subject: map['subject'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      voiceUrl: map['voiceUrl'],
      voiceDurationMs: map['voiceDurationMs'],
      voiceAmplitudes: map['voiceAmplitudes'] != null
          ? List<double>.from(
              map['voiceAmplitudes'].map((e) => (e as num).toDouble()),
            )
          : null,
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
    );
  }
}
