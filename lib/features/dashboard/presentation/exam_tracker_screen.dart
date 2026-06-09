import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/exam_model.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_logic.dart';
import '../services/google_calendar_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class ExamTrackerScreen extends ConsumerStatefulWidget {
  const ExamTrackerScreen({super.key});

  @override
  ConsumerState<ExamTrackerScreen> createState() => _ExamTrackerScreenState();
}

class _ExamTrackerScreenState extends ConsumerState<ExamTrackerScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final parentTheme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (pickerCtx, child) {
        if (parentTheme.brightness == Brightness.dark) return child!;
        return Theme(
          data: parentTheme.copyWith(
            colorScheme: ColorScheme.light(
              primary: context.brand.primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: context.brand.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      final lang = ref.read(authStateProvider).value?.preferredLanguage ?? 'el';
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Επίλεξε μάθημα.'
              : 'Please select a subject.',
          type: SnackBarType.error,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        if (mounted) {
          CustomSnackBar.show(
            context: context,
            message: 'Not signed in.',
            type: SnackBarType.error,
          );
        }
        return;
      }

      final exam = Exam(
        id: '',
        subject: _selectedSubject!,
        date: _selectedDate,
        description: _descriptionController.text,
        classId: user.scheduleExamClassId,
      );

      await ref.read(dashboardRepositoryProvider).addExam(exam);
      ref.invalidate(examProvider(user.scheduleExamClassId));

      if (user.syncToDeviceCalendar && mounted) {
        final synced = await ref
            .read(googleCalendarServiceProvider)
            .syncExamToCalendar(exam, context);
        if (mounted) {
          final lang = user.preferredLanguage;
          CustomSnackBar.show(
            context: context,
            message: lang == 'el'
                ? (synced
                      ? 'Η εξέταση προστέθηκε & συγχρονίστηκε με Google Calendar!'
                      : 'Η εξέταση προστέθηκε!')
                : (synced
                      ? 'Exam added & synced to Google Calendar!'
                      : 'Exam added!'),
            type: SnackBarType.success,
          );
          Navigator.pop(context);
        }
        return;
      }

      if (mounted) {
        final lang = user.preferredLanguage;
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Η εξέταση προστέθηκε!'
              : 'Exam added successfully!',
          type: SnackBarType.success,
        );
        Navigator.pop(context);
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
    final lang = user?.preferredLanguage ?? 'el';
    final s = S(lang);

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.brand.darkText,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.addExam,
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Subject Picker ──────────────────────────────────────
                        _SectionLabel(
                          label: lang == 'el' ? 'Μάθημα' : 'Subject',
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.brand.inputFill
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedSubject != null
                                    ? context.brand.primaryPurple.withValues(
                                        alpha: 0.4,
                                      )
                                    : context.brand.neutralGrey.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.book_outlined,
                                  color: _selectedSubject != null
                                      ? context.brand.primaryPurple
                                      : context.brand.neutralGrey,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedSubject ??
                                        (lang == 'el'
                                            ? 'Επιλέξτε μάθημα...'
                                            : 'Select subject...'),
                                    style: TextStyle(
                                      color: _selectedSubject != null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurface
                                          : context.brand.neutralGrey,
                                      fontSize: 15,
                                      fontWeight: _selectedSubject != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: context.brand.neutralGrey,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Date Picker ─────────────────────────────────────────
                        _SectionLabel(
                          label: lang == 'el'
                              ? 'Ημερομηνία Εξέτασης'
                              : 'Exam Date',
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? context.brand.inputFill
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: context.brand.primaryPurple,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  lang == 'el' ? 'Αλλαγή' : 'Change',
                                  style: TextStyle(
                                    color: context.brand.primaryPurple
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Notes ───────────────────────────────────────────────
                        _SectionLabel(
                          label: lang == 'el'
                              ? 'Σημειώσεις (Προαιρετικά)'
                              : 'Notes (Optional)',
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: lang == 'el'
                                ? 'π.χ. Κεφάλαια 1-5, Ορισμοί...'
                                : 'e.g. Chapters 1-5...',
                            hintStyle: TextStyle(
                              color: context.brand.neutralGrey.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? context.brand.inputFill
                                : Colors.white.withValues(alpha: 0.85),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: context.brand.primaryPurple,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Submit Button ────────────────────────────────────────
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.brand.primaryPurple,
                                const Color(0xFF7C6EF0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: context.brand.primaryPurple.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _isLoading ? null : _submit,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        lang == 'el'
                                            ? 'Προσθήκη Εξέτασης'
                                            : 'Add Exam',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.brand.darkText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
