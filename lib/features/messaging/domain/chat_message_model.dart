import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { academic, social, voiceMessage, poll }

class ChatMessage {
  final String id;
  final String classroomId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final MessageType type;
  final String text;
  final String? subject; // Only for academic type
  final DateTime? dueDate; // Only for academic type
  final List<String> imageUrls;
  final String? voiceUrl;
  final int? voiceDurationMs;
  final List<double>? voiceAmplitudes;
  final String? pollId;
  final DateTime timestamp;
  final bool isDeleted;
  final bool isEdited;
  final List<String> verifiedBy;
  final List<String> disapprovedBy;
  final bool isBroadcasted;

  const ChatMessage({
    required this.id,
    required this.classroomId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.type,
    this.text = '',
    this.subject,
    this.dueDate,
    this.imageUrls = const [],
    this.voiceUrl,
    this.voiceDurationMs,
    this.voiceAmplitudes,
    this.pollId,
    required this.timestamp,
    this.isDeleted = false,
    this.isEdited = false,
    this.verifiedBy = const [],
    this.disapprovedBy = const [],
    this.isBroadcasted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'classroomId': classroomId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'type': type.name,
      'text': text,
      'subject': subject,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'imageUrls': imageUrls,
      'voiceUrl': voiceUrl,
      'voiceDurationMs': voiceDurationMs,
      'voiceAmplitudes': voiceAmplitudes,
      'pollId': pollId,
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'verifiedBy': verifiedBy,
      'disapprovedBy': disapprovedBy,
      'isBroadcasted': isBroadcasted,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessage(
      id: docId,
      classroomId: map['classroomId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorAvatarUrl: map['authorAvatarUrl'],
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.social,
      ),
      text: map['text'] ?? '',
      subject: map['subject'],
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      voiceUrl: map['voiceUrl'],
      voiceDurationMs: map['voiceDurationMs']?.toInt(),
      voiceAmplitudes: (map['voiceAmplitudes'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      pollId: map['pollId'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
      verifiedBy: List<String>.from(map['verifiedBy'] ?? []),
      disapprovedBy: List<String>.from(map['disapprovedBy'] ?? []),
      isBroadcasted: map['isBroadcasted'] ?? false,
    );
  }

  ChatMessage copyWith({
    String? text,
    bool? isDeleted,
    bool? isEdited,
    List<String>? verifiedBy,
    List<String>? disapprovedBy,
    bool? isBroadcasted,
  }) {
    return ChatMessage(
      id: id,
      classroomId: classroomId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      type: type,
      text: text ?? this.text,
      subject: subject,
      dueDate: dueDate,
      imageUrls: imageUrls,
      voiceUrl: voiceUrl,
      voiceDurationMs: voiceDurationMs,
      voiceAmplitudes: voiceAmplitudes,
      pollId: pollId,
      timestamp: timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      disapprovedBy: disapprovedBy ?? this.disapprovedBy,
      isBroadcasted: isBroadcasted ?? this.isBroadcasted,
    );
  }
}
