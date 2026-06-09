import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_model.dart';

/// Firestore collection for [AppUser] fields that are safe to expose to any
/// signed-in peer (see `firestore.rules` on `user_public`).
const String kUserPublicCollection = 'user_public';

/// Keys allowed on `user_public/{uid}` (must match Firestore rules `hasOnly`).
Set<String> get userPublicFieldKeys => {
  'uid',
  'fullName',
  'currentClass',
  'profilePictureUrl',
  'bio',
  'achievements',
  'showBio',
  'showAchievements',
  'shareGrades',
  'preferredLanguage',
  'schoolRole',
  'isProfileComplete',
};

/// Subset of [AppUser] written to [kUserPublicCollection] for classmates / search.
Map<String, dynamic> appUserToPublicMap(AppUser u) {
  return {
    'uid': u.uid,
    'fullName': u.fullName,
    'currentClass': u.currentClass,
    if (u.profilePictureUrl != null) 'profilePictureUrl': u.profilePictureUrl,
    'bio': u.bio,
    'achievements': u.achievements,
    'showBio': u.showBio,
    'showAchievements': u.showAchievements,
    'shareGrades': u.shareGrades,
    'preferredLanguage': u.preferredLanguage,
    'schoolRole': u.schoolRole,
    'isProfileComplete': u.isProfileComplete,
  };
}

/// Merges public profile fields for [u.uid] (best-effort; ignores failures).
Future<void> mergeUserPublicProfile(
  FirebaseFirestore firestore,
  AppUser u,
) async {
  try {
    await firestore
        .collection(kUserPublicCollection)
        .doc(u.uid)
        .set(appUserToPublicMap(u), SetOptions(merge: true));
  } catch (_) {}
}

/// Builds an [AppUser] from a `user_public` document (sensitive fields default empty).
AppUser appUserFromPublicMap(Map<String, dynamic> map, String docUid) {
  return AppUser(
    uid: map['uid'] as String? ?? docUid,
    email: '',
    fullName: map['fullName'] as String? ?? '',
    schoolRole: map['schoolRole'] as String? ?? 'student',
    currentClass: map['currentClass'] as String?,
    preferredLanguage: map['preferredLanguage'] as String? ?? 'el',
    isProfileComplete: map['isProfileComplete'] as bool? ?? false,
    subjects: const [],
    friends: const [],
    friendRequestsSent: const [],
    friendRequestsReceived: const [],
    shareGrades: map['shareGrades'] as bool? ?? false,
    classroomIds: const [],
    profilePictureUrl: map['profilePictureUrl'] as String?,
    bio: map['bio'] as String? ?? '',
    achievements: List<String>.from(map['achievements'] ?? []),
    showBio: map['showBio'] as bool? ?? true,
    showAchievements: map['showAchievements'] as bool? ?? true,
  );
}
