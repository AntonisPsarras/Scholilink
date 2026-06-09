import 'package:flutter/material.dart';

bool chatSameCalendarDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Top padding for a row in a reverse [ListView] of chat messages.
/// [newer] is the message at the current index (closer to the bottom).
/// [older] is the message visually above it (index + 1), when present.
double chatMessageTopPadding({
  required DateTime newer,
  required DateTime? older,
  required String newerAuthorId,
  required String? olderAuthorId,
}) {
  if (older == null || olderAuthorId == null) return 6;
  if (!chatSameCalendarDay(newer, older)) return 18;
  if (newerAuthorId != olderAuthorId) return 14;
  return 10;
}

Widget chatMessageListGap({
  required double topPadding,
  required Widget child,
}) {
  return Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: child,
  );
}
