import '../domain/homework_post_model.dart';

/// Row kind for the homework history [ListView.builder].
enum HomeworkHistoryVirtualKind { summary, gap, subjectHeader, homeworkCard }

/// One row in the virtualized homework history list (built from raw history once per data update).
class HomeworkHistoryVirtualItem {
  final HomeworkHistoryVirtualKind type;
  final int completedCount;
  final int forgottenCount;
  final double gapHeight;
  final String? subject;
  final int? subjectCount;
  final HomeworkPost? post;

  const HomeworkHistoryVirtualItem.summary(
    this.completedCount,
    this.forgottenCount,
  ) : type = HomeworkHistoryVirtualKind.summary,
      gapHeight = 0,
      subject = null,
      subjectCount = null,
      post = null;

  const HomeworkHistoryVirtualItem.gap(this.gapHeight)
    : type = HomeworkHistoryVirtualKind.gap,
      completedCount = 0,
      forgottenCount = 0,
      subject = null,
      subjectCount = null,
      post = null;

  const HomeworkHistoryVirtualItem.subjectHeader(
    this.subject,
    this.subjectCount,
  ) : type = HomeworkHistoryVirtualKind.subjectHeader,
      completedCount = 0,
      forgottenCount = 0,
      gapHeight = 0,
      post = null;

  const HomeworkHistoryVirtualItem.homeworkCard(this.post)
    : type = HomeworkHistoryVirtualKind.homeworkCard,
      completedCount = 0,
      forgottenCount = 0,
      gapHeight = 0,
      subject = null,
      subjectCount = null;
}

/// Precomputed list rows for [HomeworkHistoryScreen] — derived from Firestore list only when that data changes.
class HomeworkHistoryLayout {
  final List<HomeworkHistoryVirtualItem> virtualItems;

  const HomeworkHistoryLayout._(this.virtualItems);

  /// Empty raw list → empty layout (UI shows empty state).
  factory HomeworkHistoryLayout.fromItems(List<HomeworkPost> items) {
    if (items.isEmpty) {
      return const HomeworkHistoryLayout._([]);
    }

    final grouped = <String, List<HomeworkPost>>{};
    for (final hw in items) {
      grouped.putIfAbsent(hw.subject, () => []).add(hw);
    }

    final completedCount = items.where((i) => i.isCompleted).length;
    final forgottenCount = items.length - completedCount;

    final rows = <HomeworkHistoryVirtualItem>[
      HomeworkHistoryVirtualItem.summary(completedCount, forgottenCount),
      const HomeworkHistoryVirtualItem.gap(16),
    ];
    for (final entry in grouped.entries) {
      rows.add(
        HomeworkHistoryVirtualItem.subjectHeader(entry.key, entry.value.length),
      );
      for (final hw in entry.value) {
        rows.add(HomeworkHistoryVirtualItem.homeworkCard(hw));
      }
      rows.add(const HomeworkHistoryVirtualItem.gap(16));
    }
    return HomeworkHistoryLayout._(rows);
  }

  bool get isEmpty => virtualItems.isEmpty;
}
