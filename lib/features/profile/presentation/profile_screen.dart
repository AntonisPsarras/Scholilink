import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/social_callables.dart';
import '../../dashboard/presentation/add_grades_screen.dart';
import 'settings_screen.dart';
import 'manage_subjects_screen.dart';
import 'manage_tutoring_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/l10n.dart';
import '../../dashboard/data/dashboard_logic.dart';
import '../../dashboard/data/subject_grading_data.dart';
import '../../dashboard/domain/grade_model.dart';
import '../../dashboard/utils/grade_calculator.dart';
import '../../../shared/spark_counter_widget.dart';
import 'upgrade_pro_screen.dart';
import 'edit_profile_screen.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/subject_chip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final lang = ref.watch(userLanguageProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please log in')));
        }

        final gradesAsync = ref.watch(gradesProvider);
        final s = S(user.preferredLanguage);
        final grades = gradesAsync.value ?? [];
        // Use memoized provider — avoids re-running O(grades) calculations on
        // every build triggered by unrelated auth or UI state changes.
        final gradeStats = ref.watch(_profileGradeStatsProvider);
        final double overallAverage = gradeStats.average;
        final List<FlSpot> sparklineSpots = gradeStats.spots;
        final bool isProPlan =
            user.subscriptionType.toLowerCase().trim() == 'pro';

        return Scaffold(
          backgroundColor: Colors.transparent, // Allow global gradient
          appBar: AppBar(
            title: Text(
              s.myProfile,
              style: TextStyle(
                color: context.brand.darkText,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: context.brand.darkText),
            actions: [
              const Center(child: SparkCounterWidget()),
              // Edit profile button (first for easier reach)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: context.brand.darkText.withValues(alpha: 0.8),
                ),
                tooltip: s.editProfile,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: user),
                  ),
                ),
              ),
              // Settings button
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: context.brand.darkText.withValues(alpha: 0.8),
                ),
                tooltip: s.settings,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return _buildDesktopBody(
                  context,
                  ref,
                  user,
                  grades,
                  overallAverage,
                  sparklineSpots,
                  s,
                  isProPlan,
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileHeader(context, user, s),
                    const SizedBox(height: 24),

                    if (!isProPlan) ...[
                      // Go PRO Banner (hidden for ScholiLink Pro subscribers)
                      LiquidTouch(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UpgradeProScreen(),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.brand.royalLavender,
                                const Color(0xFFB1A2FB),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: context.brand.royalLavender.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ScholiLink Pro',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Αναβάθμισε για 500 AI Sparks/μέρα & Stats',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Stat cards grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio:
                          0.9, // Slightly taller than wide to fit long class names
                      children: [
                        _buildStatCard(
                          context,
                          s.grade,
                          user.currentClass ?? '-',
                          Icons.school,
                          onTap: () =>
                              _showChangeGradeDialog(context, ref, user, s),
                        ),
                        _buildStatCard(
                          context,
                          s.subjects,
                          '${user.subjects.length}',
                          Icons.menu_book,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageSubjectsScreen(),
                            ),
                          ),
                        ),
                        _buildStatCard(
                          context,
                          s.absences,
                          '${user.absences}',
                          Icons.event_busy,
                          onTap: () =>
                              _showAbsencesDialog(context, ref, user, s),
                        ),
                        _buildStatCard(
                          context,
                          s.tutoring,
                          user.hasTutoring
                              ? '${user.tutoringSubjects.length}'
                              : '0',
                          Icons.star,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageTutoringScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action cards: Grades, Exam Results, Settings
                    LiquidTouch(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddGradesScreen(),
                        ),
                      ),
                      child: GlassContainer(
                        width: double.infinity,
                        borderRadius: 20,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.myGrades,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: context.brand.darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.lang == 'el'
                                          ? 'Βαθμοί Τετραμήνων & Τελικές Εξετάσεις'
                                          : 'Term & Final Exam Grades',
                                      style: TextStyle(
                                        color: context.brand.neutralGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: context.brand.neutralGrey.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (grades.isNotEmpty)
                              Row(
                                children: [
                                  // Circular Progress
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: overallAverage > 0
                                              ? (overallAverage / 20.0)
                                              : 0,
                                          strokeWidth: 8,
                                          backgroundColor: context
                                              .brand
                                              .neutralGrey
                                              .withValues(alpha: 0.2),
                                          color: context.brand.royalLavender,
                                          strokeCap: StrokeCap.round,
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              overallAverage > 0
                                                  ? overallAverage
                                                        .toStringAsFixed(1)
                                                  : '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            Text(
                                              '/20',
                                              style: TextStyle(
                                                color:
                                                    context.brand.neutralGrey,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Sparkline
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: SizedBox(
                                        height: 60,
                                        child: LineChart(
                                          LineChartData(
                                            minY: 10,
                                            maxY: 20,
                                            gridData: const FlGridData(
                                              show: false,
                                            ),
                                            titlesData: const FlTitlesData(
                                              show: false,
                                            ),
                                            borderData: FlBorderData(show: false),
                                            lineTouchData: const LineTouchData(
                                              enabled: false,
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: sparklineSpots,
                                                isCurved: true,
                                                color: context.brand.mintSuccess,
                                                barWidth: 3,
                                                isStrokeCapRound: true,
                                                dotData: const FlDotData(
                                                  show: false,
                                                ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      context.brand.mintSuccess
                                                          .withValues(alpha: 0.3),
                                                      context.brand.mintSuccess
                                                          .withValues(alpha: 0.0),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  s.noGradesYet,
                                  style: TextStyle(
                                    color: context.brand.neutralGrey,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildActionCard(
                      context,
                      icon: Icons.settings_outlined,
                      color: context.brand.darkText.withValues(alpha: 0.8),
                      title: s.settings,
                      subtitle: s.lang == 'el'
                          ? 'Αυτόματες εργασίες, μαθήματα'
                          : 'Auto-homework, subjects',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Subjects section
                    if (user.subjects.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          s.mySubjects,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: context.brand.darkText,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.subjects.map<Widget>((subject) {
                          final bool isFinal =
                              user.currentClass != null &&
                              SubjectGradingData.hasFinalExam(
                                subject,
                                user.currentClass!,
                              );
                          return SubjectChip(
                            subject: subject,
                            isFinalExam: isFinal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.lang == 'el'
                            ? '* Τελικές Εξετάσεις'
                            : '* Final Exams Subject',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.brand.neutralGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => Scaffold(body: Center(child: Text(S(lang).loading))),
      error: (err, _) => Scaffold(body: Center(child: Text(S(lang).error))),
    );
  }

  /// Desktop-only: profile header on the left, stats/grades/settings on the right.
  Widget _buildDesktopBody(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    List grades,
    double overallAverage,
    List sparklineSpots,
    S s,
    bool isProPlan,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Two-panel top row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left panel: avatar + name + email + pro banner
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildProfileHeader(context, user, s),
                    const SizedBox(height: 20),
                    if (!isProPlan)
                      LiquidTouch(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UpgradeProScreen(),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.brand.royalLavender,
                                const Color(0xFFB1A2FB),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: context.brand.royalLavender.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ScholiLink Pro',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Αναβάθμισε για 500 AI Sparks/μέρα & Stats',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right panel: 4-col stats + grades card + settings
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2-column stat grid (desktop right panel is ~460px, 4-col was too cramped)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _buildStatCard(
                          context,
                          s.grade,
                          user.currentClass ?? '-',
                          Icons.school,
                          onTap: () =>
                              _showChangeGradeDialog(context, ref, user, s),
                        ),
                        _buildStatCard(
                          context,
                          s.subjects,
                          '${user.subjects.length}',
                          Icons.menu_book,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageSubjectsScreen(),
                            ),
                          ),
                        ),
                        _buildStatCard(
                          context,
                          s.absences,
                          '${user.absences}',
                          Icons.event_busy,
                          onTap: () =>
                              _showAbsencesDialog(context, ref, user, s),
                        ),
                        _buildStatCard(
                          context,
                          s.tutoring,
                          user.hasTutoring
                              ? '${user.tutoringSubjects.length}'
                              : '0',
                          Icons.star,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageTutoringScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Grades card
                    LiquidTouch(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddGradesScreen(),
                        ),
                      ),
                      child: GlassContainer(
                        width: double.infinity,
                        borderRadius: 20,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.myGrades,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: context.brand.darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.lang == 'el'
                                          ? 'Βαθμοί Τετραμήνων & Τελικές Εξετάσεις'
                                          : 'Term & Final Exam Grades',
                                      style: TextStyle(
                                        color: context.brand.neutralGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: context.brand.neutralGrey.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (grades.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: overallAverage > 0
                                              ? (overallAverage / 20.0)
                                              : 0,
                                          strokeWidth: 7,
                                          backgroundColor: context
                                              .brand
                                              .neutralGrey
                                              .withValues(alpha: 0.2),
                                          color: context.brand.royalLavender,
                                          strokeCap: StrokeCap.round,
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              overallAverage > 0
                                                  ? overallAverage
                                                        .toStringAsFixed(1)
                                                  : '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                              ),
                                            ),
                                            Text(
                                              '/20',
                                              style: TextStyle(
                                                color:
                                                    context.brand.neutralGrey,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: SizedBox(
                                        height: 50,
                                        child: LineChart(
                                          LineChartData(
                                            minY: 10,
                                            maxY: 20,
                                            gridData: const FlGridData(
                                              show: false,
                                            ),
                                            titlesData: const FlTitlesData(
                                              show: false,
                                            ),
                                            borderData: FlBorderData(show: false),
                                            lineTouchData: const LineTouchData(
                                              enabled: false,
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: sparklineSpots
                                                    .cast<FlSpot>(),
                                                isCurved: true,
                                                color: context.brand.mintSuccess,
                                                barWidth: 2.5,
                                                isStrokeCapRound: true,
                                                dotData: const FlDotData(
                                                  show: false,
                                                ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      context.brand.mintSuccess
                                                          .withValues(alpha: 0.3),
                                                      context.brand.mintSuccess
                                                          .withValues(alpha: 0.0),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
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
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Settings action card
                    _buildActionCard(
                      context,
                      icon: Icons.settings_outlined,
                      color: context.brand.darkText.withValues(alpha: 0.8),
                      title: s.settings,
                      subtitle: s.lang == 'el'
                          ? 'Αυτόματες εργασίες, μαθήματα'
                          : 'Auto-homework, subjects',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Subjects — full width ──
          if (user.subjects.isNotEmpty) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.mySubjects,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.brand.darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.subjects.map<Widget>((subject) {
                final bool isFinal =
                    user.currentClass != null &&
                    SubjectGradingData.hasFinalExam(
                      subject,
                      user.currentClass!,
                    );
                return SubjectChip(
                  subject: subject,
                  isFinalExam: isFinal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              s.lang == 'el' ? '* Τελικές Εξετάσεις' : '* Final Exams Subject',
              style: TextStyle(
                fontSize: 11,
                color: context.brand.neutralGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic user, S s) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: UserAvatar(
            profilePictureUrl: user.profilePictureUrl,
            fullName: user.fullName,
            radius: 56,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: context.brand.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(user.email, style: TextStyle(color: context.brand.neutralGrey)),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return LiquidTouch(
      onTap: onTap ?? () {},
      child: GlassContainer(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 20,
        padding: EdgeInsets.zero, // Padding handled by InkWell
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center contents vertically
            children: [
              Icon(
                icon,
                color: context.brand.darkText.withValues(alpha: 0.7),
                size: 28,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.brand.darkText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.brand.neutralGrey,
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: context.brand.neutralGrey.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return LiquidTouch(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.brand.darkText,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.brand.neutralGrey),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbsencesDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    S s,
  ) {
    int count = user.absences;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.brand.backgroundSnow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          title: Text(
            s.manageAbsences,
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.absenceCount,
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: count > 0
                        ? () => setDialogState(() => count--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 36,
                    color: context.brand.neutralGrey.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: context.brand.darkText,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () => setDialogState(() => count++),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 36,
                    color: context.brand.darkText.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Manual entry
              SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.brand.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '$count',
                    isDense: true,
                  ).applyDefaults(Theme.of(context).inputDecorationTheme),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 0) {
                      setDialogState(() => count = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                s.cancel,
                style: TextStyle(color: context.brand.neutralGrey),
              ),
            ),
            ElevatedButton(
              style: Theme.of(context).brightness == Brightness.dark
                  ? ElevatedButton.styleFrom(
                      backgroundColor: context.brand.primaryPurple.withValues(
                        alpha: 0.22,
                      ),
                      foregroundColor: context.brand.darkText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    )
                  : ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                      foregroundColor: context.brand.darkText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
              onPressed: () {
                ref
                    .read(authRepositoryProvider)
                    .updateUserProfile(user.copyWith(absences: count));
                Navigator.pop(ctx);
              },
              child: Text(
                s.save,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeGradeDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    S s,
  ) {
    final grades = [
      'Α\' Γυμνασίου',
      'Β\' Γυμνασίου',
      'Γ\' Γυμνασίου',
      'Α\' Λυκείου',
      'Β\' Λυκείου - Ανθρωπιστικών',
      'Β\' Λυκείου - Θετικών Σπουδών',
      'Γ\' Λυκείου - Ανθρωπιστικών',
      'Γ\' Λυκείου - Θετικών Σπουδών',
      'Γ\' Λυκείου - Σπουδών Υγείας',
      'Γ\' Λυκείου - Οικονομίας/Πληροφορικής',
    ];
    String selectedGrade = user.currentClass ?? grades.first;
    if (!grades.contains(selectedGrade)) selectedGrade = grades.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.brand.backgroundSnow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          title: Text(
            s.lang == 'el' ? 'Αλλαγή Τάξης' : 'Change Grade',
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedGrade,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.brand.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.brand.primaryPurple.withValues(
                        alpha: 0.85,
                      ),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                dropdownColor: context.brand.surfaceElevated,
                items: grades
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          g,
                          style: TextStyle(color: context.brand.darkText),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedGrade = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                s.cancel,
                style: TextStyle(color: context.brand.neutralGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand.royalLavender,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (confirmCtx) => AlertDialog(
                    backgroundColor: context.brand.backgroundSnow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    title: Text(
                      s.lang == 'el' ? 'Επιβεβαίωση Αλλαγής' : 'Confirm Change',
                      style: TextStyle(
                        color: context.brand.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      s.lang == 'el'
                          ? 'Με την αλλαγή τάξης, τα μαθήματά σας θα αντικατασταθούν με τα προεπιλεγμένα της νέας τάξης. Το ιστορικό εργασιών σας και οι ομάδες σας θα παραμείνουν. Θέλετε να συνεχίσετε;'
                          : 'By changing your grade, your subjects will be replaced with the default ones for the new grade. Your homework history and classrooms will remain. Do you want to continue?',
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx),
                        child: Text(
                          s.cancel,
                          style: TextStyle(color: context.brand.neutralGrey),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.brand.royalLavender,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newSubjects = _getDefaultSubjectsForGrade(
                            selectedGrade,
                          );
                          final navigator = Navigator.of(context);

                          await callUpdateStudentCurrentClass(selectedGrade);

                          await ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(
                                user.copyWith(
                                  subjects: newSubjects,
                                  tutoringSubjects: user.tutoringSubjects
                                      .where((ts) => newSubjects.contains(ts))
                                      .toList(),
                                ),
                              );

                          // Homework classId sync is handled server-side by updateStudentCurrentClass.

                          navigator.pop(); // Pop dialog
                          navigator.pop(); // Pop confirmation dialog
                        },
                        child: Text(
                          s.save,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                s.save,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getDefaultSubjectsForGrade(String gradeClass) {
    final Map<String, List<String>> subjectMapping = {
      'Α\' Γυμνασίου': [
        'Νέα Ελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
        'Αρχαία Ελληνικά',
        'Οδύσσεια',
        'Αγγλικά',
        '2η Ξένη Γλώσσα',
        'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
        'Φυσική',
        'Βιολογία',
        'Ιστορία',
        'Θρησκευτικά',
        'Γεωγραφία',
        'Οικιακή Οικονομία',
        'Τεχνολογία',
        'Πληροφορική',
        'Μουσική',
        'Εικαστικά',
        'Φυσική Αγωγή',
        'Εργαστήρια Δεξιοτήτων',
      ],
      'Β\' Γυμνασίου': [
        'Νέα Ελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
        'Αρχαία Ελληνικά',
        'Ιλιάδα',
        'Αγγλικά',
        '2η Ξένη Γλώσσα',
        'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
        'Φυσική',
        'Χημεία',
        'Βιολογία',
        'Ιστορία',
        'Θρησκευτικά',
        'Γεωγραφία',
        'Τεχνολογία',
        'Πληροφορική',
        'Μουσική',
        'Εικαστικά',
        'Φυσική Αγωγή',
        'Εργαστήρια Δεξιοτήτων',
      ],
      'Γ\' Γυμνασίου': [
        'Νέα Ελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
        'Αρχαία Ελληνικά',
        'Ελένη',
        'Αγγλικά',
        '2η Ξένη Γλώσσα',
        'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
        'Φυσική',
        'Χημεία',
        'Βιολογία',
        'Ιστορία',
        'Θρησκευτικά',
        'Κοινωνική & Πολιτική Αγωγή',
        'Τεχνολογία',
        'Πληροφορική',
        'Μουσική',
        'Εικαστικά',
        'Φυσική Αγωγή',
        'Εργαστήρια Δεξιοτήτων',
      ],
      'Α\' Λυκείου': [
        'Νέα Ελληνικά',
        'Αρχαία Ελληνικά',
        'Αγγλικά',
        'Άλγεβρα',
        'Γεωμετρία',
        'Φυσική',
        'Χημεία',
        'Βιολογία',
        'Ιστορία',
        'Θρησκευτικά',
        'Κοινωνική & Πολιτική Αγωγή',
        'Εφαρμογές Πληροφορικής',
        '2η Ξένη Γλώσσα',
        'Φυσική Αγωγή',
      ],
      'Β\' Λυκείου - Γενικής Παιδείας': [
        'Νεοελληνική Γλώσσα και Λογοτεχνία',
        'Αρχαία Ελληνικά — Σοφοκλέους Αντιγόνη / Θουκυδίδη Περικλέους Επιτάφιος',
        'Άλγεβρα',
        'Γεωμετρία',
        'Φυσική',
        'Χημεία',
        'Βιολογία',
        'Ιστορία',
        'Φιλοσοφία (ή μάθημα επιλογής)',
        'Αγγλικά',
        '2η Ξένη Γλώσσα',
        'Θρησκευτικά',
        'Φυσική Αγωγή',
      ],
      'Β\' Λυκείου - Ανθρωπιστικών': [
        'Αρχαία Ελληνική Γλώσσα και Γραμματεία',
        'Λατινικά',
      ],
      'Β\' Λυκείου - Θετικών Σπουδών': [
        'Μαθηματικά Προσανατολισμού',
        'Φυσική Προσανατολισμού',
      ],
      'Γ\' Λυκείου - Γενικής Παιδείας': [
        'Νεοελληνική Γλώσσα και Λογοτεχνία',
        'Θρησκευτικά',
        'Αγγλικά',
        'Φυσική Αγωγή',
        'Ιστορία',
      ],
      'Γ\' Λυκείου - Ανθρωπιστικών': [
        'Αρχαία Ελληνικά',
        'Λατινικά',
        'Ιστορία',
        'Μαθηματικά (Γενικής Παιδείας)',
      ],
      'Γ\' Λυκείου - Θετικών Σπουδών': ['Μαθηματικά', 'Φυσική', 'Χημεία'],
      'Γ\' Λυκείου - Σπουδών Υγείας': [
        'Βιολογία',
        'Φυσική',
        'Χημεία',
        'Μαθηματικά (Γενικής Παιδείας)',
      ],
      'Γ\' Λυκείου - Οικονομίας/Πληροφορικής': [
        'Μαθηματικά',
        'Πληροφορική',
        'Οικονομία',
      ],
    };

    List<String> subjects = [];
    if (gradeClass.contains('Λυκείου') && gradeClass != 'Α\' Λυκείου') {
      final parts = gradeClass.split(' - ');
      if (parts.length == 2) {
        final yearPart = parts[0];
        subjects.addAll(subjectMapping['$yearPart - Γενικής Παιδείας'] ?? []);
        subjects.addAll(subjectMapping[gradeClass] ?? []);
      }
    } else {
      subjects = subjectMapping[gradeClass] ?? [];
    }
    return subjects.toSet().toList();
  }

}

// ---------------------------------------------------------------------------
// Derived provider — memoizes expensive grade computations so they do not
// re-run on every profile build triggered by unrelated provider updates
// (e.g. auth display-name or spark-count changes).
// ---------------------------------------------------------------------------

/// Record holding pre-computed profile grade stats.
typedef _ProfileGradeStats = ({double average, List<FlSpot> spots});

final _profileGradeStatsProvider =
    Provider.autoDispose<_ProfileGradeStats>((ref) {
  final grades = ref.watch(gradesProvider).value ?? [];
  final currentClass = ref.watch(
    authStateProvider.select((s) => s.valueOrNull?.currentClass),
  );
  return (
    average: _topLevelCalcOverallAverage(grades, currentClass),
    spots: _topLevelCalcSparklineSpots(grades),
  );
});

double _topLevelCalcOverallAverage(
  List<GradeRecord> allGrades,
  String? currentClass,
) {
  if (allGrades.isEmpty) return 0.0;
  final Map<String, Map<String, double>> subjectGrades = {};
  for (final grade in allGrades) {
    subjectGrades.putIfAbsent(grade.subject, () => {})[grade.term] =
        grade.grade;
  }
  double totalAvg = 0.0;
  int subjectCount = 0;
  for (final entry in subjectGrades.entries) {
    final terms = entry.value;
    final double? term1 = terms['1ο Τετράμηνο'];
    final double? term2 = terms['2ο Τετράμηνο'];
    final double? exam = terms['Τελικές Εξετάσεις'];
    final bool hasFinals =
        currentClass != null &&
        SubjectGradingData.hasFinalExam(entry.key, currentClass);
    double annualGrade = 0.0;
    if (currentClass != null && currentClass.contains('Λυκείου')) {
      if (currentClass.contains("Γ'")) {
        annualGrade = hasFinals
            ? GradeCalculator.calculateLyceumGradeC(term1, term2, exam)
            : GradeCalculator.calculateGymnasioGroupBC(term1, term2);
      } else {
        annualGrade = hasFinals
            ? GradeCalculator.calculateLyceumGradesAB(term1, term2, exam)
            : GradeCalculator.calculateGymnasioGroupBC(term1, term2);
      }
    } else {
      annualGrade = hasFinals
          ? GradeCalculator.calculateGymnasioGroupA(term1, term2, exam)
          : GradeCalculator.calculateGymnasioGroupBC(term1, term2);
    }
    if (annualGrade > 0) {
      totalAvg += annualGrade;
      subjectCount++;
    }
  }
  return subjectCount > 0 ? totalAvg / subjectCount : 0.0;
}

List<FlSpot> _topLevelCalcSparklineSpots(List<GradeRecord> allGrades) {
  if (allGrades.isEmpty) {
    return const [
      FlSpot(0, 16),
      FlSpot(1, 17.5),
      FlSpot(2, 17),
      FlSpot(3, 18.5),
      FlSpot(4, 18),
      FlSpot(5, 19.5),
    ];
  }
  final Map<String, List<double>> termGrades = {
    '1ο Τετράμηνο': [],
    '2ο Τετράμηνο': [],
    'Τελικές Εξετάσεις': [],
  };
  for (final grade in allGrades) {
    if (termGrades.containsKey(grade.term)) {
      termGrades[grade.term]!.add(grade.grade);
    }
  }
  final List<FlSpot> spots = [];
  double x = 0;
  for (final key in ['1ο Τετράμηνο', '2ο Τετράμηνο', 'Τελικές Εξετάσεις']) {
    final vals = termGrades[key]!;
    if (vals.isNotEmpty) {
      spots.add(FlSpot(x++, vals.reduce((a, b) => a + b) / vals.length));
    }
  }
  if (spots.length == 1) {
    spots.insert(0, FlSpot(-1, spots[0].y));
  } else if (spots.isEmpty) {
    return const [
      FlSpot(0, 16),
      FlSpot(1, 17.5),
      FlSpot(2, 17),
      FlSpot(3, 18.5),
      FlSpot(4, 18),
      FlSpot(5, 19.5),
    ];
  }
  return spots;
}
