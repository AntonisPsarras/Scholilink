import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/deadline_model.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_logic.dart';
import '../../auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../services/google_calendar_service.dart';

class DeadlineTrackerScreen extends ConsumerStatefulWidget {
  const DeadlineTrackerScreen({super.key});

  @override
  ConsumerState<DeadlineTrackerScreen> createState() =>
      _DeadlineTrackerScreenState();
}

class _DeadlineTrackerScreenState extends ConsumerState<DeadlineTrackerScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPresentation = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.darkText,
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
    final user = ref.read(authStateProvider).value;
    final lang = user?.preferredLanguage ?? 'el';

    if (_titleController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context: context,
        message: lang == 'el'
            ? 'Παρακαλώ εισάγετε τίτλο'
            : 'Please enter a title',
        type: SnackBarType.error,
      );
      return;
    }

    if (_selectedSubject == null) {
      CustomSnackBar.show(
        context: context,
        message: lang == 'el'
            ? 'Παρακαλώ επιλέξτε μάθημα'
            : 'Please select a subject',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (user != null) {
        final deadline = Deadline(
          id: '',
          title: _titleController.text.trim(),
          subject: _selectedSubject!,
          date: _selectedDate,
          description: _descriptionController.text.trim(),
          isPresentation: _isPresentation,
          classId: user.scheduleExamClassId,
        );

        await ref.read(dashboardRepositoryProvider).addDeadline(deadline);

        // Invalidate calendar provider to refresh dashboard
        ref.invalidate(calendarEventsProvider(user.scheduleExamClassId));
        ref.invalidate(deadlineProvider(user.scheduleExamClassId));

        final syncEnabled = user.syncToDeviceCalendar;
        bool synced = false;
        if (syncEnabled && mounted) {
          synced = await ref
              .read(googleCalendarServiceProvider)
              .syncDeadlineToCalendar(deadline, context);
        }

        if (mounted) {
          final s = S(user.preferredLanguage);
          String msg;
          if (s.lang == 'el') {
            msg = syncEnabled
                ? (synced
                      ? 'Η προθεσμία προστέθηκε και συγχρονίστηκε!'
                      : 'Η προθεσμία προστέθηκε (χωρίς συγχρονισμό)')
                : 'Η προθεσμία προστέθηκε!';
          } else {
            msg = syncEnabled
                ? (synced
                      ? 'Deadline added and synced!'
                      : 'Deadline added (sync failed)')
                : 'Deadline added!';
          }

          CustomSnackBar.show(
            context: context,
            message: msg,
            type: SnackBarType.success,
          );
          Navigator.pop(context);
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

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.darkText,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.lang == 'el' ? 'Νέα Προθεσμία' : 'New Deadline',
            style: const TextStyle(
              color: AppTheme.darkText,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Title ────────────────────────────────────────────────
                _SectionLabel(
                  label: s.lang == 'el'
                      ? 'Τίτλος Έργου / Παρουσίασης'
                      : 'Project / Presentation Title',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: AppTheme.darkText),
                  decoration: InputDecoration(
                    hintText: s.lang == 'el'
                        ? 'π.χ. Εργασία Ιστορίας...'
                        : 'e.g. History Project...',
                    hintStyle: TextStyle(
                      color: AppTheme.neutralGrey.withValues(alpha: 0.7),
                    ),
                    fillColor: Colors.white.withValues(alpha: 0.85),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppTheme.sunsetWarning,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Subject Picker ────────────────────────────────────────
                _SectionLabel(label: s.lang == 'el' ? 'Μάθημα' : 'Subject'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showSubjectPickerDialog(
                      context: context,
                      subjects: user?.subjects ?? [],
                      title: s.selectSubject,
                      currentSubject: _selectedSubject,
                    );
                    if (picked != null)
                      setState(() => _selectedSubject = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedSubject != null
                            ? AppTheme.sunsetWarning.withValues(alpha: 0.5)
                            : AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.book_outlined,
                          color: _selectedSubject != null
                              ? AppTheme.sunsetWarning
                              : AppTheme.neutralGrey,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedSubject ??
                                (s.lang == 'el'
                                    ? 'Επιλέξτε μάθημα...'
                                    : 'Select subject...'),
                            style: TextStyle(
                              color: _selectedSubject != null
                                  ? AppTheme.darkText
                                  : AppTheme.neutralGrey,
                              fontSize: 15,
                              fontWeight: _selectedSubject != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.neutralGrey,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Date Picker ───────────────────────────────────────────
                _SectionLabel(
                  label: s.lang == 'el'
                      ? 'Ημερομηνία Παράδοσης'
                      : 'Deadline Date',
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
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.sunsetWarning,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          s.lang == 'el' ? 'Αλλαγή' : 'Change',
                          style: TextStyle(
                            color: AppTheme.sunsetWarning.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Presentation Toggle ───────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    border: Border.all(
                      color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      s.lang == 'el' ? 'Είναι Παρουσίαση;' : 'Is Presentation?',
                    ),
                    subtitle: Text(
                      s.lang == 'el'
                          ? 'Απαιτείται ομιλία / παρουσίαση στην τάξη'
                          : 'Requires speech / presentation in class',
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: _isPresentation,
                    activeTrackColor: AppTheme.sunsetWarning.withValues(
                      alpha: 0.4,
                    ),
                    activeThumbColor: AppTheme.sunsetWarning,
                    onChanged: (val) => setState(() => _isPresentation = val),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Notes ─────────────────────────────────────────────────
                _SectionLabel(
                  label: s.lang == 'el'
                      ? 'Λεπτομέρειες (Προαιρετικά)'
                      : 'Details (Optional)',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: AppTheme.darkText),
                  decoration: InputDecoration(
                    hintText: s.lang == 'el'
                        ? 'π.χ. Σελίδες 1-10, Θέμα...'
                        : 'e.g. Pages 1-10, Topic...',
                    hintStyle: TextStyle(
                      color: AppTheme.neutralGrey.withValues(alpha: 0.7),
                    ),
                    fillColor: Colors.white.withValues(alpha: 0.85),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.neutralGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppTheme.sunsetWarning,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Submit ────────────────────────────────────────────────
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.sunsetWarning, Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.sunsetWarning.withValues(alpha: 0.35),
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
                                s.lang == 'el'
                                    ? 'Προσθήκη Προθεσμίας'
                                    : 'Add Deadline',
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
      style: const TextStyle(
        color: AppTheme.darkText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
