import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/notification_service.dart';
import '../../../theme/app_theme.dart';
import '../domain/homework_post_model.dart';
import '../domain/deadline_model.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/exam_model.dart';
import '../domain/grade_model.dart';
import '../domain/exam_result_model.dart';
import 'dashboard_repository.dart';
import 'homework_due_cutoff.dart';
import 'homework_history_layout.dart';

final personalHomeworkProvider = StreamProvider.autoDispose<List<HomeworkPost>>(
  (ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Stream.value(const <HomeworkPost>[]);
    return ref
        .watch(dashboardRepositoryProvider)
        .watchPersonalHomework(user.uid, user.classroomIds);
  },
);

final personalHomeworkDueTomorrowProvider =
    Provider.autoDispose<AsyncValue<List<HomeworkPost>>>((ref) {
      return ref.watch(personalHomeworkProvider).whenData((homework) {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        return homework.where((hw) {
          if (hw.dueDate == null) return false;
          return hw.dueDate!.year == tomorrow.year &&
              hw.dueDate!.month == tomorrow.month &&
              hw.dueDate!.day == tomorrow.day;
        }).toList();
      });
    });

final homeworkStreamProvider = FutureProvider.autoDispose
    .family<List<HomeworkPost>, String>((ref, classId) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <HomeworkPost>[];
      return ref.watch(dashboardRepositoryProvider).getHomeworkPosts(classId);
    });

final scheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, classId) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <Map<String, dynamic>>[];
      return ref.watch(dashboardRepositoryProvider).getSchedule(classId);
    });

/// Same shape as [scheduleProvider], but when a non-expired temporary schedule exists
/// (earliest [expiresAt] wins, matching [DashboardRepository.getActiveSchedule]),
/// returns that week's [days] and [isTemporarySubstitution] is true.
class ActiveScheduleBundle {
  const ActiveScheduleBundle({
    required this.days,
    required this.isTemporarySubstitution,
  });

  final List<Map<String, dynamic>> days;
  final bool isTemporarySubstitution;

  static const empty = ActiveScheduleBundle(
    days: <Map<String, dynamic>>[],
    isTemporarySubstitution: false,
  );
}

final activeScheduleInfoProvider = FutureProvider.autoDispose
    .family<ActiveScheduleBundle, String>((ref, classId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return ActiveScheduleBundle.empty;

      final repo = ref.watch(dashboardRepositoryProvider);
      final now = DateTime.now();
      final temps = await repo.getTemporarySchedules(classId);
      final active = temps.where((t) {
        final expMs = t['expiresAt'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(expMs).isAfter(now);
      }).toList();

      if (active.isNotEmpty) {
        active.sort(
          (a, b) => (a['expiresAt'] as int).compareTo(b['expiresAt'] as int),
        );
        final first = active.first;
        final daysRaw = first['days'];
        if (daysRaw != null) {
          return ActiveScheduleBundle(
            days: List<Map<String, dynamic>>.from(daysRaw as List),
            isTemporarySubstitution: true,
          );
        }
      }

      final permanent = await repo.getSchedule(classId);
      return ActiveScheduleBundle(
        days: permanent,
        isTemporarySubstitution: false,
      );
    });

final examProvider = FutureProvider.autoDispose.family<List<Exam>, String>((
  ref,
  classId,
) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const <Exam>[];
  return ref.watch(dashboardRepositoryProvider).getExams(classId);
});

/// Fetches grades for the current user.
final gradesProvider = FutureProvider.autoDispose<List<GradeRecord>>((
  ref,
) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const <GradeRecord>[];
  return ref.watch(dashboardRepositoryProvider).getGrades(uid);
});

/// Fetches exam results for the current user (current school year only when
/// [schoolYear] is provided via the family provider).
final examResultsProvider = FutureProvider.autoDispose<List<ExamResult>>((
  ref,
) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const <ExamResult>[];
  return ref.watch(dashboardRepositoryProvider).getExamResults(uid);
});

/// Fetches exam results for a specific school year (used for history view).
final examResultsHistoryProvider = FutureProvider.autoDispose
    .family<List<ExamResult>, String>((ref, schoolYear) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <ExamResult>[];
      return ref
          .watch(dashboardRepositoryProvider)
          .getExamResults(uid, schoolYear: schoolYear);
    });

/// Returns the list of school years for which the user has exam results.
final examResultYearsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const <String>[];
  return ref.watch(dashboardRepositoryProvider).getExamResultYears(uid);
});

/// Returns the list of school years for which the user has grade records.
final gradeYearsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const <String>[];
  return ref.watch(dashboardRepositoryProvider).getGradeYears(uid);
});

/// Fetches grades for a specific school year (used for history view).
final gradesHistoryProvider = FutureProvider.autoDispose
    .family<List<GradeRecord>, String>((ref, schoolYear) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <GradeRecord>[];
      return ref
          .watch(dashboardRepositoryProvider)
          .getGrades(uid, schoolYear: schoolYear);
    });

/// Real-time completed homework IDs (Firestore snapshots — no refetch on toggle).
final completedHomeworkIdsProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(dashboardRepositoryProvider).watchCompletedHomeworkIds(uid);
});

/// Fetches homework due tomorrow for a class.
final homeworkDueTomorrowProvider = FutureProvider.autoDispose
    .family<List<HomeworkPost>, String>((ref, classId) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <HomeworkPost>[];
      return ref
          .watch(dashboardRepositoryProvider)
          .getHomeworkDueTomorrow(classId);
    });

