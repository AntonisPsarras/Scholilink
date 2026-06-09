import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_functions_helpers.dart';
import 'spark_limit_message.dart';

/// Next daily Spark reset instant (UTC) from the last [getSparkStatus] / successful AI call response.
final sparkNextResetUtcProvider = StateProvider<DateTime?>((ref) => null);

/// Runs server-side refresh logic (same as before [chatWithAi]) and updates [sparkNextResetUtcProvider].
Future<void> syncSparkStatusFromServer(WidgetRef ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    await refreshAuthTokenForCallable();
    final res = await getSparkStatusCallable().call();
    final raw = res.data;
    if (raw is Map) {
      final map = Map<Object?, Object?>.from(raw);
      final next = nextRefreshFromCallableData(map);
      if (next != null) {
        ref.read(sparkNextResetUtcProvider.notifier).state = next;
      }
    }
  } catch (_) {
    // Offline / unauthenticated — ignore; UI still works with null next-reset time.
  }
}
