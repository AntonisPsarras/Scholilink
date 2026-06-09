import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/dashboard_logic.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/glass_container.dart';

/// A compact calendar widget showing the current week with exam/deadline dot indicators.
/// Dots are:
///   • Purple (exam)
///   • Orange (project/presentation deadline)
///
/// Tapping a day with events shows an event detail list below.
class SchoolCalendarWidget extends ConsumerStatefulWidget {
  final String classId;

  const SchoolCalendarWidget({super.key, required this.classId});

  @override
  ConsumerState<SchoolCalendarWidget> createState() =>
      _SchoolCalendarWidgetState();
}

class _SchoolCalendarWidgetState extends ConsumerState<SchoolCalendarWidget> {
  bool _isExpanded = false;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    // Default selected day is today
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(
      // ignore: deprecated_member_use
      authStateProvider.select((v) => v.value),
    );
    final s = S(user?.preferredLanguage ?? 'el');
    final showDeadlines = user?.showDeadlinesOnCalendar ?? true;

    // Watch calendar events (exams + optional deadlines)
    final calendarEventsAsync = ref.watch(
      calendarEventsProvider(widget.classId),
    );

    // Generate current week dates (Mon–Sun)
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final todayWeekday = now.weekday;
    final startOfWeek = now.subtract(Duration(days: todayWeekday - 1));
    final weekDates = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    // Next two weeks for expanded view
    final nextWeekDates = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: 7 + i)),
    );
    final thirdWeekDates = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: 14 + i)),
    );

    return calendarEventsAsync.when(
      loading: () => _buildCalendarShell(
        s,
        todayKey,
        weekDates,
        nextWeekDates,
        thirdWeekDates,
        {},
        showDeadlines,
        user,
      ),
      error: (_, __) => _buildCalendarShell(
        s,
        todayKey,
        weekDates,
        nextWeekDates,
        thirdWeekDates,
        {},
        showDeadlines,
        user,
      ),
      data: (events) {
        // Filter out deadline events if toggle is off
        final filteredEvents = showDeadlines
            ? events
            : Map.fromEntries(
                events.entries
                    .map(
                      (e) => MapEntry(
                        e.key,
                        e.value.where((ev) => ev['type'] == 'exam').toList(),
                      ),
                    )
                    .where((e) => e.value.isNotEmpty),
              );

        return _buildCalendarShell(
          s,
          todayKey,
          weekDates,
          nextWeekDates,
          thirdWeekDates,
          filteredEvents,
          showDeadlines,
          user,
        );
      },
    );
  }

  Widget _buildCalendarShell(
    S s,
    DateTime todayKey,
    List<DateTime> weekDates,
    List<DateTime> nextWeekDates,
    List<DateTime> thirdWeekDates,
    Map<DateTime, List<Map<String, dynamic>>> events,
    bool showDeadlines,
    dynamic user,
  ) {
    final selectedDayEvents = _selectedDay != null
        ? (events[_selectedDay!] ?? [])
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.calendar_month,
                color: context.brand.darkText,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                s.schoolCalendar,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // Legend dots
              Row(
                children: [
                  _dot(context.brand.primaryPurple),
                  const SizedBox(width: 4),
                  Text(
                    s.lang == 'el' ? 'Διαγ.' : 'Exam',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.brand.neutralGrey,
                    ),
                  ),
                  if (showDeadlines) ...[
                    const SizedBox(width: 8),
                    _dot(context.brand.sunsetWarning),
                    const SizedBox(width: 4),
                    Text(
                      s.lang == 'el' ? 'Προθ.' : 'DL',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.brand.neutralGrey,
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: context.brand.darkText,
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Week Row ─────────────────────────────────────────────────────
          _buildWeekRow(weekDates, todayKey, events, s),

          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildWeekRow(nextWeekDates, todayKey, events, s),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildWeekRow(thirdWeekDates, todayKey, events, s),
          ],

          // ── Selected Day Events ──────────────────────────────────────────
          if (selectedDayEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...selectedDayEvents.map((ev) => _buildEventTile(ev, s)),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekRow(
    List<DateTime> dates,
    DateTime todayKey,
    Map<DateTime, List<Map<String, dynamic>>> events,
    S s,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dates.map((date) {
        final dayKey = DateTime(date.year, date.month, date.day);
        final isToday = dayKey == todayKey;
        final isSelected = _selectedDay == dayKey;
        final dayEvents = events[dayKey] ?? [];
        return _buildDayWidget(date, isToday, isSelected, dayEvents, s);
      }).toList(),
    );
  }

  Widget _buildDayWidget(
    DateTime date,
    bool isToday,
    bool isSelected,
    List<Map<String, dynamic>> dayEvents,
    S s,
  ) {
    String dayLabel;
    if (s.lang == 'el') {
      const greeks = ['Δε', 'Τρ', 'Τε', 'Πε', 'Πα', 'Σα', 'Κυ'];
      dayLabel = greeks[date.weekday - 1];
    } else {
      const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dayLabel = english[date.weekday - 1];
    }

    final hasExam = dayEvents.any((e) => e['type'] == 'exam');
    final hasDeadline = dayEvents.any(
      (e) => e['type'] == 'presentation' || e['type'] == 'project',
    );

    final bg = isSelected
        ? context.brand.primaryPurple.withValues(alpha: 0.15)
        : isToday
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.transparent;

    final border = isSelected
        ? Border.all(
            color: context.brand.primaryPurple.withValues(alpha: 0.5),
            width: 1.5,
          )
        : isToday
        ? Border.all(color: Colors.white, width: 1.5)
        : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          final dayKey = DateTime(date.year, date.month, date.day);
          _selectedDay = _selectedDay == dayKey ? null : dayKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayLabel,
              style: TextStyle(
                color: isSelected || isToday
                    ? context.brand.darkText
                    : context.brand.neutralGrey,
                fontSize: 12,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? context.brand.primaryPurple
                    : context.brand.darkText,
                fontSize: isToday ? 18 : 15,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Event indicator dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasExam) _dot(context.brand.primaryPurple),
                if (hasExam && hasDeadline) const SizedBox(width: 2),
                if (hasDeadline) _dot(context.brand.sunsetWarning),
                if (!hasExam && !hasDeadline)
                  const SizedBox(width: 6, height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> ev, S s) {
    final type = ev['type'] as String;
    final title = ev['title'] as String? ?? '';
    final description = ev['description'] as String? ?? '';

    Color color;
    IconData icon;
    String typeLabel;

    if (type == 'exam') {
      color = context.brand.primaryPurple;
      icon = Icons.quiz_outlined;
      typeLabel = s.lang == 'el' ? 'Διαγώνισμα' : 'Exam';
    } else if (type == 'presentation') {
      color = context.brand.sunsetWarning;
      icon = Icons.slideshow_outlined;
      typeLabel = s.lang == 'el' ? 'Παρουσίαση' : 'Presentation';
    } else {
      color = context.brand.sunsetWarning;
      icon = Icons.assignment_outlined;
      typeLabel = 'Project';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassContainer(
        borderRadius: 14,
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$typeLabel: $title',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.brand.neutralGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
