// Homework leaves the active feed at 08:15 on the due calendar day
// in the user's local device timezone.

/// 08:15 local on the due date derived from [dueDate] (wall date in local time).
DateTime homeworkFeedCutoffLocal(DateTime dueDate) {
  final local = dueDate.toLocal();
  return DateTime(local.year, local.month, local.day, 8, 15);
}

/// Whether [now] is at or after the local feed cutoff for this due date.
bool isPastHomeworkFeedCutoff(DateTime dueDate, [DateTime? now]) {
  final instant = now ?? DateTime.now();
  final cutoff = homeworkFeedCutoffLocal(dueDate);
  return !instant.isBefore(cutoff);
}
