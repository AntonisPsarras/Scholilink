import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/chat_message_model.dart';
import '../domain/poll_model.dart';
import 'chat_service.dart';

import '../../auth/data/auth_repository.dart';

/// Tracks how many messages to load per classroom.  Increment this to paginate
/// older history (each increment fetches 50 more messages from Firestore).
final chatMessageLimitProvider = StateProvider.autoDispose
    .family<int, String>((ref, classroomId) => 50);

/// Watches chat messages for a given classroom.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, classroomId) {
      // Isolate from unrelated user-document fields (sparks, profile, etc.).
      final blockedUsers = ref.watch(
        authStateProvider.select(
          (async) => async.valueOrNull?.blockedUsers ?? const <String>[],
        ),
      );
      final limit = ref.watch(chatMessageLimitProvider(classroomId));

      return ref
          .watch(chatServiceProvider)
          .watchMessages(classroomId, limit: limit)
          .map((messages) {
            return messages
                .where((msg) => !blockedUsers.contains(msg.authorId))
                .toList();
          });
    });

/// Watches a specific poll document.
///
/// **autoDispose** cancels the Firestore listener as soon as no widget is
/// watching this poll (e.g. the message scrolled far out of the list’s
/// cache extent), which avoids N simultaneous listeners in long chats.
///
/// **Batching alternative:** A single `classrooms/{id}/polls` collection
/// snapshot would be one listener but would download and re-emit *every* poll
/// in the class on any change—often worse for bandwidth and UI churn than
/// a bounded set of per-doc streams for on-screen messages only.
final pollProvider = StreamProvider.autoDispose.family<Poll?, String>((
  ref,
  pollKey,
) {
  // pollKey format: "classroomId/pollId"
  final parts = pollKey.split('/');
  if (parts.length != 2) return Stream.value(null);
  return ref.watch(chatServiceProvider).watchPoll(parts[0], parts[1]);
});
