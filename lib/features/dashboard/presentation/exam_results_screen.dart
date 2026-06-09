import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/exam_result_model.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_logic.dart';
import '../../auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class ExamResultsScreen extends ConsumerStatefulWidget {
  const ExamResultsScreen({super.key});

  @override
  ConsumerState<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends ConsumerState<ExamResultsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  final _examNameController = TextEditingController();
  final _scoreController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _examNameController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSubject == null) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final result = ExamResult(
          id: '',
          subject: _selectedSubject!,
          examName: _examNameController.text.trim(),
          score: double.parse(_scoreController.text.replaceAll(',', '.')),
          date: _selectedDate,
          schoolYear: '2025-2026', // Current school year
        );
        await ref
            .read(dashboardRepositoryProvider)
            .addExamResult(user.uid, result);
        ref.invalidate(examResultsProvider);
        if (mounted) {
          final s = S(user.preferredLanguage);
          CustomSnackBar.show(
            context: context,
            message: s.resultAddedSuccess,
            type: SnackBarType.success,
          );
          _examNameController.clear();
          _scoreController.clear();
          setState(() => _selectedSubject = null);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final resultsAsync = ref.watch(examResultsProvider);
    final isGreek = s.lang == 'el';

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.lang == 'el' ? 'Τεστ & Εξετάσεις' : 'Tests & Exams'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
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
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Add Result Form
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isGreek ? 'Νέο Αποτέλεσμα' : 'New Result',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),

                          // Subject Picker
                          InkWell(
                            onTap: () async {
                              final picked = await showSubjectPickerDialog(
                                context: context,
                                subjects: user?.subjects ?? [],
                                title: s.selectSubject,
                                currentSubject: _selectedSubject,
                              );
                              if (picked != null) {
                                setState(() => _selectedSubject = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: s.subject,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                              child: Text(
                                _selectedSubject ?? s.selectSubject,
                                style: TextStyle(
                                  color: _selectedSubject != null
                                      ? Colors.black87
                                      : context.brand.neutralGrey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Exam Name
                          DropdownButtonFormField<String>(
                            initialValue: _examNameController.text.isNotEmpty
                                ? _examNameController.text
                                : null,
                            decoration: InputDecoration(
                              labelText: isGreek ? 'Είδος' : 'Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items:
                                (isGreek
                                        ? [
                                            'Τεστ',
                                            'Διαγώνισμα',
                                            'Πρόχειρο',
                                            'Προφορικά',
                                            'Project',
                                            'Άλλο',
                                          ]
                                        : [
                                            'Quiz',
                                            'Test',
                                            'Midterm',
                                            'Oral Exam',
                                            'Project',
                                            'Other',
                                          ])
                                    .map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      );
                                    })
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _examNameController.text = val;
                                });
                              }
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return isGreek
                                    ? 'Επιλέξτε είδος'
                                    : 'Select exam type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Score Input
                          TextFormField(
                            controller: _scoreController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: s.score,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return isGreek
                                    ? 'Εισάγετε βαθμό'
                                    : 'Enter a score';
                              final score = double.tryParse(val);
                              if (score == null || score < 0 || score > 20) {
                                return isGreek
                                    ? 'Βαθμός 0-20'
                                    : 'Score must be 0-20';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Date Picker
                          ListTile(
                            title: Text(isGreek ? 'Ημερομηνία' : 'Date'),
                            subtitle: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                            trailing: Icon(
                              Icons.calendar_today,
                              color: context.brand.royalLavender,
                            ),
                            onTap: () => _selectDate(context),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.brand.royalLavender,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isGreek ? 'Προσθήκη' : 'Add Result'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Existing Results
                Text(
                  isGreek ? 'Όλα τα αποτελέσματα' : 'All Results',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                resultsAsync.when(
                  data: (results) {
                    if (results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            s.noExamResultsYet,
                            style: TextStyle(color: context.brand.neutralGrey),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        ...results.map(
                          (r) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _scoreColor(
                                  r.score,
                                ).withValues(alpha: 0.2),
                                child: Text(
                                  r.score.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: _scoreColor(r.score),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                r.subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${r.examName} • ${r.date.day}/${r.date.month}/${r.date.year}',
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: context.brand.errorRed,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(dashboardRepositoryProvider)
                                      .deleteExamResult(user!.uid, r.id);
                                  ref.invalidate(examResultsProvider);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
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
            final yearsAsync = ref.watch(examResultYearsProvider);
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
                    isGreek ? 'Αρχείο Αποτελεσμάτων' : 'Results Archive',
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
        builder: (context) => HistoricalExamResultsView(schoolYear: year),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 16) return Colors.green;
    if (score >= 13) return Colors.blue;
    if (score >= 10) return Colors.orange;
    return context.brand.errorRed;
  }
}

class HistoricalExamResultsView extends ConsumerWidget {
  final String schoolYear;
  const HistoricalExamResultsView({super.key, required this.schoolYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isGreek = user?.preferredLanguage == 'el';
    final historyAsync = ref.watch(examResultsHistoryProvider(schoolYear));

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(schoolYear),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: historyAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return Center(
                child: Text(
                  isGreek ? 'Δεν βρέθηκαν δεδομένα.' : 'No data found.',
                  style: TextStyle(color: context.brand.neutralGrey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      child: Text(
                        r.score.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.brand.darkText,
                        ),
                      ),
                    ),
                    title: Text(
                      r.subject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${r.examName} • ${r.date.day}/${r.date.month}/${r.date.year}',
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
