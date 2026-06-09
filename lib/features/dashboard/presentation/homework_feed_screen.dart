import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/image_utils.dart';
import '../../../shared/notification_service.dart';
import '../data/dashboard_logic.dart';
import '../data/homework_due_cutoff.dart';
import '../data/dashboard_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/parental_consent_eligibility.dart';
import '../../auth/presentation/parental_consent_screen.dart';
import '../../auth/domain/user_model.dart';
import '../domain/homework_post_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/type_picker_dialog.dart';
import '../../../shared/widgets/firebase_error_widget.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/responsive_layout.dart';
import '../../navigation/data/navigation_provider.dart';
import 'homework_history_screen.dart';
import 'exam_results_screen.dart';
import '../../../shared/widgets/empty_state_shimmer.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/storage_service.dart';
import '../../../shared/utils/firebase_error_handler.dart';
import '../../messaging/presentation/voice_recorder_widget.dart';
import '../../../shared/widgets/user_profile_sheet.dart';
import '../../../shared/ocr_image_bytes.dart';
import '../../../shared/app_shell_insets.dart';
import '../application/homework_ocr_controller.dart';

/// Legacy stored type `other` is shown and edited as daily.
String _homeworkTypeUi(String? raw) {
  if (raw == null || raw == 'other') return 'daily';
  return raw;
}

