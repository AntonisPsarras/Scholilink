import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/domain/classroom_model.dart';
import '../../dashboard/domain/homework_post_model.dart';
import '../../auth/domain/user_model.dart';
import 'classroom_service.dart';
import 'friendship_service.dart';

/// Currently selected classroom ID (for viewing chat/details).
final selectedClassroomIdProvider = StateProvider<String?>((ref) => null);

/// Watches all classrooms the user belongs to.
final userClassroomsProvider = StreamProvider.autoDispose<List<Classroom>>((
  ref,
) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    data: (user) {
      if (user == null || user.classroomIds.isEmpty) return Stream.value([]);
      return ref
          .watch(classroomServiceProvider)
          .watchUserClassrooms(user.classroomIds);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

/// Watches the currently selected classroom.
final selectedClassroomProvider = StreamProvider.autoDispose<Classroom?>((ref) {
  final classroomId = ref.watch(selectedClassroomIdProvider);
  if (classroomId == null) return Stream.value(null);
  return ref.watch(classroomServiceProvider).watchClassroom(classroomId);
});

/// Watches homework for the selected classroom.
final classroomHomeworkProvider =
    StreamProvider.autoDispose<List<HomeworkPost>>((ref) {
      final classroomId = ref.watch(selectedClassroomIdProvider);
      if (classroomId == null) return Stream.value([]);
      return ref
          .watch(classroomServiceProvider)
          .watchClassroomHomework(classroomId);
    });

/// Fetches friends of the current user (refetches only when [AppUser.friends] changes).
final friendsProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final friends = ref.watch(
    authStateProvider.select((async) => async.valueOrNull?.friends),
  );
  if (friends == null || friends.isEmpty) return <AppUser>[];
  try {
    return await ref.read(friendshipServiceProvider).getFriends(friends);
  } catch (e) {
    debugPrint('friendsProvider: $e');
    return <AppUser>[];
  }
});

/// UIDs of users who sent pending friend requests to the current user.
final pendingFriendRequestUidsProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  return ref.watch(authStateProvider).valueOrNull?.friendRequestsReceived ??
      const [];
});

/// UIDs the current user sent friend requests to (still pending).
final sentFriendRequestUidsProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  return ref.watch(authStateProvider).valueOrNull?.friendRequestsSent ??
      const [];
});
