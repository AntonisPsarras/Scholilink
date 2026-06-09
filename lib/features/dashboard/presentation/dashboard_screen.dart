import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/data/auth_repository.dart';
import '../../exam_readiness/presentation/quiz_setup_screen.dart';
import '../../auth/domain/user_model.dart';
import '../../../shared/app_shell_insets.dart';
import '../data/dashboard_logic.dart';
import '../data/dashboard_repository.dart';
import '../data/homework_due_cutoff.dart';
import '../domain/exam_result_model.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/spark_counter_widget.dart';

import 'exam_tracker_screen.dart';
import '../../classroom/data/classroom_providers.dart';
import '../../messaging/presentation/widgets/friendship_tiles.dart';
import 'exam_results_screen.dart';
import 'event_calendar_widget.dart';
import 'moria_calculator_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/empty_state_shimmer.dart';
import '../../../shared/widgets/subject_chip.dart';
import '../../../shared/widgets/exam_readiness_widget.dart';
import '../domain/exam_model.dart';
import '../domain/homework_post_model.dart';
import 'dashboard_user_layout.dart';
import '../../../shared/responsive_layout.dart';

/// Narrow auth to fields that affect dashboard layout (excludes aiSparks churn, etc.).
Object _dashboardAuthSelect(AsyncValue<AppUser?> async) {
  if (async.isLoading) return const _DashGateLoading();
  if (async.hasError) return _DashGateError(async.error!);
  final u = async.valueOrNull;
  if (u == null) return const _DashGateLoggedOut();
  return DashboardUserLayout.fromUser(u);
}

@immutable
class _DashGateLoading {
  const _DashGateLoading();
  @override
  bool operator ==(Object other) => other is _DashGateLoading;
  @override
  int get hashCode => 1;
}

@immutable
class _DashGateLoggedOut {
  const _DashGateLoggedOut();
  @override
  bool operator ==(Object other) => other is _DashGateLoggedOut;
  @override
  int get hashCode => 2;
}

@immutable
class _DashGateError {
  final Object error;
  const _DashGateError(this.error);
  @override
  bool operator ==(Object other) =>
      other is _DashGateError && other.error == error;
  @override
  int get hashCode => Object.hash(3, error);
}

/// Dashboard screen — optimized with per-section Consumer widgets so that
/// each data stream only rebuilds its own section, not the entire dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(authStateProvider.select(_dashboardAuthSelect));
    final lang = ref.watch(userLanguageProvider);

    if (gate is _DashGateLoading) {
      return Center(child: Text(S(lang).loading));
    }
    if (gate is _DashGateError) {
      return Center(child: Text(S(lang).error));
    }
    if (gate is _DashGateLoggedOut) {
      return const Center(child: Text('Please log in'));
    }
    if (gate is DashboardUserLayout) {
      return _DashboardContent(layout: gate);
    }
    return const SizedBox.shrink();
  }
}

/// Greeting row (with sparks + bell) sits in one horizontal band so cross-axis
/// alignment matches [SparkCounterWidget] and [_NotificationBell]. Class line spans full width beneath.
class _DashboardHeaderTop extends StatelessWidget {
  const _DashboardHeaderTop({required this.s, required this.layout});

  final S s;
  final DashboardUserLayout layout;

