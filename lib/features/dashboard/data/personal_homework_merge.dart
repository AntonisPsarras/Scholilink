import '../domain/homework_post_model.dart';

/// Merges homework lists in-memory (no map round-trip). Same semantics as
/// [mergeDedupeSortHomeworkPostMaps].
List<HomeworkPost> mergeDedupeSortHomeworkPosts(
  List<List<HomeworkPost>> lists,
) {
  final allPosts = lists.expand((list) => list).toList();

  final seen = <String>{};
  final uniquePosts = allPosts.where((p) => seen.add(p.postId)).toList();

  uniquePosts.sort((a, b) {
    if (a.dueDate == null && b.dueDate == null) {
      return b.timestamp.compareTo(a.timestamp);
    }
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  });

  return uniquePosts;
}

/// Top-level entry for [compute] — merges personal + classroom homework lists,
/// dedupes by [postId], sorts by due date (then timestamp). Maps use the same
/// shape as [HomeworkPost.toMap].
List<Map<String, dynamic>> mergeDedupeSortHomeworkPostMaps(
  List<List<Map<String, dynamic>>> lists,
) {
  final allPosts = lists.expand((list) => list).toList();

  final seen = <String>{};
  final uniquePosts = allPosts.where((p) {
    final id = p['postId'] as String? ?? '';
    return seen.add(id);
  }).toList();

  uniquePosts.sort((a, b) {
    final aDue = a['dueDate'] as int?;
    final bDue = b['dueDate'] as int?;
    final aTs = a['timestamp'] as int? ?? 0;
    final bTs = b['timestamp'] as int? ?? 0;
    if (aDue == null && bDue == null) {
      return bTs.compareTo(aTs);
    }
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  });

  return uniquePosts;
}
