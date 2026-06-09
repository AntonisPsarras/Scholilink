import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/dashboard_logic.dart';
import 'schedule_editor_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/l10n.dart';
import '../../../shared/responsive_layout.dart';
import '../../../shared/desktop_page_shell.dart';
import '../../../shared/widgets/subject_chip.dart';
import '../../../shared/app_shell_insets.dart';
import 'next_class_banner.dart';

String _translateDay(String day, String lang) {
  if (lang != 'el') return day;
  switch (day.toLowerCase()) {
    case 'monday':
      return 'Δευτέρα';
    case 'tuesday':
      return 'Τρίτη';
    case 'wednesday':
      return 'Τετάρτη';
    case 'thursday':
      return 'Πέμπτη';
    case 'friday':
      return 'Παρασκευή';
    default:
      return day;
  }
}

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final lang = ref.watch(userLanguageProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please log in')));
        }

        final s = S(user.preferredLanguage);
        final classId = user.scheduleExamClassId;
        final scheduleAsync = ref.watch(scheduleProvider(classId));

        return Scaffold(
          backgroundColor: Colors.transparent, // Allow global gradient
          appBar: AppBar(
            title: Text(
              s.lang == 'el' ? 'Το Πρόγραμμά μου' : 'My Classes',
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
              IconButton(
                icon: Icon(
                  Icons.edit_note,
                  color: context.brand.darkText.withValues(alpha: 0.8),
                ),
                onPressed: () {
                  const editor = ScheduleEditorScreen();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResponsiveLayout.isDesktop(context)
                          ? const DesktopPageShell(
                              selectedNavIndex: 2,
                              child: editor,
                            )
                          : editor,
                    ),
                  );
                },
                tooltip: s.manageSchedule,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: scheduleAsync.when(
                  data: (days) {
                    if (days.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.lang == 'el'
                                    ? 'Δεν βρέθηκε πρόγραμμα για την τάξη σας.'
                                    : 'No schedule found for your class.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.brand.neutralGrey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              LiquidTouch(
                                onTap: () {
                                  const editor = ScheduleEditorScreen();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ResponsiveLayout.isDesktop(context)
                                          ? const DesktopPageShell(
                                              selectedNavIndex: 2,
                                              child: editor,
                                            )
                                          : editor,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.brand.darkText.withValues(
                                      alpha: 0.8,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.lang == 'el'
                                            ? 'Δημιουργία Προγράμματος'
                                            : 'Create Schedule',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return DefaultTabController(
                      length: days.length,
                      child: Column(
                        children: [
                          NextClassBanner(classId: classId, s: s),
                          TabBar(
                            isScrollable: true,
                            indicatorColor: context.brand.royalLavender,
                            labelColor: context.brand.darkText,
                            unselectedLabelColor: context.brand.neutralGrey,
                            tabs: days
                                .map(
                                  (dayData) => Tab(
                                    text: _translateDay(
                                      dayData['dayName'] as String,
                                      s.lang,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: days.asMap().entries.map((entry) {
                                final dayData = entry.value;
                                final classes = List<Map<String, dynamic>>.from(
                                  dayData['classes'],
                                );
                                final bottomPad = shellBottomContentPadding(
                                  context,
                                );
                                return SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    24,
                                    16,
                                    bottomPad,
                                  ),
                                  child: _buildDaySchedule(context, classes, s),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('${s.error}: $err')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(body: Center(child: Text(S(lang).loading))),
      error: (err, stack) => Scaffold(body: Center(child: Text(S(lang).error))),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? context.brand.royalLavender),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? context.brand.darkText,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySchedule(
    BuildContext context,
    List<Map<String, dynamic>> classes,
    S s,
  ) {
    final schoolClasses = <Map<String, String>>[];
    final tutoringClasses = <Map<String, String>>[];

    for (var c in classes) {
      final clsMap = Map<String, String>.from(c);
      final subjLow = (clsMap['subject'] ?? '').toLowerCase();

      // Multi-keyword fallback for tutoring detection
      final isTutoringFallback =
          subjLow.contains('φροντ') ||
          subjLow.contains('tutoring') ||
          subjLow.contains('personal') ||
          subjLow.contains('ιδιαιτ'); // "ιδιαίτερο"

      final type =
          clsMap['type'] ?? (isTutoringFallback ? 'frontistirio' : 'school');

      if (type == 'frontistirio') {
        tutoringClasses.add(clsMap);
      } else {
        schoolClasses.add(clsMap);
      }
    }

    // Heuristic sort by starting time
    int timeToVal(String? t) {
      if (t == null) return 0;
      final parts = t.split(' - ').first.split(':');
      if (parts.length < 2) return 0;
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    schoolClasses.sort(
      (a, b) => timeToVal(a['time']).compareTo(timeToVal(b['time'])),
    );
    tutoringClasses.sort(
      (a, b) => timeToVal(a['time']).compareTo(timeToVal(b['time'])),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (schoolClasses.isNotEmpty) ...[
          _buildSectionHeader(context, s.schoolProgram, Icons.school_outlined),
          ...schoolClasses.map(
            (cls) => _ClassCard(cls: cls, s: s, isTutoring: false),
          ),
          const SizedBox(height: 24),
        ],
        if (tutoringClasses.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            s.tutoringProgram,
            Icons.auto_awesome_outlined,
            color: context.brand.sunsetWarning,
          ),
          ...tutoringClasses.map(
            (cls) => _ClassCard(cls: cls, s: s, isTutoring: true),
          ),
        ],
        if (schoolClasses.isEmpty && tutoringClasses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                s.lang == 'el' ? 'Κανένα μάθημα σήμερα!' : 'No classes today!',
                style: TextStyle(color: context.brand.neutralGrey),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, String> cls;
  final S s;
  final bool isTutoring;

  const _ClassCard({
    required this.cls,
    required this.s,
    required this.isTutoring,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = cls['subject']?.split(' & ') ?? [];
    final timeStr = cls['time'] ?? '';
    final timeParts = timeStr.split(' - ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        backgroundColor: isTutoring
            ? context.brand.sunsetWarning.withValues(alpha: 0.12)
            : (Theme.of(context).brightness == Brightness.dark
                  ? null
                  : Colors.white.withValues(alpha: 0.5)),
        border: Border.all(
          color:
              (isTutoring
                      ? context.brand.sunsetWarning
                      : context.brand.primaryPurple)
                  .withValues(alpha: 0.2),
          width: 0.8,
        ),
        child: Row(
          children: [
            // Time
            SizedBox(
              width: 55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeParts.first,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.brand.darkText.withValues(alpha: 0.9),
                    ),
                  ),
                  if (timeParts.length > 1)
                    Text(
                      timeParts.last,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.brand.neutralGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Vertical accent
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: isTutoring
                    ? context.brand.sunsetWarning
                    : context.brand.royalLavender,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            // Subjects
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subjects.length > 1)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: subjects
                          .map(
                            (subj) => SubjectChip(
                              subject: subj,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Text(
                      subjects.firstOrNull ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.brand.darkText,
                      ),
                    ),
                  if (cls['room'] != null && cls['room']!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.room_outlined,
                          size: 12,
                          color: context.brand.neutralGrey.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cls['room']!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.brand.neutralGrey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
