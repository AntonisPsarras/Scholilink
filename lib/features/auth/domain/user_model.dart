import 'package:cloud_firestore/cloud_firestore.dart';

/// Default `users/{uid}.currentClass` for new accounts — must match [FirebaseAuthRepository]
/// and Firestore rules (`userCurrentClass`) so exams, deadlines, and schedules stay consistent.
const String kAppDefaultCurrentClassId = 'A-Lykeio-General';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String schoolRole; // 'student' | 'teacher'
  final String? schoolId;
  final String? currentClass; // e.g., "B2", "A-Lykeio"
  final int absences;
  final String preferredLanguage;
  final bool isProfileComplete;
  final List<String> subjects;
  final bool hasTutoring;
  final List<String> tutoringSubjects;
  final bool hasTakenSampleTest;
  final List<String> friends;
  final List<String> friendRequestsSent;
  final List<String> friendRequestsReceived;
  final bool shareGrades;
  final bool autoAddHomework;
  final List<String> classroomIds;
  final String? profilePictureUrl;
  final int aiSparks;
  final String subscriptionType; // 'free', 'pro'
  final DateTime? lastSparksRefresh;
  final DateTime? birthDate;
  final bool hasParentalConsent;
  final String? parentEmail;
  final String? consentVerificationStatus; // 'pending', 'approved', null
  final String? consentToken;
  final List<String> blockedUsers;
  final int safetyScore;
  final int offenseCount;
  final int reportsCount;
  final DateTime? isBannedUntil;
  final String bio;
  final List<String> achievements;
  final bool showBio;
  final bool showAchievements;
  final bool syncToDeviceCalendar;
  final bool showDeadlinesOnCalendar;
  final bool notifyMessages;
  final bool notifyHomeworkOverdue;
  final bool notifyExamPrepOverdue;
  final bool notifyDailyDigest;
  final bool notifyInactivity;
  final bool notifyClassUpdates;

  /// Canonical `classId` for exams, deadlines, schedules, and homework — must match
  /// Firestore `users/{uid}.currentClass` (see security rules on those collections).
  String get scheduleExamClassId => currentClass ?? kAppDefaultCurrentClassId;

  const AppUser({
    required this.uid,
    required this.email,
    this.fullName = '',
    required this.schoolRole,
    this.schoolId,
    this.currentClass,
    this.absences = 0,
    this.preferredLanguage = 'el',
    this.isProfileComplete = false,
    this.subjects = const [],
    this.hasTutoring = false,
    this.tutoringSubjects = const [],
    this.hasTakenSampleTest = false,
    this.friends = const [],
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    this.shareGrades = false,
    this.autoAddHomework = false,
    this.classroomIds = const [],
    this.profilePictureUrl,
    this.aiSparks = 25,
    this.subscriptionType = 'free',
    this.lastSparksRefresh,
    this.birthDate,
    this.hasParentalConsent = false,
    this.parentEmail,
    this.consentVerificationStatus,
    this.consentToken,
    this.blockedUsers = const [],
    this.safetyScore = 100,
    this.offenseCount = 0,
    this.reportsCount = 0,
    this.isBannedUntil,
    this.bio = '',
    this.achievements = const [],
    this.showBio = true,
    this.showAchievements = true,
    this.syncToDeviceCalendar = false,
    this.showDeadlinesOnCalendar = true,
    this.notifyMessages = true,
    this.notifyHomeworkOverdue = true,
    this.notifyExamPrepOverdue = true,
    this.notifyDailyDigest = true,
    this.notifyInactivity = true,
    this.notifyClassUpdates = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'schoolRole': schoolRole,
      'schoolId': schoolId,
      'currentClass': currentClass,
      'absences': absences,
      'preferredLanguage': preferredLanguage,
      'isProfileComplete': isProfileComplete,
      'subjects': subjects,
      'hasTutoring': hasTutoring,
      'tutoringSubjects': tutoringSubjects,
      'hasTakenSampleTest': hasTakenSampleTest,
      'friends': friends,
      'friendRequestsSent': friendRequestsSent,
      'friendRequestsReceived': friendRequestsReceived,
      'shareGrades': shareGrades,
      'autoAddHomework': autoAddHomework,
      'classroomIds': classroomIds,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      'aiSparks': aiSparks,
      'subscriptionType': subscriptionType,
      if (lastSparksRefresh != null)
        'lastSparksRefresh': Timestamp.fromDate(lastSparksRefresh!),
      if (birthDate != null) 'birthDate': birthDate,
      'hasParentalConsent': hasParentalConsent,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (consentVerificationStatus != null)
        'consentVerificationStatus': consentVerificationStatus,
      if (consentToken != null) 'consentToken': consentToken,
      'blockedUsers': blockedUsers,
      'safetyScore': safetyScore,
      'offenseCount': offenseCount,
      'reportsCount': reportsCount,
      if (isBannedUntil != null)
        'isBannedUntil': Timestamp.fromDate(isBannedUntil!),
      'bio': bio,
      'achievements': achievements,
      'showBio': showBio,
      'showAchievements': showAchievements,
      'syncToDeviceCalendar': syncToDeviceCalendar,
      'showDeadlinesOnCalendar': showDeadlinesOnCalendar,
      'notifyMessages': notifyMessages,
      'notifyHomeworkOverdue': notifyHomeworkOverdue,
      'notifyExamPrepOverdue': notifyExamPrepOverdue,
      'notifyDailyDigest': notifyDailyDigest,
      'notifyInactivity': notifyInactivity,
      'notifyClassUpdates': notifyClassUpdates,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    // Backward compatible: support both old 'classroomId' and new 'classroomIds'
    List<String> classrooms;
    if (map['classroomIds'] != null) {
      classrooms = List<String>.from(map['classroomIds']);
    } else if (map['classroomId'] != null) {
      classrooms = [map['classroomId'] as String];
    } else {
      classrooms = [];
    }

    // Backward compatible: support old 'tutoringDetails' string
    bool tutoring = map['hasTutoring'] ?? false;
    List<String> tutSubjects = List<String>.from(map['tutoringSubjects'] ?? []);
    if (!tutoring &&
        map['tutoringDetails'] != null &&
        (map['tutoringDetails'] as String).isNotEmpty) {
      tutoring = true;
    }

    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      schoolRole: map['schoolRole'] ?? 'student',
      schoolId: map['schoolId'],
      currentClass: map['currentClass'],
      absences: map['absences']?.toInt() ?? 0,
      preferredLanguage: map['preferredLanguage'] ?? 'el',
      isProfileComplete: map['isProfileComplete'] ?? false,
      subjects: List<String>.from(map['subjects'] ?? []),
      hasTutoring: tutoring,
      tutoringSubjects: tutSubjects,
      hasTakenSampleTest: map['hasTakenSampleTest'] ?? false,
      friends: List<String>.from(map['friends'] ?? []),
      friendRequestsSent: List<String>.from(map['friendRequestsSent'] ?? []),
      friendRequestsReceived: List<String>.from(
        map['friendRequestsReceived'] ?? [],
      ),
      shareGrades: map['shareGrades'] ?? false,
      autoAddHomework: map['autoAddHomework'] ?? false,
      classroomIds: classrooms,
      profilePictureUrl: map['profilePictureUrl'],
      aiSparks: map['aiSparks']?.toInt() ?? 25,
      subscriptionType: map['subscriptionType'] ?? 'free',
      lastSparksRefresh: map['lastSparksRefresh'] != null
          ? (map['lastSparksRefresh'] as Timestamp).toDate()
          : null,
      birthDate: map['birthDate'] != null
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      hasParentalConsent: map['hasParentalConsent'] ?? false,
      parentEmail: map['parentEmail'],
      consentVerificationStatus: map['consentVerificationStatus'],
      consentToken: map['consentToken'],
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      safetyScore: map['safetyScore']?.toInt() ?? 100,
      offenseCount: map['offenseCount']?.toInt() ?? 0,
      reportsCount: map['reportsCount']?.toInt() ?? 0,
      isBannedUntil: map['isBannedUntil'] != null
          ? (map['isBannedUntil'] as Timestamp).toDate()
          : null,
      bio: map['bio'] ?? '',
      achievements: List<String>.from(map['achievements'] ?? []),
      showBio: map['showBio'] ?? true,
      showAchievements: map['showAchievements'] ?? true,
      syncToDeviceCalendar: map['syncToDeviceCalendar'] ?? false,
      showDeadlinesOnCalendar: map['showDeadlinesOnCalendar'] ?? true,
      notifyMessages: map['notifyMessages'] ?? true,
      notifyHomeworkOverdue: map['notifyHomeworkOverdue'] ?? true,
      notifyExamPrepOverdue: map['notifyExamPrepOverdue'] ?? true,
      notifyDailyDigest: map['notifyDailyDigest'] ?? true,
      notifyInactivity: map['notifyInactivity'] ?? true,
      notifyClassUpdates: map['notifyClassUpdates'] ?? true,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? schoolRole,
    String? schoolId,
    String? currentClass,
    int? absences,
    String? preferredLanguage,
    bool? isProfileComplete,
    List<String>? subjects,
    bool? hasTutoring,
    List<String>? tutoringSubjects,
    bool? hasTakenSampleTest,
    List<String>? friends,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    bool? shareGrades,
    bool? autoAddHomework,
    List<String>? classroomIds,
    String? profilePictureUrl,
    int? aiSparks,
    String? subscriptionType,
    DateTime? lastSparksRefresh,
    DateTime? birthDate,
    bool? hasParentalConsent,
    String? parentEmail,
    String? consentVerificationStatus,
    String? consentToken,
    List<String>? blockedUsers,
    int? safetyScore,
    int? offenseCount,
    int? reportsCount,
    DateTime? isBannedUntil,
    String? bio,
    List<String>? achievements,
    bool? showBio,
    bool? showAchievements,
    bool? syncToDeviceCalendar,
    bool? showDeadlinesOnCalendar,
    bool? notifyMessages,
    bool? notifyHomeworkOverdue,
    bool? notifyExamPrepOverdue,
    bool? notifyDailyDigest,
    bool? notifyInactivity,
    bool? notifyClassUpdates,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      schoolRole: schoolRole ?? this.schoolRole,
      schoolId: schoolId ?? this.schoolId,
      currentClass: currentClass ?? this.currentClass,
      absences: absences ?? this.absences,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      subjects: subjects ?? this.subjects,
      hasTutoring: hasTutoring ?? this.hasTutoring,
      tutoringSubjects: tutoringSubjects ?? this.tutoringSubjects,
      hasTakenSampleTest: hasTakenSampleTest ?? this.hasTakenSampleTest,
      friends: friends ?? this.friends,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      friendRequestsReceived:
          friendRequestsReceived ?? this.friendRequestsReceived,
      shareGrades: shareGrades ?? this.shareGrades,
      autoAddHomework: autoAddHomework ?? this.autoAddHomework,
      classroomIds: classroomIds ?? this.classroomIds,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      aiSparks: aiSparks ?? this.aiSparks,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      lastSparksRefresh: lastSparksRefresh ?? this.lastSparksRefresh,
      birthDate: birthDate ?? this.birthDate,
      hasParentalConsent: hasParentalConsent ?? this.hasParentalConsent,
      parentEmail: parentEmail ?? this.parentEmail,
      consentVerificationStatus:
          consentVerificationStatus ?? this.consentVerificationStatus,
      consentToken: consentToken ?? this.consentToken,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      safetyScore: safetyScore ?? this.safetyScore,
      offenseCount: offenseCount ?? this.offenseCount,
      reportsCount: reportsCount ?? this.reportsCount,
      isBannedUntil: isBannedUntil ?? this.isBannedUntil,
      bio: bio ?? this.bio,
      achievements: achievements ?? this.achievements,
      showBio: showBio ?? this.showBio,
      showAchievements: showAchievements ?? this.showAchievements,
      syncToDeviceCalendar: syncToDeviceCalendar ?? this.syncToDeviceCalendar,
      showDeadlinesOnCalendar:
          showDeadlinesOnCalendar ?? this.showDeadlinesOnCalendar,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyHomeworkOverdue:
          notifyHomeworkOverdue ?? this.notifyHomeworkOverdue,
      notifyExamPrepOverdue:
          notifyExamPrepOverdue ?? this.notifyExamPrepOverdue,
      notifyDailyDigest: notifyDailyDigest ?? this.notifyDailyDigest,
      notifyInactivity: notifyInactivity ?? this.notifyInactivity,
      notifyClassUpdates: notifyClassUpdates ?? this.notifyClassUpdates,
    );
  }
}