  @override
  Widget build(BuildContext context) {
    final greetingStyle = Theme.of(context).textTheme.displayLarge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return SizedBox(
                    width: c.maxWidth,
                    height: 76,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${s.goodMorning}, ${layout.greetingFirstName}!',
                        style: greetingStyle,
                        maxLines: 2,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SparkCounterWidget(),
            const SizedBox(width: 8),
            _NotificationBell(s: s),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          layout.currentClass ?? '',
          style: TextStyle(color: context.brand.neutralGrey, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Core dashboard content — depends on [DashboardUserLayout] (stable fields only).
class _DashboardContent extends StatelessWidget {
  final DashboardUserLayout layout;
  const _DashboardContent({required this.layout});

  @override
  Widget build(BuildContext context) {
    final s = S(layout.preferredLanguage);
    final classId = layout.scheduleExamClassId;

    if (ResponsiveLayout.isDesktop(context)) {
      return _buildDesktopScaffold(context, s, classId);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // GREETING HEADER & NOTIFICATION BELL — static (no stream dependency)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                    child: _DashboardHeaderTop(s: s, layout: layout),
                  ),
                ),

                // READINESS GAUGE or SCHOOL CALENDAR — no stream dependency
                SliverToBoxAdapter(
                  child: layout.hasTakenSampleTest
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: GlassContainer(
                            animate: false,
                            padding: const EdgeInsets.all(24),
                            child: Builder(
                              builder: (context) {
                                final readiness =
                                    AbsenceLogic.calculateReadiness(
                                      layout.absences,
                                    );
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          s.readinessScore,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Tooltip(
                                          message: s.readinessTooltip,
                                          child: Icon(
                                            Icons.info_outline,
                                            color: context.brand.neutralGrey,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          height: 120,
                                          child: CircularProgressIndicator(
                                            value: readiness,
                                            strokeWidth: 10,
                                            backgroundColor: context
                                                .brand
                                                .neutralGrey
                                                .withValues(alpha: 0.2),
                                            color: AbsenceLogic.getAbsenceColor(
                                              layout.absences,
                                              context.brand,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(readiness * 100).round()}%',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${s.absences}: ${layout.absences}/${AbsenceLogic.maxAbsences}',
                                      style: TextStyle(
                                        color: context.brand.neutralGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        )
                      : EventCalendarWidget(classId: classId),
                ),

                SliverToBoxAdapter(
                  child: _TomorrowHomeworkPreview(classId: classId, s: s),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: ExamReadinessWidget(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TryExamReadinessPrompt(classId: classId, s: s),
                ),

                if (layout.subjects.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _SubjectsChips(
                      layout: layout,
                      classId: classId,
                      s: s,
                    ),
                  ),

                if (layout.showMoriaCalculator)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: LiquidTouch(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MoriaCalculatorScreen(),
                          ),
                        ),
                        child: GlassContainer(
                          animate: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          borderRadius: 20,
                          backgroundColor: context.brand.primaryPurple
                              .withValues(alpha: 0.1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: context.brand.primaryPurple
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.calculate_outlined,
                                      color: context.brand.primaryPurple,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    s.lang == 'el'
                                        ? 'Υπολογισμός Μορίων'
                                        : 'Panhellenic Calculator',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: context.brand.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: context.brand.primaryPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final examResultsAsync = ref.watch(examResultsProvider);
                      return examResultsAsync.when(
                        data: (results) => results.isEmpty
                            ? const SizedBox.shrink()
                            : _ExamResultsChart(results: results, s: s),
                        loading: () => const Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: SectionLoadingShimmer(height: 180),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),

                SliverToBoxAdapter(
                  child: _UpcomingExamsSection(classId: classId, s: s),
                ),

                SliverToBoxAdapter(
                  child: _HomeworkStreamSection(classId: classId, s: s),
                ),

                if (layout.classroomIds.length > 1)
                  SliverToBoxAdapter(
                    child: _SubjectFocusAlerts(
                      classroomIds: layout.classroomIds,
                      s: s,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: shellBottomContentPadding(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop-only: two-column layout that uses horizontal space instead of a
  /// single stretched column.
  Widget _buildDesktopScaffold(BuildContext context, S s, String classId) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left column: greeting, readiness/calendar, tomorrow homework, chips ──
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Greeting header — reduced top padding (no status-bar gap needed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
                            child: _DashboardHeaderTop(s: s, layout: layout),
                          ),
                          // Readiness gauge or event calendar
                          if (layout.hasTakenSampleTest)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
                              child: GlassContainer(
                                animate: false,
                                padding: const EdgeInsets.all(24),
                                child: Builder(
                                  builder: (ctx) {
                                    final readiness =
                                        AbsenceLogic.calculateReadiness(
                                          layout.absences,
                                        );
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              s.readinessScore,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Tooltip(
                                              message: s.readinessTooltip,
                                              child: Icon(
                                                Icons.info_outline,
                                                color:
                                                    context.brand.neutralGrey,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 120,
                                              height: 120,
                                              child: CircularProgressIndicator(
                                                value: readiness,
                                                strokeWidth: 10,
                                                backgroundColor: context
                                                    .brand
                                                    .neutralGrey
                                                    .withValues(alpha: 0.2),
                                                color:
                                                    AbsenceLogic.getAbsenceColor(
                                                      layout.absences,
                                                      context.brand,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              '${(readiness * 100).round()}%',
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${s.absences}: ${layout.absences}/${AbsenceLogic.maxAbsences}',
                                          style: TextStyle(
                                            color: context.brand.neutralGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            EventCalendarWidget(classId: classId),
                          // Tomorrow's homework preview
                          _TomorrowHomeworkPreview(classId: classId, s: s),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 12, 0),
                            child: ExamReadinessWidget(),
                          ),
                          _TryExamReadinessPrompt(classId: classId, s: s),
                          // Subject chips
                          if (layout.subjects.isNotEmpty)
                            _SubjectsChips(
                              layout: layout,
                              classId: classId,
                              s: s,
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ── Right column: moria promo, chart, exams, homework, alerts ──
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top gap matches left column greeting height visually
                          const SizedBox(height: 24),
                          // Moria calculator promo (Γ' Λυκείου only)
                          if (layout.showMoriaCalculator)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 20, 0),
                              child: LiquidTouch(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MoriaCalculatorScreen(),
                                  ),
                                ),
                                child: GlassContainer(
                                  animate: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  borderRadius: 20,
                                  backgroundColor: context.brand.primaryPurple
                                      .withValues(alpha: 0.1),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: context.brand.primaryPurple
                                                  .withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.calculate_outlined,
                                              color:
                                                  context.brand.primaryPurple,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            s.lang == 'el'
                                                ? 'Υπολογισμός Μορίων'
                                                : 'Panhellenic Calculator',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color:
                                                  context.brand.primaryPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: context.brand.primaryPurple,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Exam results chart
                          Consumer(
                            builder: (context, ref, _) {
                              final examResultsAsync = ref.watch(
                                examResultsProvider,
                              );
                              return examResultsAsync.when(
                                data: (results) => results.isEmpty
                                    ? const SizedBox.shrink()
                                    : _ExamResultsChart(results: results, s: s),
                                loading: () => const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 20, 20, 0),
                                  child: SectionLoadingShimmer(height: 180),
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                          // Upcoming exams
                          _UpcomingExamsSection(classId: classId, s: s),
                          // Homework stream (desktop-safe bottom padding)
                          _HomeworkStreamSection(classId: classId, s: s),
                          // Subject focus alerts (tutoring + school conflict)
                          if (layout.classroomIds.length > 1)
                            _SubjectFocusAlerts(
                              classroomIds: layout.classroomIds,
                              s: s,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Notification Bell ---
class _NotificationBell extends ConsumerStatefulWidget {
  final S s;
  const _NotificationBell({required this.s});

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _isOpen = false;

  Color _panelColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
  }

  Future<void> _openMenu() async {
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !mounted) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final btnSize = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final pendingUids = ref.read(pendingFriendRequestUidsProvider);
    final pendingCount = pendingUids.length;
    final s = widget.s;

    setState(() => _isOpen = true);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogCtx) => SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: offset.dy + btnSize.height + 6,
              right: screenWidth - (offset.dx + btnSize.width),
              child: Material(
                color: _panelColor(dialogCtx),
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                    maxHeight: 360,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _panelColor(dialogCtx),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(
                          dialogCtx,
                        ).colorScheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 18,
                                color: Theme.of(
                                  dialogCtx,
                                ).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.lang == 'el'
                                      ? 'Ειδοποιήσεις'
                                      : 'Notifications',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(
                                      dialogCtx,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Theme.of(
                                    dialogCtx,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => Navigator.pop(dialogCtx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(
                            dialogCtx,
                          ).colorScheme.outline.withValues(alpha: 0.25),
                        ),
                        if (pendingCount > 0)
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: pendingUids
                                  .map(
                                    (uid) => PendingRequestTile(
                                      key: ValueKey(uid),
                                      senderUid: uid,
                                      lang: s.lang,
                                      compact: true,
                                    ),
                                  )
                                  .toList(),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 20,
                                  color: Theme.of(
                                    dialogCtx,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.lang == 'el'
                                        ? 'Δεν υπάρχουν νέες ειδοποιήσεις'
                                        : 'No new notifications',
                                    style: TextStyle(
                                      color: Theme.of(
                                        dialogCtx,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final pendingUids = ref.watch(pendingFriendRequestUidsProvider);
    final pendingCount = pendingUids.length;

    return LiquidTouch(
      onTap: _openMenu,
      child: GlassContainer(
        key: _anchorKey,
        animate: false,
        width: 44,
        height: 44,
        borderRadius: 22,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.5),
        blur: 10,
        child: Center(
          child: Badge(
            isLabelVisible: pendingCount > 0,
            label: Text(pendingCount.toString()),
            child: Icon(
              _isOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Subjects Chips (scoped ConsumerWidget for homework data on long-press) ---
class _SubjectsChips extends ConsumerWidget {
  final DashboardUserLayout layout;
  final String classId;
  final S s;

  const _SubjectsChips({
    required this.layout,
    required this.classId,
    required this.s,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.mySubjects,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: layout.subjects.take(8).map<Widget>((sub) {
              return SubjectChip(
                subject: sub,
                onLongPress: () {
                  final allHomework =
                      ref.read(homeworkStreamProvider(classId)).value ?? [];
                  final completedIds =
                      ref.read(completedHomeworkIdsProvider).valueOrNull ?? {};

                  final subjectHomework = allHomework
                      .where(
                        (hw) =>
                            hw.subject == sub &&
                            !completedIds.contains(hw.postId),
                      )
                      .toList();

                  if (subjectHomework.isNotEmpty) {
                    subjectHomework.sort((a, b) {
                      if (a.dueDate == null && b.dueDate == null) return 0;
                      if (a.dueDate == null) return 1;
                      if (b.dueDate == null) return -1;
                      return a.dueDate!.compareTo(b.dueDate!);
                    });

                    final nextHw = subjectHomework.first;

                    showDialog(
                      context: context,
                      builder: (dialogCtx) {
                        final dlgCs = Theme.of(dialogCtx).colorScheme;
                        return AlertDialog(
                          backgroundColor: dlgCs.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: dlgCs.outline.withValues(alpha: 0.35),
                            ),
                          ),
                          title: Text(
                            '$sub - ${s.lang == 'el' ? 'Επόμενη Εργασία' : 'Next Homework'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: dlgCs.onSurface,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.assignment,
                                color: context.brand.royalLavender,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                nextHw.content,
                                style: TextStyle(color: dlgCs.onSurface),
                              ),
                              if (nextHw.dueDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${s.dueDate}: ${nextHw.dueDate!.day}/${nextHw.dueDate!.month}/${nextHw.dueDate!.year}',
                                  style: TextStyle(
                                    color: dlgCs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                s.lang == 'el' ? 'Κλείσιμο' : 'Close',
                                style: TextStyle(color: dlgCs.primary),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    CustomSnackBar.show(
                      context: context,
                      message: s.lang == 'el'
                          ? 'Δεν υπάρχουν εκκρεμείς εργασίες'
                          : 'No pending homework',
                      type: SnackBarType.info,
                    );
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TryExamReadinessPrompt extends ConsumerWidget {
  const _TryExamReadinessPrompt({required this.classId, required this.s});

  final String classId;
  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examProvider(classId));
    return examsAsync.when(
      data: (exams) {
        final now = DateTime.now();
        final examSoon = exams.where((exam) {
          final days = exam.date.difference(now).inDays;
          return days >= 0 && days < 3;
        }).toList()..sort((a, b) => a.date.compareTo(b.date));
        if (examSoon.isEmpty) return const SizedBox.shrink();

        final nextExam = examSoon.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: GlassContainer(
            animate: false,
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: context.brand.primaryPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.lang == 'el'
                        ? 'Η εξέταση ${nextExam.subject} είναι σε λιγότερο από 3 ημέρες. '
                              'Κάνε ένα τεστ ετοιμότητας τώρα.'
                        : 'The ${nextExam.subject} exam is in less than 3 days. '
                              'Take a readiness test now.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizSetupScreen(
                          subjectName: nextExam.subject,
                          examReference: nextExam.id,
                        ),
                      ),
                    );
                  },
                  child: Text(s.lang == 'el' ? 'Κάνε τεστ' : 'Take test'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// --- Upcoming Exams Section (scoped Consumer) ---
class _UpcomingExamsSection extends ConsumerWidget {
  final String classId;
  final S s;

  const _UpcomingExamsSection({required this.classId, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examProvider(classId));

    return examsAsync.when(
      data: (exams) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.upcomingExams,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  LiquidTouch(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExamTrackerScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add,
                            size: 18,
                            color: context.brand.darkText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.addExam,
                            style: TextStyle(
                              color: context.brand.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (exams.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EmptyStateWidget(
                      icon: Icons.event_note_outlined,
                      title: s.lang == 'el' ? 'Καμία Εξέταση' : 'No Exams',
                      message: s.lang == 'el'
                          ? 'Δεν υπάρχουν προγραμματισμένες εξετάσεις για την τάξη σου.'
                          : 'No upcoming exams scheduled for your class.',
                      action: LiquidTouch(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExamTrackerScreen(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: context.brand.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s.addExam,
                            style: TextStyle(
                              color: context.brand.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ...exams
                    .take(3)
                    .map(
                      (exam) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GlassContainer(
                          animate: false,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(
                            8,
                          ), // Increased from 4 for better readability
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.quiz,
                                color: context.brand.darkText.withValues(
                                  alpha: 0.8,
                                ),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              exam.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${exam.date.day}/${exam.date.month}/${exam.date.year}${exam.description.isNotEmpty ? ' • ${exam.description}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QuizSetupScreen(
                                      subjectName: exam.subject,
                                      examReference: exam.id,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                s.lang == 'el' ? 'Κάνε τεστ' : 'Take test',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: SectionLoadingShimmer(height: 120),
      ),
      error: (err, _) => const SizedBox.shrink(),
    );
  }
}

// --- Homework Stream Section (scoped Consumer) ---
class _HomeworkStreamSection extends ConsumerWidget {
  final String classId;
  final S s;

  const _HomeworkStreamSection({required this.classId, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworkAsync = ref.watch(personalHomeworkProvider);
    final completedIds =
        ref.watch(completedHomeworkIdsProvider).valueOrNull ?? {};

    return homeworkAsync.when(
      data: (homework) {
        // Filter out completed and overdue homework from the dashboard preview
        final now = DateTime.now();
        final pendingHomework = homework.where((hw) {
          if (completedIds.contains(hw.postId)) return false;
          if (hw.dueDate != null) {
            if (isPastHomeworkFeedCutoff(hw.dueDate!, now)) return false;
          }
          return true;
        }).toList();

        final bottomPad = ResponsiveLayout.isDesktop(context) ? 24.0 : 120.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.homeworkStream,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (pendingHomework.isNotEmpty)
                    LiquidTouch(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          s.viewAll,
                          style: TextStyle(
                            color: context.brand.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (pendingHomework.isEmpty)
                EmptyStateWidget(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: context.brand.mintSuccess,
                  title: s.lang == 'el' ? 'Όλα Τέλεια!' : 'All Caught Up!',
                  message: s.noHomeworkTomorrow,
                )
              else
                ...pendingHomework
                    .take(3)
                    .map(
                      (hw) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GlassContainer(
                          animate: false,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(
                            8,
                          ), // Increased from 4 for better readability
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hw.isVerified
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hw.isVerified ? Icons.check : Icons.assignment,
                                color: hw.isVerified
                                    ? context.brand.darkText
                                    : context.brand.neutralGrey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              hw.subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              hw.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          ResponsiveLayout.isDesktop(context) ? 24.0 : 120.0,
        ),
        child: const SectionLoadingShimmer(height: 150),
      ),
      error: (err, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          ResponsiveLayout.isDesktop(context) ? 24.0 : 120.0,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: context.brand.errorRed,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                s.error,
                style: TextStyle(
                  color: context.brand.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                s.lang == 'el'
                    ? 'Αδυναμία φόρτωσης εργασιών'
                    : 'Could not load homework',
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Exam Results Progress Chart ---
class _ExamResultsChart extends StatelessWidget {
  final List<ExamResult> results;
  final S s;

  const _ExamResultsChart({required this.results, required this.s});

  @override
  Widget build(BuildContext context) {
    // Sort by date chronologically
    final sorted = List<ExamResult>.from(results)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Filter to last 3 months
    final now = DateTime.now();
    final threeMonthsAgo = now.subtract(const Duration(days: 90));
    var chartResults = sorted
        .where((r) => r.date.isAfter(threeMonthsAgo))
        .toList();

    // Fallback if not enough data in the last 3 months
    if (chartResults.length < 2) {
      chartResults = sorted.length > 3
          ? sorted.sublist(sorted.length - 3)
          : sorted;
    }

    if (chartResults.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassContainer(
        animate: false,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.lang == 'el'
                        ? 'Πρόοδος Τεστ/Εξετάσεων'
                        : 'Test & Exam Results',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.fullscreen,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        // Calculate proper chart width based on time span
                        double timeSpanDays = sorted.isNotEmpty
                            ? sorted.last.date
                                  .difference(sorted.first.date)
                                  .inDays
                                  .toDouble()
                            : 0.0;

                        // Allocating 30px per day preserves spacing correctly
                        double chartWidth = timeSpanDays * 30.0;
                        if (chartWidth <
                            MediaQuery.of(context).size.width - 80) {
                          chartWidth = MediaQuery.of(context).size.width - 80;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.black.withValues(alpha: 0.45)
                              : null,
                          builder: (dialogCtx) {
                            final cs = Theme.of(dialogCtx).colorScheme;
                            final light =
                                Theme.of(dialogCtx).brightness ==
                                Brightness.light;
                            final surface = light
                                ? const Color(0xFFFFFFFF)
                                : cs.surface;
                            return Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(16),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                constraints: const BoxConstraints(
                                  maxWidth: 800,
                                ),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: cs.outline.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.lang == 'el'
                                                ? 'Πρόοδος Τεστ/Εξετάσεων'
                                                : 'Test & Exam Results',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color: cs.onSurface,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: chartWidth,
                                        height:
                                            MediaQuery.of(
                                              dialogCtx,
                                            ).size.height *
                                            0.5,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 20,
                                          ),
                                          child: LineChart(
                                            _buildLineChartData(
                                              sorted,
                                              dialogCtx,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s.lang == 'el'
                                          ? 'Πατήστε στις τελείες για λεπτομέρειες (Σύρετε για περισσότερα)'
                                          : 'Tap on points for details (Scroll for more)',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    LiquidTouch(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExamResultsScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                    .withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Theme.of(context).brightness == Brightness.dark
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: Text(
                          s.viewAll,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Main fixed screen height widget
            SizedBox(
              height: 180,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: RepaintBoundary(
                  child: LineChart(_buildLineChartData(chartResults, context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(
    List<ExamResult> examList,
    BuildContext context,
  ) {
    if (examList.isEmpty) return LineChartData();

    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final axisLabelColor = dark
        ? cs.onSurface.withValues(alpha: 0.72)
        : context.brand.neutralGrey;
    final lineColor = dark
        ? cs.primary.withValues(alpha: 0.85)
        : context.brand.darkText.withValues(alpha: 0.5);

    // Normalize dates using midnight
    final firstDateRaw = examList.first.date;
    final firstD = DateTime(
      firstDateRaw.year,
      firstDateRaw.month,
      firstDateRaw.day,
    );

    final spots = <FlSpot>[];
    final Map<double, ExamResult> spotMeta = {};

    final occupiedX = <double>{};
    for (var r in examList) {
      final currentD = DateTime(r.date.year, r.date.month, r.date.day);
      double xVar = currentD.difference(firstD).inDays.toDouble();

      while (occupiedX.contains(xVar)) {
        xVar += 0.2;
      }
      occupiedX.add(xVar);
      spots.add(FlSpot(xVar, r.score.clamp(0.0, 20.0)));
      spotMeta[xVar] = r;
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    final minX = spots.first.x;
    final maxX = spots.last.x;
    final span = (maxX - minX).abs();
    final bottomInterval = span <= 7
        ? 1.0
        : math.max(1.0, (span / 6).ceilToDouble());

    return LineChartData(
      minY: 0,
      maxY: 20,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (value) => FlLine(
          color: dark
              ? cs.outline.withValues(alpha: 0.35)
              : context.brand.neutralGrey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final rel = value - minX;
              final steps = rel / bottomInterval;
              if ((steps - steps.round()).abs() > 0.02) {
                return const SizedBox.shrink();
              }
              final d = firstD.add(Duration(days: value.round()));
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${d.day}/${d.month}',
                  style: TextStyle(fontSize: 10, color: axisLabelColor),
                ),
              );
            },
            reservedSize: 30,
            interval: bottomInterval,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 5,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  color: axisLabelColor,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => dark
              ? cs.surfaceContainerHighest
              : Colors.white.withValues(alpha: 0.95),
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((FlSpot spot) {
              final result = spotMeta[spot.x];
              if (result == null) return null;

              final dateStr =
                  '${result.date.day}/${result.date.month}/${result.date.year}';
              final subColor = dark ? cs.primary : context.brand.primaryPurple;
              final metaColor = dark
                  ? cs.onSurfaceVariant
                  : context.brand.neutralGrey;
              final scoreColor = dark ? cs.onSurface : context.brand.darkText;
              return LineTooltipItem(
                '${result.subject}\n',
                TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$dateStr\n',
                    style: TextStyle(
                      color: metaColor,
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: 'Βαθμός: ${result.score}',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: lineColor,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: dark ? cs.surface : Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: lineColor,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: dark
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

// --- Tomorrow's Homework Preview ---
class _TomorrowHomeworkPreview extends ConsumerWidget {
  final String classId;
  final S s;

  const _TomorrowHomeworkPreview({required this.classId, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tomorrowAsync = ref.watch(personalHomeworkDueTomorrowProvider);
    final completedIdsAsync = ref.watch(completedHomeworkIdsProvider);

    return tomorrowAsync.when(
      data: (homework) {
        if (homework.isEmpty) return const SizedBox.shrink();

        final completedIds = completedIdsAsync.valueOrNull ?? {};

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: GlassContainer(
            animate: false,
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: context.brand.darkText.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.tomorrowHomework,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...homework.map((hw) {
                  final isCompleted = completedIds.contains(hw.postId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final user = ref.read(authStateProvider).value;
                            if (user != null) {
                              await ref
                                  .read(dashboardRepositoryProvider)
                                  .toggleHomeworkCompletion(
                                    user.uid,
                                    hw.postId,
                                    !isCompleted,
                                  );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? context.brand.mintSuccess
                                  : Colors.transparent,
                              border: Border.all(
                                color: isCompleted
                                    ? context.brand.mintSuccess
                                    : context.brand.neutralGrey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hw.subject,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? context.brand.neutralGrey
                                      : null,
                                ),
                              ),
                              Text(
                                hw.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isCompleted
                                      ? context.brand.neutralGrey
                                      : context.brand.neutralGrey,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// --- Subject Focus Alerts ---
class _SubjectFocusAlerts extends ConsumerWidget {
  final List<String> classroomIds;
  final S s;

  const _SubjectFocusAlerts({required this.classroomIds, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classroomIds.length < 2) return const SizedBox.shrink();

    final schoolId = classroomIds[0];
    final tutorId = classroomIds[1];

    final schoolExamsAsync = ref.watch(examProvider(schoolId));
    final tutorHomeworkAsync = ref.watch(homeworkStreamProvider(tutorId));

    return schoolExamsAsync.when(
      data: (exams) {
        return tutorHomeworkAsync.when(
          data: (homework) {
            final conflicts = _findConflicts(exams, homework);
            if (conflicts.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: GlassContainer(
                animate: false,
                backgroundColor: context.brand.sunsetWarning.withValues(
                  alpha: 0.1,
                ),
                border: Border.all(
                  color: context.brand.sunsetWarning.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: context.brand.sunsetWarning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.subjectFocusAlert,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.brand.sunsetWarning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.conflictWarning,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ...conflicts.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${c.subject} (${c.date.day}/${c.date.month})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<_Conflict> _findConflicts(
    List<Exam> exams,
    List<HomeworkPost> homework,
  ) {
    final hwDaySubject = <String>{};
    for (final hw in homework) {
      if (hw.dueDate == null) continue;
      hwDaySubject.add(
        '${hw.dueDate!.year}-${hw.dueDate!.month}-${hw.dueDate!.day}|${hw.subject.toLowerCase()}',
      );
    }
    final conflicts = <_Conflict>[];
    for (final exam in exams) {
      final k =
          '${exam.date.year}-${exam.date.month}-${exam.date.day}|${exam.subject.toLowerCase()}';
      if (hwDaySubject.contains(k)) {
        conflicts.add(_Conflict(subject: exam.subject, date: exam.date));
      }
    }
    return conflicts;
  }
}

class _Conflict {
  final String subject;
  final DateTime date;
  _Conflict({required this.subject, required this.date});
}
