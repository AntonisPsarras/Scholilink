import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_functions_helpers.dart';

HttpsCallable _callable(
  String name, {
  Duration timeout = const Duration(seconds: 60),
}) {
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  ).httpsCallable(name, options: HttpsCallableOptions(timeout: timeout));
}

Future<void> callFriendSendRequest(String toUid) async {
  await refreshAuthTokenForCallable();
  await _callable('friendSendRequest').call({'toUid': toUid});
}

Future<void> callFriendAcceptRequest(String fromUid) async {
  await refreshAuthTokenForCallable();
  await _callable('friendAcceptRequest').call({'fromUid': fromUid});
}

Future<void> callFriendDeclineRequest(String fromUid) async {
  await refreshAuthTokenForCallable();
  await _callable('friendDeclineRequest').call({'fromUid': fromUid});
}

Future<void> callFriendCancelRequest(String toUid) async {
  await refreshAuthTokenForCallable();
  await _callable('friendCancelRequest').call({'toUid': toUid});
}

Future<String> callDirectChatGetOrCreate(String otherUid) async {
  await refreshAuthTokenForCallable();
  final res = await _callable('directChatGetOrCreate').call({
    'otherUid': otherUid,
  });
  final data = res.data;
  if (data is Map) {
    final chatId = data['chatId'];
    if (chatId is String && chatId.isNotEmpty) return chatId;
  }
  throw StateError('directChatGetOrCreate returned no chatId');
}

Future<void> callFriendRemove(String friendUid) async {
  await refreshAuthTokenForCallable();
  await _callable('friendRemove').call({'friendUid': friendUid});
}

Future<List<Map<String, dynamic>>> callResolveFriendProfiles(
  List<String> friendUids,
) async {
  if (friendUids.isEmpty) return [];
  await refreshAuthTokenForCallable();
  final res = await _callable('resolveFriendProfiles').call({
    'friendUids': friendUids,
  });
  final data = res.data;
  if (data is! Map) return [];
  final profiles = data['profiles'];
  if (profiles is! List) return [];
  return profiles
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Future<void> callClassroomRemoveMemberAdmin({
  required String classroomId,
  required String targetUserId,
}) async {
  await refreshAuthTokenForCallable();
  await _callable(
    'classroomRemoveMemberAdmin',
  ).call({'classroomId': classroomId, 'targetUserId': targetUserId});
}

Future<void> callClassroomDeleteWithCleanup(String classroomId) async {
  await refreshAuthTokenForCallable();
  await _callable(
    'classroomDeleteWithCleanup',
    timeout: const Duration(seconds: 120),
  ).call({'classroomId': classroomId});
}

Future<void> callDeleteOwnUserFirestoreData() async {
  await refreshAuthTokenForCallable();
  await _callable(
    'deleteOwnUserFirestoreData',
    timeout: const Duration(seconds: 120),
  ).call({});
}

Future<Map<String, dynamic>> callClassroomJoinWithInviteCode(
  String inviteCode,
) async {
  await refreshAuthTokenForCallable();
  final res = await _callable('classroomJoinWithInviteCode').call({
    'inviteCode': inviteCode,
  });
  final data = res.data;
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return {'ok': false};
}

Future<void> callUpdateStudentCurrentClass(String currentClass) async {
  await refreshAuthTokenForCallable();
  await _callable('updateStudentCurrentClass').call({
    'currentClass': currentClass,
  });
}

Future<void> callCompleteStudentOnboarding({
  required String currentClass,
  required List<String> subjects,
  required bool hasTutoring,
  required List<String> tutoringSubjects,
  required int birthDateMillis,
}) async {
  await refreshAuthTokenForCallable();
  await _callable(
    'completeStudentOnboarding',
    timeout: const Duration(seconds: 60),
  ).call({
    'currentClass': currentClass,
    'subjects': subjects,
    'hasTutoring': hasTutoring,
    'tutoringSubjects': tutoringSubjects,
    'birthDateMillis': birthDateMillis,
  });
}

Future<Map<String, dynamic>> callModerateStudentMessage(String text) async {
  await refreshAuthTokenForCallable();
  final res = await _callable(
    'moderateStudentMessage',
    timeout: const Duration(seconds: 45),
  ).call({'text': text});
  final data = res.data;
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return {'flagged': false};
}
