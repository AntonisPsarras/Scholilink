import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/custom_snackbar.dart';

import '../data/dashboard_logic.dart'; // For converting slots to data and cache invalidation

/// Standard Greek school hour times (Start - End).
const _hourTimes = [
  '08:15 - 09:00',
  '09:05 - 09:50',
  '10:00 - 10:45',
  '10:55 - 11:40',
  '11:50 - 12:35',
  '12:40 - 13:25',
  '13:30 - 14:10',
];
const _totalHours = 7;

// Removed fixed tutoring times as they are now dynamic.

const _weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  final List<String>? subjectOverrides;
  final List<String>? tutoringSubjectOverrides;
  final bool onboardingMode;

  const ScheduleEditorScreen({
    super.key,
    this.subjectOverrides,
    this.tutoringSubjectOverrides,
    this.onboardingMode = false,
  });

  @override
  ConsumerState<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDayIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  // Permanent schedule: dayName → list of 7 slots (null means empty)
  final Map<String, List<String?>> _permanentSlots = {};

  // Tutoring schedule: dayName → list of dynamic slots {subject: String, time: String}
  final Map<String, List<Map<String, dynamic>>> _tutoringSlots = {};

  // Temporary schedules from Firestore
  List<Map<String, dynamic>> _temporarySchedules = [];

  @override
  void initState() {
    super.initState();
    _initSlots();
    _loadSchedule();
  }

  void _initSlots() {
    for (final day in _weekDays) {
      _permanentSlots[day] = List.filled(_totalHours, null);
      _tutoringSlots[day] = [];
    }
  }

  Future<void> _loadSchedule() async {
    final user = ref.read(authStateProvider).value;
    if (user != null && user.currentClass != null) {
      final repo = ref.read(dashboardRepositoryProvider);
      final schedule = await repo.getSchedule(user.currentClass!);
      final temps = await repo.getTemporarySchedules(user.currentClass!);

      // Parse permanent schedule into slots
      for (final dayData in schedule) {
        final dayName = dayData['dayName'] as String?;
        if (dayName == null || !_permanentSlots.containsKey(dayName)) continue;
        final classes = List<Map<String, dynamic>>.from(
          dayData['classes'] ?? [],
        );

        // Try to map classes to hour slots by time
        for (final c in classes) {
          final time = c['time'] as String? ?? '';
          final subjectValue = c['subject'] as String? ?? '';
          final hourIndex = _hourTimes.indexOf(time);
          if (hourIndex != -1) {
            _permanentSlots[dayName]![hourIndex] = subjectValue;
          } else {
            // It's a tutoring/extra slot
            if (subjectValue.isNotEmpty) {
              // Support both legacy single string and new & separated format
              final subs = subjectValue
                  .split(' & ')
                  .where((s) => s.isNotEmpty)
                  .toList();
              _tutoringSlots[dayName]?.add({'subjects': subs, 'time': time});
            }
          }
        }
      }

      setState(() {
        _temporarySchedules = temps;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _slotsToScheduleData(
    Map<String, List<String?>> slots, {
    Map<String, List<Map<String, dynamic>>>? tutoring,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final day in _weekDays) {
      final classes = <Map<String, dynamic>>[];
      final hourSlots = slots[day] ?? List.filled(_totalHours, null);
      for (int i = 0; i < _totalHours; i++) {
        if (hourSlots[i] != null && hourSlots[i]!.isNotEmpty) {
          classes.add({
            'subject': hourSlots[i],
            'time': _hourTimes[i],
            'room': '',
            'type': 'school', // Explicitly categorization
          });
        }
      }
      // Add tutoring slots
      if (tutoring != null && tutoring[day] != null) {
        final tutSlots = tutoring[day]!;
        for (final slot in tutSlots) {
          final List<String> subjects = List<String>.from(
            slot['subjects'] ?? [],
          );
          classes.add({
            'subject': subjects.join(' & '),
            'time': slot['time'],
            'room': '',
            'type': 'frontistirio', // Categorization
          });
        }
      }
      if (classes.isNotEmpty) {
        result.add({'dayName': day, 'classes': classes});
      }
    }
    return result;
  }

  Future<void> _savePermanent() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.currentClass == null) return;

    await ref
        .read(dashboardRepositoryProvider)
        .saveSchedule(
          user.currentClass!,
          _slotsToScheduleData(_permanentSlots, tutoring: _tutoringSlots),
        );

    // Invalidate cache so schedule tab updates
    ref.invalidate(scheduleProvider(user.currentClass!));
    ref.invalidate(activeScheduleInfoProvider(user.currentClass!));

    if (mounted) {
      setState(() => _isSaving = false);
      CustomSnackBar.show(
        context: context,
        message: S(user.preferredLanguage).saveSchedule,
        type: SnackBarType.success,
      );
      Navigator.pop(context);
    }
  }

  void _showTemporaryDialog() {
    final user = ref.read(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final subjects = _effectiveSubjects(user);

    // Initialize temp slots from permanent (pre-fill)
    final tempSlots = <String, List<String?>>{};
    for (final day in _weekDays) {
      tempSlots[day] = List<String?>.from(
        _permanentSlots[day] ?? List.filled(_totalHours, null),
      );
    }

    DateTime? expiresAt;
    final labelController = TextEditingController();
    int tempDayIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dayName = _weekDays[tempDayIndex];

          String dayLabel(int i) {
            switch (i) {
              case 0:
                return s.monday;
              case 1:
                return s.tuesday;
              case 2:
                return s.wednesday;
              case 3:
                return s.thursday;
              case 4:
                return s.friday;
              default:
                return '';
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.temporarySchedule,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Label
                          TextField(
                            controller: labelController,
                            decoration: InputDecoration(
                              labelText: s.scheduleLabel,
                              hintText: s.lang == 'el'
                                  ? 'π.χ. Εβδομάδα εξετάσεων'
                                  : 'e.g. Exam week',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Expiry date
                          Row(
                            children: [
                              Text(
                                '${s.expiresOn}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 7),
                                      ),
                                      firstDate: DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => expiresAt = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: context.brand.neutralGrey,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      expiresAt != null
                                          ? '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                                          : (s.lang == 'el'
                                                ? 'Επιλέξτε ημερομηνία'
                                                : 'Select date'),
                                      style: TextStyle(
                                        color: expiresAt != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : context.brand.neutralGrey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Day tabs
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                5,
                                (i) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: ChoiceChip(
                                    label: Text(
                                      dayLabel(i),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tempDayIndex == i
                                            ? Colors.white
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    selected: tempDayIndex == i,
                                    onSelected: (v) {
                                      if (v) {
                                        setDialogState(() => tempDayIndex = i);
                                      }
                                    },
                                    selectedColor: context.brand.royalLavender,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Hour slots (scrollable)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _totalHours,
                              itemBuilder: (_, hour) {
                                final sub = tempSlots[dayName]![hour];
                                return _HourSlotTile(
                                  hour: hour,
                                  subject: sub,
                                  s: s,
                                  onTap: () async {
                                    final picked =
                                        await showSubjectPickerDialog(
                                          context: ctx,
                                          subjects: subjects,
                                          title: s.selectSubject,
                                          currentSubject: sub,
                                        );
                                    if (picked != null) {
                                      setDialogState(
                                        () =>
                                            tempSlots[dayName]![hour] = picked,
                                      );
                                    }
                                  },
                                  onClear: () => setDialogState(
                                    () => tempSlots[dayName]![hour] = null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  s.lang == 'el' ? 'Ακύρωση' : 'Cancel',
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.brand.royalLavender,
                                ),
                                onPressed: expiresAt == null
                                    ? null
                                    : () async {
                                        final classId = user?.currentClass;
                                        if (classId == null) return;
                                        Navigator.pop(ctx);
                                        await ref
                                            .read(dashboardRepositoryProvider)
                                            .saveTemporarySchedule(
                                              classId,
                                              _slotsToScheduleData(tempSlots),
                                              expiresAt!,
                                              labelController.text.isNotEmpty
                                                  ? labelController.text
                                                  : s.temporarySchedule,
                                            );
                                        // Invalidate cache
                                        ref.invalidate(
                                          scheduleProvider(classId),
                                        );
                                        ref.invalidate(
                                          activeScheduleInfoProvider(classId),
                                        );
                                        // Reload
                                        final temps = await ref
                                            .read(dashboardRepositoryProvider)
                                            .getTemporarySchedules(classId);
                                        if (mounted) {
                                          setState(
                                            () => _temporarySchedules = temps,
                                          );
                                        }
                                      },
                                child: Text(
                                  s.lang == 'el' ? 'Αποθήκευση' : 'Save',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final subjects = _effectiveSubjects(user);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dayName = _weekDays[_selectedDayIndex];

    String dayLabel(int i) {
      switch (i) {
        case 0:
          return s.monday;
        case 1:
          return s.tuesday;
        case 2:
          return s.wednesday;
        case 3:
          return s.thursday;
        case 4:
          return s.friday;
        default:
          return '';
      }
    }

    // Check for active temporary schedules
    final now = DateTime.now().millisecondsSinceEpoch;
    final activeTemps = _temporarySchedules.where((t) {
      final exp = t['expiresAt'] as int? ?? 0;
      return exp > now;
    }).toList();

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            s.manageSchedule,
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
            if (!_isLoading)
              TextButton(
                onPressed: () {
                  setState(() => _isSaving = true);
                  _savePermanent();
                },
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.brand.royalLavender,
                        ),
                      )
                    : Text(
                        s.save,
                        style: TextStyle(
                          color: context.brand.royalLavender,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Active temporary schedule banner
            if (activeTemps.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.activeTemporary,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          ...activeTemps.map((t) {
                            final exp = DateTime.fromMillisecondsSinceEpoch(
                              t['expiresAt'] as int,
                            );
                            return Text(
                              '${t['label']} — ${s.expiresOn} ${exp.day}/${exp.month}/${exp.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Temporary schedule button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: OutlinedButton.icon(
                onPressed: _showTemporaryDialog,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(s.createTemporary),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.brand.royalLavender,
                  side: BorderSide(color: context.brand.royalLavender),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    size: 16,
                    color: context.brand.royalLavender,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.permanentSchedule,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Day selector (Mon-Fri only)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(dayLabel(index)),
                      selected: _selectedDayIndex == index,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDayIndex = index);
                        }
                      },
                      selectedColor: context.brand.royalLavender,
                      labelStyle: TextStyle(
                        color: _selectedDayIndex == index
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Hour slots grid
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  // School hours (1-7)
                  for (int hour = 0; hour < _totalHours; hour++)
                    Builder(
                      builder: (_) {
                        final sub = _permanentSlots[dayName]![hour];
                        return _HourSlotTile(
                          hour: hour,
                          subject: sub,
                          s: s,
                          onTap: () async {
                            final picked = await showSubjectPickerDialog(
                              context: context,
                              subjects: subjects,
                              title: s.selectSubject,
                              currentSubject: sub,
                            );
                            if (picked != null) {
                              setState(
                                () => _permanentSlots[dayName]![hour] = picked,
                              );
                            }
                          },
                          onClear: () => setState(
                            () => _permanentSlots[dayName]![hour] = null,
                          ),
                        );
                      },
                    ),
                  // Tutoring section
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.tutoringHour,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              // Default to first tutoring subject or empty if none
                              final effectiveTutoring =
                                  _effectiveTutoringSubjects(user);
                              final defaultSub = effectiveTutoring.isNotEmpty
                                  ? effectiveTutoring.first
                                  : '';
                              _tutoringSlots[dayName]?.add({
                                'subjects': defaultSub.isNotEmpty
                                    ? [defaultSub]
                                    : <String>[],
                                'time': '16:00',
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            s.addTutoring,
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber.shade700,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tutoringSlots[dayName] != null)
                    for (int t = 0; t < _tutoringSlots[dayName]!.length; t++)
                      Builder(
                        builder: (_) {
                          final slot = _tutoringSlots[dayName]![t];
                          final tutoringSubjects = _effectiveTutoringSubjects(
                            user,
                          );
                          return _TutoringSlotTile(
                            subjects: List<String>.from(slot['subjects'] ?? []),
                            time: slot['time'],
                            s: s,
                            onAddSubject: () async {
                              final picked = await showSubjectPickerDialog(
                                context: context,
                                subjects: tutoringSubjects,
                                title: s.selectSubject,
                              );
                              if (picked != null) {
                                final current = List<String>.from(
                                  slot['subjects'] ?? [],
                                );
                                if (!current.contains(picked)) {
                                  setState(
                                    () =>
                                        slot['subjects'] = [...current, picked],
                                  );
                                }
                              }
                            },
                            onRemoveSubject: (index) {
                              final current = List<String>.from(
                                slot['subjects'] ?? [],
                              );
                              current.removeAt(index);
                              setState(() => slot['subjects'] = current);
                            },
                            onTapTime: () async {
                              final initialTimeParts = (slot['time'] as String)
                                  .split(':');
                              final initialTime = initialTimeParts.length == 2
                                  ? TimeOfDay(
                                      hour: int.parse(initialTimeParts[0]),
                                      minute: int.parse(initialTimeParts[1]),
                                    )
                                  : const TimeOfDay(hour: 16, minute: 0);

                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initialTime,
                              );

                              if (picked != null) {
                                final formatted =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                setState(
                                  () => _tutoringSlots[dayName]![t]['time'] =
                                      formatted,
                                );
                              }
                            },
                            onDelete: () => setState(
                              () => _tutoringSlots[dayName]!.removeAt(t),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _effectiveSubjects(AppUser? user) {
    if (widget.onboardingMode && widget.subjectOverrides != null) {
      return [...widget.subjectOverrides!];
    }
    return <String>[...(user?.subjects ?? [])];
  }

  List<String> _effectiveTutoringSubjects(AppUser? user) {
    if (widget.onboardingMode && widget.tutoringSubjectOverrides != null) {
      return [...widget.tutoringSubjectOverrides!];
    }
    return <String>[...(user?.tutoringSubjects ?? [])];
  }
}

/// A single hour slot tile showing the period number, time, and subject.
class _HourSlotTile extends StatelessWidget {
  final int hour;
  final String? subject;
  final S s;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _HourSlotTile({
    required this.hour,
    required this.subject,
    required this.s,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = subject == null || subject!.isEmpty;
    final displayTime = hour < _hourTimes.length ? _hourTimes[hour] : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isEmpty
            ? context.brand.neutralGrey.withValues(alpha: 0.06)
            : context.brand.royalLavender.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Hour number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isEmpty
                        ? context.brand.neutralGrey.withValues(alpha: 0.15)
                        : context.brand.royalLavender.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${hour + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isEmpty
                          ? context.brand.neutralGrey
                          : context.brand.royalLavender,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Time and subject
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final timeParts = displayTime.split(' - ');
                      return Row(
                        children: [
                          if (displayTime.isNotEmpty)
                            SizedBox(
                              width: 50,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeParts.isNotEmpty
                                        ? timeParts[0]
                                        : displayTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isEmpty
                                          ? context.brand.neutralGrey
                                          : context.brand.darkText.withValues(
                                              alpha: 0.8,
                                            ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (timeParts.length > 1) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      timeParts[1],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.brand.neutralGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (displayTime.isNotEmpty) const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEmpty ? s.tapToSetSubject : subject!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isEmpty
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    color: isEmpty
                                        ? context.brand.neutralGrey
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                // Clear button (only if filled)
                if (!isEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: context.brand.neutralGrey,
                    ),
                    onPressed: onClear,
                    tooltip: s.clearSlot,
                    visualDensity: VisualDensity.compact,
                  ),
                // Arrow indicator
                if (isEmpty)
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: context.brand.neutralGrey,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutoringSlotTile extends StatelessWidget {
  final List<String> subjects;
  final String time;
  final S s;
  final VoidCallback onAddSubject;
  final Function(int) onRemoveSubject;
  final VoidCallback onTapTime;
  final VoidCallback onDelete;

  const _TutoringSlotTile({
    required this.subjects,
    required this.time,
    required this.s,
    required this.onAddSubject,
    required this.onRemoveSubject,
    required this.onTapTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.brand.sunsetWarning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.brand.sunsetWarning.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: context.brand.sunsetWarning.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.brand.sunsetWarning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.star,
                    size: 20,
                    color: context.brand.sunsetWarning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onTapTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.selectTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: context.brand.neutralGrey,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.subject,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subjects.isNotEmpty)
                  InkWell(
                    onTap: onAddSubject,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: context.brand.sunsetWarning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s.lang == 'el' ? 'Προσθήκη' : 'Add',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.brand.sunsetWarning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (subjects.isEmpty)
              InkWell(
                onTap: onAddSubject,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle,
                        size: 18,
                        color: context.brand.sunsetWarning,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          s.lang == 'el' ? 'Προσθήκη Μαθήματος' : 'Add Subject',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.brand.sunsetWarning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(subjects.length, (index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.brand.surfaceElevated
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.brand.sunsetWarning.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subjects[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => onRemoveSubject(index),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: context.brand.neutralGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
