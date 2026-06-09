import 'package:cloud_firestore/cloud_firestore.dart';

class HomeworkPost {
  final String postId;
  final String classId;
  final String subject;
  final String content; // "Algebra pg 45 ex 2"
  final String authorId;
  final int verificationCount;
  final bool isVerified;
  final int flaggedFalse;
  final DateTime timestamp;
  final List<String> verifiedBy;
  final List<String> disapprovedBy;
  final bool isOfficial;
  final String? classroomId;
  // New fields
  final String homeworkType; // 'daily', 'project', 'other'
  final DateTime? dueDate;
  final String? voiceUrl;
  final List<String> photoUrls;
  final bool isCompleted;
  final DateTime? completedAt;

  /// When [dueDate] is set, whether to schedule the night-before reminder.
  final bool reminderEnabled;

  /// Time-of-day for the reminder (date portion ignored). `null` means 20:00.
  final DateTime? reminderTime;

  const HomeworkPost({
    required this.postId,
    required this.classId,
    required this.subject,
    required this.content,
    required this.authorId,
    this.verificationCount = 0,
    this.isVerified = false,
    this.flaggedFalse = 0,
    required this.timestamp,
    this.verifiedBy = const [],
    this.disapprovedBy = const [],
    this.isOfficial = false,
    this.classroomId,
    this.homeworkType = 'daily',
    this.dueDate,
    this.voiceUrl,
    this.photoUrls = const [],
    this.isCompleted = false,
    this.completedAt,
    this.reminderEnabled = true,
    this.reminderTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'classId': classId,
      'subject': subject,
      'content': content,
      'authorId': authorId,
      'verificationCount': verificationCount,
      'isVerified': isVerified,
      'flaggedFalse': flaggedFalse,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'verifiedBy': verifiedBy,
      'disapprovedBy': disapprovedBy,
      'isOfficial': isOfficial,
      if (classroomId != null) 'classroomId': classroomId,
      'homeworkType': homeworkType,
      if (dueDate != null) 'dueDate': dueDate!.millisecondsSinceEpoch,
      if (voiceUrl != null) 'voiceUrl': voiceUrl,
      'photoUrls': photoUrls,
      'isCompleted': isCompleted,
      if (completedAt != null)
        'completedAt': completedAt!.millisecondsSinceEpoch,
      'reminderEnabled': reminderEnabled,
      // Encoded minutes: >=0 custom time; -1 = enabled, default 20:00; -2 = disabled
      'reminderMinutes': _encodeReminderMinutes(),
    };
  }

  /// Firestore-safe encoding (merge-safe overwrite of prior custom times).
  int _encodeReminderMinutes() {
    if (!reminderEnabled) return -2;
    if (reminderTime == null) return -1;
    return reminderTime!.hour * 60 + reminderTime!.minute;
  }

  factory HomeworkPost.fromMap(Map<String, dynamic> map) {
    // Handle completedAt which may be a Firestore Timestamp or int (millisecondsSinceEpoch)
    DateTime? completedAt;
    if (map['completedAt'] != null) {
      final raw = map['completedAt'];
      if (raw is int) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(raw);
      } else if (raw is DateTime) {
        completedAt = raw;
      } else {
        // Firestore Timestamp has a toDate() method
        try {
          completedAt = (raw as dynamic).toDate();
        } catch (_) {}
      }
    }

    final rawMin = map['reminderMinutes'];
    final rawEn = map['reminderEnabled'];
    final int? mInt = rawMin == null
        ? null
        : ((rawMin is int) ? rawMin : (rawMin as num).toInt());
    final bool enabled = rawEn is bool ? rawEn : (mInt != -2);
    DateTime? reminderTimeFromMap;
    if (enabled && mInt != null && mInt >= 0) {
      reminderTimeFromMap = DateTime(1970, 1, 1, mInt ~/ 60, mInt % 60);
    }

    return HomeworkPost(
      postId: map['postId'] ?? '',
      classId: map['classId'] ?? '',
      subject: map['subject'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      verificationCount: map['verificationCount']?.toInt() ?? 0,
      isVerified: map['isVerified'] ?? false,
      flaggedFalse: map['flaggedFalse']?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      verifiedBy: List<String>.from(map['verifiedBy'] ?? []),
      disapprovedBy: List<String>.from(map['disapprovedBy'] ?? []),
      isOfficial: map['isOfficial'] ?? false,
      classroomId: map['classroomId'],
      homeworkType: map['homeworkType'] ?? 'daily',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
          : null,
      voiceUrl: map['voiceUrl'],
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      isCompleted: map['isCompleted'] ?? false,
      completedAt: completedAt,
      reminderEnabled: enabled,
      reminderTime: reminderTimeFromMap,
    );
  }

  factory HomeworkPost.fromChatMessage(Map<String, dynamic> map, String docId) {
    // Handle timestamp which is a Firestore Timestamp
    final rawTimestamp = map['timestamp'];
    DateTime timestamp = DateTime.now();
    if (rawTimestamp is Timestamp) {
      timestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    }

    // Handle dueDate which is a Firestore Timestamp
    final rawDueDate = map['dueDate'];
    DateTime? dueDate;
    if (rawDueDate is Timestamp) {
      dueDate = rawDueDate.toDate();
    } else if (rawDueDate is int) {
      dueDate = DateTime.fromMillisecondsSinceEpoch(rawDueDate);
    }

    return HomeworkPost(
      postId: docId,
      classId: map['classroomId'] ?? '',
      subject: map['subject'] ?? 'General',
      content: map['text'] ?? '',
      authorId: map['authorId'] ?? '',
      timestamp: timestamp,
      dueDate: dueDate,
      isOfficial: true,
      isVerified: true,
      verifiedBy: List<String>.from(map['verifiedBy'] ?? []),
      disapprovedBy: List<String>.from(map['disapprovedBy'] ?? []),
      verificationCount: (map['verifiedBy'] as List?)?.length ?? 0,
      homeworkType: 'daily',
    );
  }

  HomeworkPost copyWith({
    String? postId,
    String? classId,
    String? subject,
    String? content,
    String? authorId,
    int? verificationCount,
    bool? isVerified,
    int? flaggedFalse,
    DateTime? timestamp,
    List<String>? verifiedBy,
    List<String>? disapprovedBy,
    bool? isOfficial,
    String? classroomId,
    String? homeworkType,
    DateTime? dueDate,
    String? voiceUrl,
    List<String>? photoUrls,
    bool? isCompleted,
    DateTime? completedAt,
    bool? reminderEnabled,
    DateTime? reminderTime,
    bool setReminderTime = false,
  }) {
    return HomeworkPost(
      postId: postId ?? this.postId,
      classId: classId ?? this.classId,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      verificationCount: verificationCount ?? this.verificationCount,
      isVerified: isVerified ?? this.isVerified,
      flaggedFalse: flaggedFalse ?? this.flaggedFalse,
      timestamp: timestamp ?? this.timestamp,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      disapprovedBy: disapprovedBy ?? this.disapprovedBy,
      isOfficial: isOfficial ?? this.isOfficial,
      classroomId: classroomId ?? this.classroomId,
      homeworkType: homeworkType ?? this.homeworkType,
      dueDate: dueDate ?? this.dueDate,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: setReminderTime ? reminderTime : this.reminderTime,
    );
  }
}
