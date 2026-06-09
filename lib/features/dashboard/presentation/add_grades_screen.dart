import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/grade_model.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_logic.dart';
import '../data/subject_grading_data.dart';
import '../application/term_grades_ocr_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/parental_consent_eligibility.dart';
import '../../auth/presentation/parental_consent_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/ocr_image_bytes.dart';
import 'subject_grade_detail_screen.dart';

class AddGradesScreen extends ConsumerStatefulWidget {
  const AddGradesScreen({super.key});

  @override
  ConsumerState<AddGradesScreen> createState() => _AddGradesScreenState();
}

class _AddGradesScreenState extends ConsumerState<AddGradesScreen> {
  final _yearController = TextEditingController(text: '2025-2026');
  String _schoolYear = '2025-2026';
  bool _isLoading = false;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _showGradeDialog(
    String subject,
    String term,
    GradeRecord? existingRecord,
  ) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final isGreek = user.preferredLanguage == 'el';
    final TextEditingController controller = TextEditingController(
      text: existingRecord != null ? existingRecord.grade.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '$subject\n$term',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isGreek ? 'Βαθμός (0-20)' : 'Grade (0-20)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (existingRecord != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  await ref
                      .read(dashboardRepositoryProvider)
                      .deleteGrade(user.uid, existingRecord.id);
                  ref.invalidate(gradesProvider);
                  setState(() => _isLoading = false);
                },
                child: Text(
                  isGreek ? 'Διαγραφή' : 'Delete',
                  style: TextStyle(color: context.brand.errorRed),
                ),
              )
            else
              const SizedBox.shrink(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isGreek ? 'Ακύρωση' : 'Cancel',
                    style: TextStyle(color: context.brand.neutralGrey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brand.royalLavender,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(
                      controller.text.replaceAll(',', '.'),
                    );
                    if (val == null || val < 0 || val > 20) return;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      final newRecord = GradeRecord(
                        id: existingRecord?.id ?? '',
                        subject: subject,
                        grade: val,
                        term: term,
                        date: DateTime.now(),
                        schoolYear: _schoolYear,
                      );

                      if (existingRecord == null) {
                        await ref
                            .read(dashboardRepositoryProvider)
                            .addGrade(user.uid, newRecord);
                      } else {
                        await ref
                            .read(dashboardRepositoryProvider)
                            .deleteGrade(user.uid, existingRecord.id);
                        await ref
                            .read(dashboardRepositoryProvider)
                            .addGrade(user.uid, newRecord);
                      }

                      ref.invalidate(gradesProvider);
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  child: Text(isGreek ? 'Αποθήκευση' : 'Save'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanTermGradesFromImage(
    bool isGreek,
    List<String> subjects,
    Map<String, Map<String, GradeRecord>> gradesBySubject,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    if (requiresParentalAiGate(user)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dCtx) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;
    setState(() => _isLoading = true);
    try {
      final rawBytes = await picked.readAsBytes();
      final bytes = await compute(encodeImageBytesForGeminiOcr, rawBytes);
      final rows = await ref
          .read(termGradesOcrControllerProvider.notifier)
          .scanReport(
            imageBytes: bytes,
            availableSubjects: subjects,
            isGreek: isGreek,
          );
      if (rows.isEmpty) {
        if (mounted) {
          final err = ref.read(termGradesOcrControllerProvider).error;
          CustomSnackBar.show(
            context: context,
            message:
                err ??
                (isGreek
                    ? 'Δεν βρέθηκαν έγκυροι βαθμοί στην εικόνα.'
                    : 'No valid grades were detected in the image.'),
            type: SnackBarType.warning,
          );
        }
        return;
      }

      for (final row in rows) {
        final existing = gradesBySubject[row.subjectName]?[row.term];
        if (existing != null) {
          await ref
              .read(dashboardRepositoryProvider)
              .deleteGrade(user.uid, existing.id);
        }
        final record = GradeRecord(
          id: '',
          subject: row.subjectName,
          grade: row.grade,
          term: row.term,
          date: DateTime.now(),
          schoolYear: _schoolYear,
        );
        await ref.read(dashboardRepositoryProvider).addGrade(user.uid, record);
      }
      ref.invalidate(gradesProvider);
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: isGreek
              ? 'Η εισαγωγή βαθμών από OCR ολοκληρώθηκε.'
              : 'OCR grades import completed.',
          type: SnackBarType.success,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGradeCell(String subject, String term, GradeRecord? record) {
    Color? textColor;
    if (record != null) {
      textColor = record.grade >= 15
          ? Colors.green[800]
          : _gradeColor(record.grade);
    }
    return GestureDetector(
      onTap: () => _showGradeDialog(subject, term, record),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: record != null
              ? _gradeColor(record.grade).withValues(alpha: 0.15)
              : context.brand.neutralGrey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: record != null
                ? _gradeColor(record.grade).withValues(alpha: 0.3)
                : context.brand.neutralGrey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          record != null ? record.grade.toStringAsFixed(1) : '-',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color:
                textColor ?? context.brand.neutralGrey.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// One pass over [grades]: subject name → (term label → record). O(1) lookups per cell.
  static Map<String, Map<String, GradeRecord>> _gradesBySubjectThenTerm(
    List<GradeRecord> grades,
  ) {
    final bySubject = <String, Map<String, GradeRecord>>{};
    for (final g in grades) {
      bySubject.putIfAbsent(g.subject, () => <String, GradeRecord>{})[g.term] =
          g;
    }
    return bySubject;
  }

  Widget _buildSubjectRow(
    BuildContext context,
    String subject,
    Map<String, Map<String, GradeRecord>> gradesBySubject,
    bool isGreek,
    String? currentClass,
    String schoolYear,
  ) {
    final term1Label = isGreek ? '1ο Τετράμηνο' : '1st Term';
    final term2Label = isGreek ? '2ο Τετράμηνο' : '2nd Term';
    final finalsLabel = isGreek ? 'Τελικές Εξετάσεις' : 'Final Exams';

    final byTerm = gradesBySubject[subject];
    GradeRecord? term1 = byTerm?[term1Label];
    GradeRecord? term2 = byTerm?[term2Label];
    GradeRecord? finals = byTerm?[finalsLabel];

    bool hasFinals =
        currentClass != null &&
        SubjectGradingData.hasFinalExam(subject, currentClass);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SubjectGradeDetailScreen(
                        subject: subject,
                        schoolYear: schoolYear,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: subject,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.brand.darkText,
                          ),
                        ),
                        if (hasFinals)
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.brand.royalLavender,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: _buildGradeCell(subject, term1Label, term1)),
          Expanded(flex: 2, child: _buildGradeCell(subject, term2Label, term2)),
          Expanded(
            flex: 2,
            child: hasFinals
                ? _buildGradeCell(subject, finalsLabel, finals)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final gradesAsync = ref.watch(gradesProvider);
    final isGreek = s.lang == 'el';
    final grades = gradesAsync.value ?? [];
    final gradesBySubject = _gradesBySubjectThenTerm(grades);

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.myGrades),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => _scanTermGradesFromImage(
                isGreek,
                user?.subjects ?? const [],
                gradesBySubject,
              ),
              icon: Icon(
                Icons.document_scanner_rounded,
                color: context.brand.royalLavender,
              ),
              tooltip: isGreek ? 'Σάρωση Ελέγχου Προόδου' : 'Scan Report Card',
            ),
            IconButton(
              onPressed: () => _showHistoryArchive(context),
              icon: Icon(
                Icons.history_rounded,
                color: context.brand.primaryPurple,
              ),
              tooltip: isGreek
                  ? 'Αρχείο Προηγούμενων Ετών'
                  : 'Previous Years Archive',
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20).copyWith(bottom: 80),
                  children: [
                    // School Year Selector
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isGreek ? 'Σχολικό Έτος' : 'School Year',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.brand.darkText,
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _yearController,
                                onChanged: (val) =>
                                    setState(() => _schoolYear = val),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.brand.royalLavender,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Report Card Table
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The Table Header
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    isGreek
                                        ? 'Μάθημα (* = Εξετ.)'
                                        : 'Subject (* = Exam)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.brand.neutralGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      isGreek ? "1ο Τετρ." : "1st Term",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: context.brand.neutralGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      isGreek ? "2ο Τετρ." : "2nd Term",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: context.brand.neutralGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      isGreek ? "Εξετάσεις" : "Finals",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: context.brand.neutralGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),

                            // The rows
                            if (user?.subjects.isEmpty ?? true)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    isGreek
                                        ? 'Προσθέστε μαθήματα στο προφίλ σας για να δρομολογήσετε τους βαθμούς σας.'
                                        : 'Add subjects to your profile to track grades.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.brand.neutralGrey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...user!.subjects.map((subject) {
                                return _buildSubjectRow(
                                  context,
                                  subject,
                                  gradesBySubject,
                                  isGreek,
                                  user.currentClass,
                                  _schoolYear,
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.5),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.brand.royalLavender,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryArchive(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final yearsAsync = ref.watch(gradeYearsProvider);
            final user = ref.read(authStateProvider).value;
            final isGreek = user?.preferredLanguage == 'el';
            final sheetCs = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isGreek ? 'Αρχείο Βαθμολογιών' : 'Grades Archive',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: sheetCs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  yearsAsync.when(
                    data: (years) {
                      if (years.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            isGreek
                                ? 'Δεν βρέθηκαν παλαιότερα έτη.'
                                : 'No previous years found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: sheetCs.onSurfaceVariant),
                          ),
                        );
                      }
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.separated(
                          itemCount: years.length,
                          shrinkWrap: true,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            color: sheetCs.outline.withValues(alpha: 0.25),
                          ),
                          itemBuilder: (ctx, i) {
                            return ListTile(
                              title: Text(
                                years[i],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: sheetCs.onSurface,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: sheetCs.onSurfaceVariant,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _viewHistoricalYear(years[i]);
                              },
                            );
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _viewHistoricalYear(String year) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoricalGradesView(schoolYear: year),
      ),
    );
  }

  Color _gradeColor(double grade) {
    if (grade >= 18) return context.brand.mintSuccess;
    if (grade >= 15) return Colors.green;
    if (grade >= 12) return Colors.blue;
    if (grade >= 10) return Colors.orange;
    return context.brand.errorRed;
  }
}

/// First grade in [list] matching each historical column rule (same order as three `.where` chains).
({GradeRecord? t1, GradeRecord? t2, GradeRecord? ex}) _historicalTermTriplet(
  List<GradeRecord> list,
) {
  GradeRecord? t1;
  GradeRecord? t2;
  GradeRecord? ex;
  for (final g in list) {
    if (t1 == null && g.term.contains('1')) t1 = g;
    if (t2 == null && g.term.contains('2')) t2 = g;
    if (ex == null && g.term.contains('Τελικ')) ex = g;
  }
  return (t1: t1, t2: t2, ex: ex);
}

class HistoricalGradesView extends ConsumerWidget {
  final String schoolYear;
  const HistoricalGradesView({super.key, required this.schoolYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isGreek = user?.preferredLanguage == 'el';
    final historyAsync = ref.watch(gradesHistoryProvider(schoolYear));

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(schoolYear),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: historyAsync.when(
          data: (grades) {
            if (grades.isEmpty) {
              return Center(
                child: Text(
                  isGreek ? 'Δεν βρέθηκαν δεδομένα.' : 'No data found.',
                  style: TextStyle(color: context.brand.neutralGrey),
                ),
              );
            }

            final subjects = grades.map((g) => g.subject).toSet().toList();
            subjects.sort();

            final gradesBySubject = <String, List<GradeRecord>>{};
            for (final g in grades) {
              gradesBySubject.putIfAbsent(g.subject, () => []).add(g);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                isGreek ? 'Μάθημα' : 'Subject',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  'T1',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  'T2',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Center(
                                child: Text(
                                  'EX',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        ...subjects.map((s) {
                          final list = gradesBySubject[s] ?? [];
                          final (:t1, :t2, :ex) = _historicalTermTriplet(list);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      t1?.grade.toString() ?? '-',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      t2?.grade.toString() ?? '-',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      ex?.grade.toString() ?? '-',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