/// Fetches homework history for a specific school year.
final homeworkHistoryProvider = FutureProvider.autoDispose
    .family<List<HomeworkPost>, String>((ref, schoolYear) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <HomeworkPost>[];
      return ref
          .watch(dashboardRepositoryProvider)
          .getHomeworkHistory(uid, schoolYear);
    });

/// Grouping + virtual rows for [HomeworkHistoryScreen]. Recomputes only when
/// [homeworkHistoryProvider] emits new data, not on unrelated rebuilds or scroll.
final homeworkHistoryLayoutProvider = Provider.autoDispose
    .family<AsyncValue<HomeworkHistoryLayout>, String>((ref, schoolYear) {
      final async = ref.watch(homeworkHistoryProvider(schoolYear));
      return async.when(
        data: (items) =>
            AsyncValue.data(HomeworkHistoryLayout.fromItems(items)),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Fetches deadlines (projects & presentations) for a class.
final deadlineProvider = FutureProvider.autoDispose
    .family<List<Deadline>, String>((ref, classId) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const <Deadline>[];
      return ref.watch(dashboardRepositoryProvider).getDeadlines(classId);
    });

/// Real-time stream of calendar events (exams + deadlines) for a class.
/// Using StreamProvider means the calendar widget auto-updates whenever Firestore
/// data changes — no manual invalidation required after addExam/addDeadline.
final calendarEventsProvider = StreamProvider.autoDispose
    .family<Map<DateTime, List<Map<String, dynamic>>>, String>((ref, classId) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) {
        return Stream.value(const <DateTime, List<Map<String, dynamic>>>{});
      }
      return ref
          .watch(dashboardRepositoryProvider)
          .watchCalendarEvents(classId);
    });

/// Archives overdue, incomplete homework from the personal feed (Firestore + notification).
/// Runs outside widget [build]; dedupes by post id to avoid redundant writes.
class _HomeworkOverdueArchiver {
  _HomeworkOverdueArchiver(this._ref);

  final Ref _ref;
  final Set<String> _inFlightOrDone = {};
  bool _disposed = false;
  bool _queued = false;

  void schedule() {
    if (_disposed) return;
    if (_queued) return;
    _queued = true;
    Future.microtask(() {
      _queued = false;
      if (!_disposed) {
        _process();
      }
    });
  }

  Future<void> _process() async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null || _disposed) return;

    final postsAsync = _ref.read(personalHomeworkProvider);
    final completedAsync = _ref.read(completedHomeworkIdsProvider);

    final posts = postsAsync.valueOrNull;
    final completed = completedAsync.valueOrNull;
    if (posts == null || completed == null) return;

    final now = DateTime.now();
    final schoolYear = now.month >= 9
        ? '${now.year}-${now.year + 1}'
        : '${now.year - 1}-${now.year}';
    final repo = _ref.read(dashboardRepositoryProvider);

    for (final post in posts) {
      if (_disposed) return;
      if (post.dueDate == null) continue;

      if (!isPastHomeworkFeedCutoff(post.dueDate!, now)) continue;
      if (completed.contains(post.postId)) continue;
      if (_inFlightOrDone.contains(post.postId)) continue;

      _inFlightOrDone.add(post.postId);
      try {
        await repo.moveToHistory(
          user.uid,
          post,
          schoolYear,
          isCompleted: false,
        );
        await NotificationService().showForgottenHomeworkNotification(
          subject: post.subject,
          lang: user.preferredLanguage,
        );
      } catch (e, st) {
        _inFlightOrDone.remove(post.postId);
        debugPrint(
          'Homework overdue archive failed for ${post.postId}: $e\n$st',
        );
      }
    }
  }

  void dispose() {
    _disposed = true;
  }
}

/// Side-effect provider: keep this watched from the homework feed while that screen is active.
final homeworkOverdueArchiverProvider = Provider.autoDispose<int>((ref) {
  final archiver = _HomeworkOverdueArchiver(ref);
  ref.onDispose(archiver.dispose);
  ref.listen<AsyncValue<List<HomeworkPost>>>(
    personalHomeworkProvider,
    (_, __) => archiver.schedule(),
    fireImmediately: true,
  );
  ref.listen<AsyncValue<Set<String>>>(
    completedHomeworkIdsProvider,
    (_, __) => archiver.schedule(),
    fireImmediately: true,
  );
  return 0;
});

// Business Logic for Absences
class AbsenceLogic {
  static const int maxAbsences = 114;
  static const int warningThreshold = 80;
  static const int criticalThreshold = 100;

  static bool shouldWarn(int currentAbsences) {
    return currentAbsences >= warningThreshold;
  }

  static Color getAbsenceColor(int currentAbsences, AppBrandColors brand) {
    if (currentAbsences >= criticalThreshold) return brand.dangerRose;
    if (currentAbsences >= warningThreshold) return brand.sunsetWarning;
    return brand.mintSuccess;
  }

  static double calculatePercentage(int currentAbsences) {
    return (currentAbsences / maxAbsences).clamp(0.0, 1.0);
  }

  static double calculateReadiness(int currentAbsences) {
    return 1.0 - calculatePercentage(currentAbsences);
  }
}

// Business Logic for Grading
class GradingLogic {
  static bool isValidGrade(double grade) {
    return grade >= 0 && grade <= 20;
  }

  static String getPerformanceLabel(double grade) {
    if (grade >= 18) return 'Άριστα! Συνέχισε έτσι! 🏆';
    if (grade >= 15) return 'Πολύ καλά! Είσαι σε καλό δρόμο';
    if (grade >= 12) return 'Καλά, αλλά μπορείς καλύτερα';
    if (grade >= 10) return 'Οριακά, χρειάζεσαι βελτίωση';
    return 'Κάτω από τη βάση — μην τα παρατάς';
  }
}