String _homeworkSectionLabel(DateTime? dueDate, S s) {
  if (dueDate == null) {
    return s.lang == 'el' ? 'Χωρίς ημερομηνία' : 'Unscheduled';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final tomorrow = today.add(const Duration(days: 1));
  if (target == tomorrow) {
    return s.lang == 'el' ? 'Για αύριο' : 'For tomorrow';
  }
  return s.lang == 'el'
      ? 'Για ${target.day}/${target.month}'
      : 'For ${target.day}/${target.month}';
}

/// Immutable slice of [AppUser] the homework feed depends on. With
/// [authStateProvider.select], the screen does not rebuild on unrelated user
/// document changes (e.g. sparks, safety counters).
@immutable
class _HomeworkFeedUser {
  final String uid;
  final String preferredLanguage;
  final String classId;
  final List<String> subjects;

  const _HomeworkFeedUser({
    required this.uid,
    required this.preferredLanguage,
    required this.classId,
    required this.subjects,
  });

  factory _HomeworkFeedUser.fromAppUser(AppUser u) {
    return _HomeworkFeedUser(
      uid: u.uid,
      preferredLanguage: u.preferredLanguage,
      classId: u.scheduleExamClassId,
      subjects: u.subjects,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HomeworkFeedUser &&
        other.uid == uid &&
        other.preferredLanguage == preferredLanguage &&
        other.classId == classId &&
        listEquals(other.subjects, subjects);
  }

  @override
  int get hashCode =>
      Object.hash(uid, preferredLanguage, classId, Object.hashAll(subjects));
}

class HomeworkFeedScreen extends ConsumerWidget {
  const HomeworkFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAuth = ref.watch(
      authStateProvider.select(
        (async) => async.when(
          data: (AppUser? u) {
            if (u == null) {
              return (
                loading: false,
                err: false,
                error: null,
                loggedOut: true,
                user: null,
              );
            }
            return (
              loading: false,
              err: false,
              error: null,
              loggedOut: false,
              user: _HomeworkFeedUser.fromAppUser(u),
            );
          },
          loading: () => (
            loading: true,
            err: false,
            error: null,
            loggedOut: false,
            user: null,
          ),
          error: (Object e, _) => (
            loading: false,
            err: true,
            error: e,
            loggedOut: false,
            user: null,
          ),
        ),
      ),
    );

    if (feedAuth.loading) {
      final lang = ref.watch(userLanguageProvider);
      return Scaffold(body: Center(child: Text(S(lang).loading)));
    }
    if (feedAuth.err) {
      return Scaffold(body: FirebaseErrorWidget(error: feedAuth.error!));
    }
    if (feedAuth.loggedOut) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final user = feedAuth.user!;
    final s = S(user.preferredLanguage);
    ref.watch(homeworkOverdueArchiverProvider);
    final homeworkAsync = ref.watch(personalHomeworkProvider);
    final completedIdsAsync = ref.watch(completedHomeworkIdsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Allow global gradient
      appBar: AppBar(
        title: Text(s.homeworkStream),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: context.brand.neutralGrey),
            tooltip: s.homeworkHistory,
            onPressed: () {
              if (ResponsiveLayout.isDesktop(context) ||
                  ResponsiveLayout.isTablet(context)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(centerOverlayProvider.notifier).state =
                      const HomeworkHistoryScreen();
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeworkHistoryScreen(),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle,
              color: context.brand.royalLavender,
              size: 30,
            ),
            onPressed: () => _showAddHomeworkDialog(
              context,
              ref,
              user.uid,
              user.classId,
              user.preferredLanguage,
              user.subjects,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: homeworkAsync.when(
              data: (posts) {
                final completedIds = completedIdsAsync.value ?? {};

                // Filter out overdue items (archival is handled by homeworkOverdueArchiverProvider).
                final now = DateTime.now();

                final visiblePosts = <HomeworkPost>[];

                for (final post in posts) {
                  if (post.dueDate != null) {
                    if (isPastHomeworkFeedCutoff(post.dueDate!, now)) {
                      // Past 08:15 local on due day — hidden from feed; archival runs
                      // in [homeworkOverdueArchiverProvider] (not during build).
                      continue;
                    }
                  }

                  visiblePosts.add(post);
                }

                if (visiblePosts.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: context.brand.mintSuccess,
                      title: s.lang == 'el' ? 'Όλα τέλεια!' : 'All caught up!',
                      message: s.lang == 'el'
                          ? 'Ολοκλήρωσες όλες τις εργασίες σου. Απόλαυσε τον ελεύθερο χρόνο σου!'
                          : 'You have finished all your homework. Enjoy your free time!',
                      action: LiquidTouch(
                        onTap: () {
                          if (ResponsiveLayout.isDesktop(context) ||
                              ResponsiveLayout.isTablet(context)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(centerOverlayProvider.notifier).state =
                                  const ExamResultsScreen();
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExamResultsScreen(),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? context.brand.surfaceElevated
                                : Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assessment_rounded,
                                color: context.brand.royalLavender,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s.lang == 'el'
                                    ? 'Δες τις Βαθμολογίες σου'
                                    : 'Review your Grades',
                                style: TextStyle(
                                  color: context.brand.darkText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final bottomPad = shellBottomContentPadding(context);
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(personalHomeworkProvider.future),
                  child: Column(
                    children: [
                      // Homework count header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Row(
                          children: [
                            Text(
                              '${s.totalHomework}: ${visiblePosts.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.brand.neutralGrey,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${completedIds.intersection(visiblePosts.map((p) => p.postId).toSet()).length} ${s.markComplete.toLowerCase()}',
                              style: TextStyle(
                                color: context.brand.mintSuccess,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                          itemCount: visiblePosts.length,
                          itemBuilder: (context, listIndex) {
                            final current = visiblePosts[listIndex];
                            final previousDueDate = listIndex > 0
                                ? visiblePosts[listIndex - 1].dueDate
                                : null;
                            final previousDay = DateTime(
                              previousDueDate?.year ?? 0,
                              previousDueDate?.month ?? 1,
                              previousDueDate?.day ?? 1,
                            );
                            final currentDay = DateTime(
                              current.dueDate?.year ?? 0,
                              current.dueDate?.month ?? 1,
                              current.dueDate?.day ?? 1,
                            );
                            final shouldShowHeader =
                                listIndex == 0 || previousDay != currentDay;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shouldShowHeader)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      8,
                                      4,
                                      10,
                                    ),
                                    child: Text(
                                      _homeworkSectionLabel(current.dueDate, s),
                                      style: TextStyle(
                                        color: context.brand.royalLavender,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                _HomeworkCard(
                                  post: current,
                                  user: user,
                                  isCompleted: completedIds.contains(
                                    current.postId,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => FirebaseErrorWidget(error: err),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddHomeworkDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String classId,
    String lang,
    List<String> subjects,
  ) {
    final s = S(lang);

    /// Host screen context (still valid after the dialog is closed).
    final hostContext = context;
    String? selectedSubject;
    String selectedType = 'daily';
    DateTime? selectedDueDate;
    final contentController = TextEditingController();
    final List<XFile> pendingNewImages = [];
    bool showVoiceRecorder = false;
    Uint8List? pendingVoiceBytes;
    var reminderEnabled = true;
    var reminderClock = const TimeOfDay(hour: 20, minute: 0);

    ref.read(homeworkOcrControllerProvider.notifier).reset();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.homeworkStream),
          content: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final isProcessingOcr = ref.watch(
                  homeworkOcrControllerProvider.select(
                    (s) => s.isProcessingOcr,
                  ),
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Smart Add OCR
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.brand.royalLavender.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.brand.royalLavender.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: context.brand.royalLavender,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.lang == 'el'
                                  ? 'Αυτόματη περιγραφή με AI'
                                  : 'AI auto description',
                              style: TextStyle(color: context.brand.darkText),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isProcessingOcr
                                ? null
                                : () async {
                                    final gateUser = ref
                                        .read(authStateProvider)
                                        .value;
                                    if (gateUser != null &&
                                        requiresParentalAiGate(gateUser)) {
                                      await showDialog<void>(
                                        context: hostContext,
                                        builder: (dCtx) => Dialog(
                                          clipBehavior: Clip.antiAlias,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 420,
                                            ),
                                            child: const SingleChildScrollView(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: ParentalConsentScreen(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final curUser = ref
                                        .read(authStateProvider)
                                        .value;
                                    if (curUser != null &&
                                        curUser.aiSparks <= 0) {
                                      CustomSnackBar.show(
                                        context: context,
                                        message: sparkLimitUserMessage(
                                          preferredLanguage:
                                              curUser.preferredLanguage,
                                          nextResetUtc: ref.read(
                                            sparkNextResetUtcProvider,
                                          ),
                                          subscriptionType:
                                              curUser.subscriptionType,
                                        ),
                                        type: SnackBarType.warning,
                                      );
                                      return;
                                    }
                                    final picker = ImagePicker();
                                    final picked = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 75,
                                      maxWidth: 1600,
                                    );
                                    if (picked == null) return;
                                    final rawBytes = await picked.readAsBytes();
                                    final bytes = await compute(
                                      encodeImageBytesForGeminiOcr,
                                      rawBytes,
                                    );
                                    final result = await ref
                                        .read(
                                          homeworkOcrControllerProvider
                                              .notifier,
                                        )
                                        .scanImage(
                                          imageBytes: bytes,
                                          availableSubjects: subjects,
                                          userHint: s.lang == 'el'
                                              ? 'Ανάλυσε την άσκηση και δώσε καθαρή περιγραφή.'
                                              : 'Analyze the exercise and summarize homework.',
                                        );
                                    if (result != null) {
                                      setDialogState(() {
                                        contentController.text = result.content;
                                      });
                                    } else if (context.mounted) {
                                      final err = ref
                                          .read(homeworkOcrControllerProvider)
                                          .error;
                                      CustomSnackBar.show(
                                        context: context,
                                        message:
                                            err ??
                                            (s.lang == 'el'
                                                ? 'Αποτυχία σάρωσης εικόνας.'
                                                : 'Could not scan the image.'),
                                        type: SnackBarType.error,
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.image_search_rounded,
                              size: 18,
                            ),
                            label: Text(s.lang == 'el' ? 'Σάρωση' : 'Scan'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: isProcessingOcr
                          ? const HomeworkOcrFormSkeleton(
                              key: ValueKey('hw_ocr_loading'),
                            )
                          : Column(
                              key: const ValueKey('hw_ocr_form'),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Subject Picker
                                InkWell(
                                  onTap: () async {
                                    final picked =
                                        await showSubjectPickerDialog(
                                          context: context,
                                          subjects: subjects,
                                          title: s.selectSubject,
                                          currentSubject: selectedSubject,
                                        );
                                    if (picked != null) {
                                      setDialogState(
                                        () => selectedSubject = picked,
                                      );
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: s.subject,
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                      ),
                                    ),
                                    child: Text(
                                      selectedSubject ?? s.selectSubject,
                                      style: TextStyle(
                                        color: selectedSubject != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : context.brand.neutralGrey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Homework Type
                                // Homework Type Picker
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTypePickerDialog(
                                      context: context,
                                      currentType: selectedType,
                                      s: s,
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                        () => selectedType = picked,
                                      );
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: s.homeworkType,
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                      ),
                                    ),
                                    child: Text(
                                      selectedType == 'project'
                                          ? s.projectHomework
                                          : s.dailyHomework,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Due date: required for project, optional for daily (no auto-fill).
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          selectedDueDate ??
                                          DateTime.now().add(
                                            const Duration(days: 1),
                                          ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                        () => selectedDueDate = picked,
                                      );
                                    }
                                  },
                                  onLongPress: selectedType == 'daily'
                                      ? () => setDialogState(
                                          () => selectedDueDate = null,
                                        )
                                      : null,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: selectedType == 'project'
                                          ? s.dueDateRequiredForProject
                                          : s.dueDateOptional,
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (selectedDueDate != null &&
                                              selectedType == 'daily')
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                size: 16,
                                              ),
                                              onPressed: () => setDialogState(
                                                () => selectedDueDate = null,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          const Icon(Icons.calendar_today),
                                        ],
                                      ),
                                      helperText: selectedType == 'project'
                                          ? (s.lang == 'el'
                                                ? 'Υποχρεωτική για project'
                                                : 'Required for projects')
                                          : (selectedDueDate == null
                                                ? (s.lang == 'el'
                                                      ? 'Προαιρετική — χωρίς ημερομηνία αν θέλεις'
                                                      : 'Optional — leave unset if you prefer')
                                                : null),
                                      helperStyle: TextStyle(
                                        fontSize: 11,
                                        color: selectedType == 'project'
                                            ? context.brand.errorRed.withValues(
                                                alpha: 0.85,
                                              )
                                            : context.brand.neutralGrey,
                                      ),
                                    ),
                                    child: Text(
                                      selectedDueDate != null
                                          ? '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'
                                          : (selectedType == 'project'
                                                ? (s.lang == 'el'
                                                      ? 'Πάτησε για επιλογή'
                                                      : 'Tap to choose')
                                                : (s.lang == 'el'
                                                      ? 'Χωρίς ημερομηνία'
                                                      : 'No due date')),
                                      style: TextStyle(
                                        color: selectedDueDate != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : (selectedType == 'project'
                                                  ? context.brand.errorRed
                                                  : context.brand.neutralGrey),
                                        fontStyle: selectedDueDate == null
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                if (selectedDueDate != null) ...[
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      s.lang == 'el'
                                          ? 'Υπενθύμιση'
                                          : 'Reminder',
                                    ),
                                    subtitle: Text(
                                      s.lang == 'el'
                                          ? 'Την προηγούμενη βράδυ πριν την παράδοση'
                                          : 'The evening before the due date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.brand.neutralGrey,
                                      ),
                                    ),
                                    value: reminderEnabled,
                                    onChanged: (v) => setDialogState(
                                      () => reminderEnabled = v,
                                    ),
                                  ),
                                  if (reminderEnabled)
                                    InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(
                                          context: context,
                                          initialTime: reminderClock,
                                        );
                                        if (t != null) {
                                          setDialogState(
                                            () => reminderClock = t,
                                          );
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: s.lang == 'el'
                                              ? 'Ώρα υπενθύμισης'
                                              : 'Reminder time',
                                        ),
                                        child: Text(
                                          reminderClock.format(context),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],

                                // Content
                                TextField(
                                  controller: contentController,
                                  decoration: InputDecoration(
                                    labelText: s.homeworkContent,
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),

                                // Preview Row
                                if (pendingNewImages.isNotEmpty) ...[
                                  SizedBox(
                                    height: 60,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: pendingNewImages.length,
                                      itemBuilder: (ctx, i) => Stack(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.image,
                                              color: context.brand.neutralGrey,
                                            ),
                                          ),
                                          Positioned(
                                            right: 8,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () => setDialogState(
                                                () => pendingNewImages.removeAt(
                                                  i,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    context.brand.errorRed,
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Attachment buttons (voice + photo)
                                if (showVoiceRecorder)
                                  VoiceRecorderWidget(
                                    onCancel: () => setDialogState(
                                      () => showVoiceRecorder = false,
                                    ),
                                    onSend:
                                        (
                                          Uint8List bytes,
                                          int durationMs,
                                          List<double> amplitudes,
                                        ) async {
                                          setDialogState(() {
                                            pendingVoiceBytes = bytes;
                                            showVoiceRecorder = false;
                                          });
                                        },
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (pendingVoiceBytes != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.mic,
                                                  size: 18,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  s.lang == 'el'
                                                      ? 'Ηχητικό έτοιμο'
                                                      : 'Voice note ready',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                GestureDetector(
                                                  onTap: () => setDialogState(
                                                    () {
                                                      pendingVoiceBytes = null;
                                                    },
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            onPressed: () => setDialogState(
                                              () => showVoiceRecorder = true,
                                            ),
                                            icon: const Icon(
                                              Icons.mic,
                                              size: 18,
                                            ),
                                            label: Text(
                                              s.addVoiceNote,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              side: BorderSide(
                                                color: context.brand.neutralGrey
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final picker = ImagePicker();
                                            final picked = await picker
                                                .pickImage(
                                                  source: ImageSource.gallery,
                                                  imageQuality: 60,
                                                  maxWidth: 800,
                                                  maxHeight: 800,
                                                );
                                            if (picked != null) {
                                              setDialogState(
                                                () => pendingNewImages.add(
                                                  picked,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.photo_camera,
                                            size: 18,
                                          ),
                                          label: Text(
                                            s.addPhotos,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            side: BorderSide(
                                              color: context.brand.neutralGrey
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSubject == null || contentController.text.isEmpty) {
                  return;
                }
                if (selectedType == 'project' && selectedDueDate == null) {
                  CustomSnackBar.show(
                    context: context,
                    message: s.pickDueDateForProject,
                    type: SnackBarType.error,
                  );
                  return;
                }
                // Snapshot synchronously (dialog disposal must not touch controllers).
                final subject = selectedSubject!;
                final contentText = contentController.text;
                final type = selectedType;
                final pickedDueDate = selectedDueDate;
                final imageFiles = List<XFile>.from(pendingNewImages);
                final voiceBytes = pendingVoiceBytes;

                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                try {
                  DateTime? dueDate = pickedDueDate;
                  if (type == 'daily') {
                    final resolved = await ref
                        .read(dashboardRepositoryProvider)
                        .getNextSubjectOccurrence(classId, subject);
                    dueDate = resolved ?? pickedDueDate;
                  }

                  final storageService = ref.read(storageServiceProvider);
                  final photoUrls = <String>[];
                  for (final xfile in imageFiles) {
                    final bytes = await xfile.readAsBytes();
                    var ext = xfile.name.contains('.')
                        ? xfile.name.split('.').last.toLowerCase()
                        : 'jpg';
                    if (ext == 'jpeg') ext = 'jpg';
                    if (!const {'jpg', 'png', 'webp', 'gif'}.contains(ext)) {
                      ext = 'jpg';
                    }
                    final url = await storageService.uploadImageBytes(
                      bytes,
                      'homework_images',
                      ext: ext,
                      ownerUid: userId,
                    );
                    photoUrls.add(url);
                  }

                  String? finalVoiceUrl;
                  if (voiceBytes != null) {
                    finalVoiceUrl = await storageService.uploadVoiceBytes(
                      voiceBytes,
                      'homework_voice',
                      ownerUid: userId,
                    );
                  }

                  final reminderActive = dueDate != null && reminderEnabled;
                  final DateTime? reminderTimeField;
                  if (reminderActive &&
                      (reminderClock.hour != 20 || reminderClock.minute != 0)) {
                    reminderTimeField = DateTime(
                      1970,
                      1,
                      1,
                      reminderClock.hour,
                      reminderClock.minute,
                    );
                  } else {
                    reminderTimeField = null;
                  }

                  final newPost = HomeworkPost(
                    postId: '',
                    classId: classId,
                    subject: subject,
                    content: contentText,
                    authorId: userId,
                    timestamp: DateTime.now(),
                    homeworkType: type,
                    dueDate: dueDate,
                    photoUrls: photoUrls,
                    voiceUrl: finalVoiceUrl,
                    reminderEnabled: reminderActive,
                    reminderTime: reminderTimeField,
                  );

                  final docId = await ref
                      .read(dashboardRepositoryProvider)
                      .createPersonalHomeworkEntry(userId, newPost);

                  ref.invalidate(deadlineProvider(classId));
                  ref.invalidate(calendarEventsProvider(classId));

                  if (hostContext.mounted) {
                    CustomSnackBar.show(
                      context: hostContext,
                      message: s.lang == 'el'
                          ? 'Η εργασία αποθηκεύτηκε'
                          : 'Homework saved',
                      type: SnackBarType.success,
                    );
                  }

                  try {
                    await ref
                        .read(dashboardRepositoryProvider)
                        .syncPersonalHomeworkDeadline(
                          userId,
                          docId,
                          newPost.copyWith(postId: docId),
                        );

                    if (dueDate != null) {
                      await NotificationService().scheduleHomeworkReminder(
                        homeworkId: docId,
                        dueDate: dueDate,
                        subject: subject,
                        content: contentText,
                        lang: lang,
                        reminderEnabled: newPost.reminderEnabled,
                        reminderTime: newPost.reminderTime,
                      );
                    }
                  } catch (e, st) {
                    debugPrint('Homework post-save sync skipped: $e\n$st');
                  }
                } catch (e, st) {
                  debugPrint('Add homework (post-dialog) failed: $e\n$st');
                  if (hostContext.mounted) {
                    CustomSnackBar.show(
                      context: hostContext,
                      message: FirebaseErrorHandler.getMessage(e, lang),
                      type: SnackBarType.error,
                    );
                  }
                }
              },
              child: Text(s.post),
            ),
          ],
        ),
      ),
    ).then((_) {
      contentController.dispose();
      ref.read(homeworkOcrControllerProvider.notifier).reset();
    });
  }
}

/// Cached author lookup via [userProvider]; avoids refetching on every list rebuild.
class _AuthorByline extends ConsumerWidget {
  final String authorId;
  final S s;

  const _AuthorByline({required this.authorId, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(userProvider(authorId));
    return authorAsync.when(
      data: (author) {
        final name = author?.fullName;
        final authorName = (name != null && name.isNotEmpty)
            ? name
            : (authorId.length > 5
                  ? '${authorId.substring(0, 5)}...'
                  : authorId);
        return Text(
          '${s.lang == 'el' ? 'Από' : 'By'} $authorName',
          style: Theme.of(context).textTheme.labelSmall,
        );
      },
      loading: () => const SizedBox(
        height: 12,
        width: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Text(
        '${s.lang == 'el' ? 'Από' : 'By'} ${authorId.length > 5 ? '${authorId.substring(0, 5)}...' : authorId}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

Future<void> _applyHomeworkCompletionState({
  required WidgetRef ref,
  required HomeworkPost post,
  required String uid,
  required bool completed,
}) async {
  await ref
      .read(dashboardRepositoryProvider)
      .toggleHomeworkCompletion(uid, post.postId, completed);
  final now = DateTime.now();
  final schoolYear = now.month >= 9
      ? '${now.year}-${now.year + 1}'
      : '${now.year - 1}-${now.year}';

  if (completed) {
    await ref
        .read(dashboardRepositoryProvider)
        .moveToHistory(uid, post, schoolYear, isCompleted: true);
    await NotificationService().cancelReminder(post.postId);
  }
}

class _HomeworkCard extends ConsumerWidget {
  final HomeworkPost post;
  final _HomeworkFeedUser user;
  final bool isCompleted;

  const _HomeworkCard({
    required this.post,
    required this.user,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(user.preferredLanguage);

    final card = GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 16,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Completion checkbox
              LiquidTouch(
                onTap: () async {
                  await _applyHomeworkCompletionState(
                    ref: ref,
                    post: post,
                    uid: user.uid,
                    completed: !isCompleted,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? context.brand.mintSuccess
                        : Colors.white.withValues(alpha: 0.3),
                    border: Border.all(
                      color: isCompleted
                          ? context.brand.mintSuccess
                          : context.brand.neutralGrey.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted ? context.brand.neutralGrey : null,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              UserProfileSheet(userId: post.authorId),
                        );
                      },
                      child: _AuthorByline(authorId: post.authorId, s: s),
                    ),
                  ],
                ),
              ),
              if (post.isVerified)
                Icon(Icons.verified, color: context.brand.mintSuccess),
              // Type badge
              _typeBadge(context, post.homeworkType, s),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: TextStyle(
              color: isCompleted ? context.brand.neutralGrey : null,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (post.dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: _isOverdue(post.dueDate!)
                      ? context.brand.errorRed
                      : context.brand.neutralGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.dueDate}: ${post.dueDate!.day}/${post.dueDate!.month}/${post.dueDate!.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isOverdue(post.dueDate!)
                        ? context.brand.errorRed
                        : context.brand.neutralGrey,
                    fontWeight: _isOverdue(post.dueDate!)
                        ? FontWeight.w600
                        : null,
                  ),
                ),
              ],
            ),
          ],
          // Attachment indicators
          if (post.voiceUrl != null || post.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (post.voiceUrl != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, size: 12, color: Colors.blue),
                        SizedBox(width: 2),
                        Text(
                          'Voice',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                if (post.photoUrls.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo, size: 12, color: Colors.green),
                        const SizedBox(width: 2),
                        Text(
                          '${post.photoUrls.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (post.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.photoUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isBase64DataUri(url)
                          ? Image.memory(
                              Uint8List.fromList(decodeBase64DataUri(url)),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Builder(
                              builder: (context) {
                                final px =
                                    (80 *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round();
                                return CachedNetworkImage(
                                  imageUrl: url,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  memCacheWidth: px,
                                  memCacheHeight: px,
                                  maxWidthDiskCache: px,
                                  maxHeightDiskCache: px,
                                  placeholder: (_, __) => Container(
                                    width: 80,
                                    height: 80,
                                    color: context.brand.neutralGrey.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: context.brand.neutralGrey.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 32,
                                      color: context.brand.neutralGrey,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (post.authorId != user.uid) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LiquidTouch(
                  onTap: () async {
                    await ref
                        .read(dashboardRepositoryProvider)
                        .verifyHomework(post.postId, user.uid);
                    ref.invalidate(homeworkStreamProvider(post.classId));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: post.isVerified
                          ? context.brand.mintSuccess.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: post.isVerified
                              ? context.brand.mintSuccess
                              : context.brand.neutralGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.verify} (${post.verificationCount})',
                          style: TextStyle(
                            color: post.isVerified
                                ? context.brand.mintSuccess
                                : context.brand.neutralGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                LiquidTouch(
                  onTap: () async {
                    await ref
                        .read(dashboardRepositoryProvider)
                        .flagHomework(post.postId);
                    if (context.mounted) {
                      CustomSnackBar.show(
                        context: context,
                        message: s.lang == 'el'
                            ? 'Αναφέρθηκε ως λανθασμένη.'
                            : 'Reported as incorrect.',
                        type: SnackBarType.warning,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.brand.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 20,
                          color: context.brand.errorRed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.lang == 'el' ? 'Σήμανση' : 'Flag',
                          style: TextStyle(
                            color: context.brand.errorRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LiquidTouch(
                  onTap: () => _showEditHomeworkDialog(context, ref, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.brand.royalLavender.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: context.brand.royalLavender,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.lang == 'el' ? 'Επεξεργασία' : 'Edit',
                          style: TextStyle(
                            color: context.brand.royalLavender,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _confirmDelete(context, ref, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.brand.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: context.brand.errorRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.lang == 'el' ? 'Διαγραφή' : 'Delete',
                            style: TextStyle(
                              color: context.brand.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Dismissible(
      key: ValueKey('homework_dismissible_${post.postId}'),
      direction: isCompleted
          ? DismissDirection.startToEnd
          : DismissDirection.endToStart,
      background: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.grey.shade700,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Icon(Icons.undo_rounded, color: Colors.white, size: 28),
        ),
      ),
      secondaryBackground: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xFF43A047),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _applyHomeworkCompletionState(
            ref: ref,
            post: post,
            uid: user.uid,
            completed: true,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Η εργασία ολοκληρώθηκε ✓'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: user.preferredLanguage == 'el' ? 'Αναίρεση' : 'Undo',
                    onPressed: () {
                      unawaited(
                        _applyHomeworkCompletionState(
                          ref: ref,
                          post: post,
                          uid: user.uid,
                          completed: false,
                        ),
                      );
                    },
                  ),
                ),
              );
          }
        } else if (direction == DismissDirection.startToEnd) {
          await _applyHomeworkCompletionState(
            ref: ref,
            post: post,
            uid: user.uid,
            completed: false,
          );
        }
        return false;
      },
      child: card,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, S s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.lang == 'el' ? 'Διαγραφή Εργασίας' : 'Delete Homework'),
        content: Text(
          s.lang == 'el'
              ? 'Είσαι σίγουρος ότι θέλεις να διαγράψεις αυτή την εργασία;'
              : 'Are you sure you want to delete this homework?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(dashboardRepositoryProvider)
                    .deletePersonalHomework(user.uid, post.postId);
                ref.invalidate(deadlineProvider(post.classId));
                ref.invalidate(calendarEventsProvider(post.classId));
                if (context.mounted) {
                  CustomSnackBar.show(
                    context: context,
                    message: s.homeworkDeleted,
                    type: SnackBarType.success,
                  );
                }
              } catch (e, st) {
                debugPrint('deletePersonalHomework failed: $e\n$st');
                if (context.mounted) {
                  CustomSnackBar.show(
                    context: context,
                    message: s.homeworkDeleteFailed,
                    type: SnackBarType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.errorRed,
            ),
            child: Text(
              s.lang == 'el' ? 'Διαγραφή' : 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditHomeworkDialog(BuildContext context, WidgetRef ref, S s) {
    String? selectedSubject = post.subject;
    String selectedType = _homeworkTypeUi(post.homeworkType);
    DateTime? selectedDueDate = post.dueDate;
    final contentController = TextEditingController(text: post.content);
    final List<String> existingImageUrls = List.from(
      post.photoUrls,
    ); // existing URLs
    final List<XFile> newImageFiles = []; // newly picked images
    bool showVoiceRecorder = false;
    String? existingVoiceUrl =
        post.voiceUrl; // existing voice URL from Firestore
    Uint8List? newVoiceBytes; // newly recorded voice bytes
    var reminderEnabled = post.dueDate != null && post.reminderEnabled;
    var reminderClock = post.reminderTime != null
        ? TimeOfDay(
            hour: post.reminderTime!.hour,
            minute: post.reminderTime!.minute,
          )
        : const TimeOfDay(hour: 20, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            s.lang == 'el' ? 'Επεξεργασία Εργασίας' : 'Edit Homework',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subject Picker
                InkWell(
                  onTap: () async {
                    final picked = await showSubjectPickerDialog(
                      context: context,
                      subjects: user.subjects,
                      title: s.selectSubject,
                      currentSubject: selectedSubject,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedSubject = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: s.subject,
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      selectedSubject ?? s.selectSubject,
                      style: TextStyle(
                        color: selectedSubject != null
                            ? Theme.of(context).colorScheme.onSurface
                            : context.brand.neutralGrey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Homework Type Picker
                InkWell(
                  onTap: () async {
                    final picked = await showTypePickerDialog(
                      context: context,
                      currentType: selectedType,
                      s: s,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedType = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: s.homeworkType,
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      selectedType == 'project'
                          ? s.projectHomework
                          : s.dailyHomework,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Due date: required for project, optional for daily.
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDueDate = picked);
                    }
                  },
                  onLongPress: selectedType == 'daily'
                      ? () => setDialogState(() => selectedDueDate = null)
                      : null,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: selectedType == 'project'
                          ? s.dueDateRequiredForProject
                          : s.dueDateOptional,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedDueDate != null &&
                              selectedType == 'daily')
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setDialogState(() => selectedDueDate = null),
                              visualDensity: VisualDensity.compact,
                            ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                      helperText: selectedType == 'project'
                          ? (s.lang == 'el'
                                ? 'Υποχρεωτική για project'
                                : 'Required for projects')
                          : (selectedDueDate == null
                                ? (s.lang == 'el' ? 'Προαιρετική' : 'Optional')
                                : null),
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: selectedType == 'project'
                            ? context.brand.errorRed.withValues(alpha: 0.85)
                            : context.brand.neutralGrey,
                      ),
                    ),
                    child: Text(
                      selectedDueDate != null
                          ? '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'
                          : (selectedType == 'project'
                                ? (s.lang == 'el'
                                      ? 'Πάτησε για επιλογή'
                                      : 'Tap to choose')
                                : (s.lang == 'el'
                                      ? 'Χωρίς ημερομηνία'
                                      : 'No due date')),
                      style: TextStyle(
                        color: selectedDueDate != null
                            ? Theme.of(context).colorScheme.onSurface
                            : (selectedType == 'project'
                                  ? context.brand.errorRed
                                  : context.brand.neutralGrey),
                        fontStyle: selectedDueDate == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (selectedDueDate != null) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.lang == 'el' ? 'Υπενθύμιση' : 'Reminder'),
                    subtitle: Text(
                      s.lang == 'el'
                          ? 'Την προηγούμενη βράδυ πριν την παράδοση'
                          : 'The evening before the due date',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.brand.neutralGrey,
                      ),
                    ),
                    value: reminderEnabled,
                    onChanged: (v) => setDialogState(() => reminderEnabled = v),
                  ),
                  if (reminderEnabled)
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: reminderClock,
                        );
                        if (t != null) {
                          setDialogState(() => reminderClock = t);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: s.lang == 'el'
                              ? 'Ώρα υπενθύμισης'
                              : 'Reminder time',
                        ),
                        child: Text(
                          reminderClock.format(context),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                // Content
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(labelText: s.homeworkContent),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Preview Row
                if (existingImageUrls.isNotEmpty ||
                    newImageFiles.isNotEmpty) ...[
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          existingImageUrls.length + newImageFiles.length,
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.image,
                              color: context.brand.neutralGrey,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => setDialogState(() {
                                if (i < existingImageUrls.length) {
                                  existingImageUrls.removeAt(i);
                                } else {
                                  newImageFiles.removeAt(
                                    i - existingImageUrls.length,
                                  );
                                }
                              }),
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: context.brand.errorRed,
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Attachment buttons
                if (showVoiceRecorder)
                  VoiceRecorderWidget(
                    onCancel: () =>
                        setDialogState(() => showVoiceRecorder = false),
                    onSend:
                        (
                          Uint8List bytes,
                          int durationMs,
                          List<double> amplitudes,
                        ) async {
                          setDialogState(() {
                            newVoiceBytes = bytes;
                            existingVoiceUrl =
                                null; // new recording replaces existing
                            showVoiceRecorder = false;
                          });
                        },
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (newVoiceBytes != null ||
                            (existingVoiceUrl != null &&
                                existingVoiceUrl!.isNotEmpty))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s.lang == 'el'
                                      ? 'Ηχητικό έτοιμο'
                                      : 'Voice note ready',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setDialogState(() {
                                    existingVoiceUrl = null;
                                    newVoiceBytes = null;
                                  }),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () =>
                                setDialogState(() => showVoiceRecorder = true),
                            icon: const Icon(Icons.mic, size: 18),
                            label: Text(
                              s.addVoiceNote,
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              side: BorderSide(
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 60,
                              maxWidth: 800,
                              maxHeight: 800,
                            );
                            if (picked != null) {
                              setDialogState(() => newImageFiles.add(picked));
                            }
                          },
                          icon: const Icon(Icons.photo_camera, size: 18),
                          label: Text(
                            s.addPhotos,
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            side: BorderSide(
                              color: context.brand.neutralGrey.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSubject != null &&
                    contentController.text.isNotEmpty) {
                  if (selectedType == 'project' && selectedDueDate == null) {
                    CustomSnackBar.show(
                      context: context,
                      message: s.pickDueDateForProject,
                      type: SnackBarType.error,
                    );
                    return;
                  }
                  DateTime? dueDate = selectedDueDate;
                  if (selectedType == 'daily') {
                    final resolved = await ref
                        .read(dashboardRepositoryProvider)
                        .getNextSubjectOccurrence(
                          user.classId,
                          selectedSubject!,
                        );
                    dueDate = resolved ?? selectedDueDate;
                  }

                  // Upload new images, keep existing URLs
                  final storageService = ref.read(storageServiceProvider);
                  final photoUrls = <String>[
                    ...existingImageUrls,
                  ]; // keep existing
                  for (final xfile in newImageFiles) {
                    final bytes = await xfile.readAsBytes();
                    final ext = xfile.name.split('.').last;
                    final url = await storageService.uploadImageBytes(
                      bytes,
                      'homework_images',
                      ext: ext,
                      ownerUid: user.uid,
                    );
                    photoUrls.add(url);
                  }

                  String? finalVoiceUrl;
                  if (newVoiceBytes != null) {
                    // New recording — upload it
                    finalVoiceUrl = await storageService.uploadVoiceBytes(
                      newVoiceBytes!,
                      'homework_voice',
                      ownerUid: user.uid,
                    );
                  } else if (existingVoiceUrl != null &&
                      existingVoiceUrl!.isNotEmpty) {
                    // Keep existing voice URL
                    finalVoiceUrl = existingVoiceUrl;
                  }

                  final reminderActive = dueDate != null && reminderEnabled;
                  final DateTime? reminderTimeField;
                  if (reminderActive &&
                      (reminderClock.hour != 20 || reminderClock.minute != 0)) {
                    reminderTimeField = DateTime(
                      1970,
                      1,
                      1,
                      reminderClock.hour,
                      reminderClock.minute,
                    );
                  } else {
                    reminderTimeField = null;
                  }

                  final updatedPost = post.copyWith(
                    subject: selectedSubject,
                    content: contentController.text,
                    homeworkType: selectedType,
                    dueDate: dueDate,
                    photoUrls: photoUrls,
                    voiceUrl:
                        finalVoiceUrl ??
                        '', // use '' to represent cleared voice
                    reminderEnabled: reminderActive,
                    reminderTime: reminderTimeField,
                    setReminderTime: true,
                  );

                  await ref
                      .read(dashboardRepositoryProvider)
                      .updatePersonalHomeworkEntry(user.uid, updatedPost);

                  await ref
                      .read(dashboardRepositoryProvider)
                      .syncPersonalHomeworkDeadline(
                        user.uid,
                        updatedPost.postId,
                        updatedPost,
                      );

                  if (dueDate != null) {
                    await NotificationService().scheduleHomeworkReminder(
                      homeworkId: updatedPost.postId,
                      dueDate: dueDate,
                      subject: selectedSubject!,
                      content: contentController.text,
                      lang: s.lang,
                      reminderEnabled: updatedPost.reminderEnabled,
                      reminderTime: updatedPost.reminderTime,
                    );
                  } else {
                    await NotificationService().cancelReminder(
                      updatedPost.postId,
                    );
                  }

                  ref.invalidate(deadlineProvider(post.classId));
                  ref.invalidate(calendarEventsProvider(post.classId));
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(s.lang == 'el' ? 'Αποθήκευση' : 'Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      contentController.dispose();
    });
  }

  bool _isOverdue(DateTime dueDate) {
    return isPastHomeworkFeedCutoff(dueDate);
  }

  Widget _typeBadge(BuildContext context, String type, S s) {
    final normalized = _homeworkTypeUi(type);
    final label = normalized == 'project' ? s.projectHomework : s.dailyHomework;
    final color = normalized == 'project'
        ? Colors.orange
        : context.brand.neutralGrey;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
