import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/performance_config.dart';
import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/dashboard_logic.dart';
import '../domain/exam_model.dart';
import '../domain/deadline_model.dart';

class EventCalendarWidget extends ConsumerStatefulWidget {
  final String classId;
  const EventCalendarWidget({super.key, required this.classId});

  @override
  ConsumerState<EventCalendarWidget> createState() =>
      _EventCalendarWidgetState();
}

class _EventCalendarWidgetState extends ConsumerState<EventCalendarWidget>
    with SingleTickerProviderStateMixin {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  bool _isExpanded = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  double _slideDirection = 0; // -1 for left, 1 for right

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onMonthChange(bool next) {
    setState(() {
      _slideDirection = next ? 1 : -1;
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + (next ? 1 : -1),
      );
      _fadeController.reset();
      _fadeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final examsAsync = ref.watch(examProvider(widget.classId));
    final deadlinesAsync = ref.watch(deadlineProvider(widget.classId));
    final showDeadlinesOnCalendar = ref.watch(
      authStateProvider.select(
        (async) => async.valueOrNull?.showDeadlinesOnCalendar ?? true,
      ),
    );

    return examsAsync.when(
      data: (exams) => deadlinesAsync.when(
        data: (deadlines) =>
            _buildContent(exams, deadlines, lang, showDeadlinesOnCalendar),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContent(
    List<Exam> exams,
    List<Deadline> deadlines,
    String lang,
    bool showDeadlines,
  ) {
    // Group all events by day
    final Map<DateTime, List<_CalEvent>> allEvents = {};
    for (final e in exams) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      allEvents
          .putIfAbsent(key, () => <_CalEvent>[])
          .add(
            _CalEvent(type: 'exam', subject: e.subject, title: 'Διαγώνισμα'),
          );
    }
    if (showDeadlines) {
      for (final d in deadlines) {
        final key = DateTime(d.date.year, d.date.month, d.date.day);
        allEvents
            .putIfAbsent(key, () => <_CalEvent>[])
            .add(
              _CalEvent(
                type: d.isPresentation ? 'presentation' : 'project',
                subject: d.subject,
                title: d.title,
              ),
            );
      }
    }

    final s = _selectedDay;
    final selectedEvents = s != null
        ? (allEvents[DateTime(s.year, s.month, s.day)] ?? <_CalEvent>[])
        : <_CalEvent>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          _buildHeader(lang, s, showDeadlines),
          const SizedBox(height: 16),

          // ── Calendar Grid ───────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _calendarFrostPanel(
              borderRadius: 24,
              child: Column(
                children: [
                  _buildMonthNav(lang),
                  const SizedBox(height: 4),
                  _buildWeekdayRow(lang),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _fadeAnim.drive(
                        Tween<Offset>(
                          begin: Offset(_slideDirection * 0.3, 0),
                          end: Offset.zero,
                        ),
                      ),
                      child: _buildDaysGrid(allEvents, lang),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Selected Day Events Panel ─────────────────────────────────
          if (selectedEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildEventsPanel(selectedEvents, lang),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String lang, DateTime? s, bool showDeadlines) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'el' ? 'Ημερολόγιο' : 'Calendar',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _buildDotIndicator(
                  context.brand.primaryPurple,
                  lang == 'el' ? 'Διαγωνίσματα' : 'Exams',
                ),
                if (showDeadlines) ...[
                  const SizedBox(width: 12),
                  _buildDotIndicator(
                    context.brand.sunsetWarning,
                    lang == 'el' ? 'Προθεσμίες' : 'Deadlines',
                  ),
                ],
              ],
            ),
          ],
        ),
        // Toggle Month/Week View
        IconButton(
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: context.brand.primaryPurple,
          ),
          style: IconButton.styleFrom(
            backgroundColor: context.brand.primaryPurple.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDotIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.brand.neutralGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNav(String lang) {
    final monthsEl = [
      'Ιανουάριος',
      'Φεβρουάριος',
      'Μάρτιος',
      'Απρίλιος',
      'Μάιος',
      'Ιούνιος',
      'Ιούλιος',
      'Αύγουστος',
      'Σεπτέμβριος',
      'Οκτώβριος',
      'Νοέμβριος',
      'Δεκέμβριος',
    ];
    final monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = lang == 'el'
        ? monthsEl[_focusedMonth.month - 1]
        : monthsEn[_focusedMonth.month - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _onMonthChange(false),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Text(
            '$monthName ${_focusedMonth.year}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          IconButton(
            onPressed: () => _onMonthChange(true),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(String lang) {
    final labelsEl = ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ'];
    final labelsEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final labels = lang == 'el' ? labelsEl : labelsEn;
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDaysGrid(Map<DateTime, List<_CalEvent>> allEvents, String lang) {
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rowsList = List.generate((totalCells / 7).ceil(), (index) => index);

    final targetDate = _selectedDay ?? DateTime.now();
    int targetRow = 0;
    if (targetDate.year == _focusedMonth.year &&
        targetDate.month == _focusedMonth.month) {
      final dayNum = targetDate.day;
      targetRow = ((dayNum + startOffset - 1) / 7).floor();
    } else {
      if (today.year == _focusedMonth.year &&
          today.month == _focusedMonth.month) {
        targetRow = ((today.day + startOffset - 1) / 7).floor();
      }
    }

    final displayRows = _isExpanded ? rowsList : [targetRow];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          children: displayRows.map((row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - startOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                final date = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  dayNum,
                );
                final dayKey = DateTime(date.year, date.month, date.day);
                final isToday = dayKey == todayKey;
                final isSelected = _selectedDay == dayKey;
                final dayEvents = allEvents[dayKey] ?? [];
                final hasExam = dayEvents.any((e) => e.type == 'exam');
                final hasDeadline = dayEvents.any((e) => e.type != 'exam');

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedDay = (isSelected) ? null : dayKey;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 48,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.brand.primaryPurple
                            : isToday
                            ? context.brand.primaryPurple.withValues(
                                alpha: 0.12,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                  ? context.brand.primaryPurple
                                  : context.brand.darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasExam)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : context.brand.primaryPurple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasDeadline)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white70
                                        : context.brand.sunsetWarning,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (!hasExam && !hasDeadline)
                                const SizedBox(height: 5),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEventsPanel(List<_CalEvent> events, String lang) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: _calendarFrostPanel(
        borderRadius: 20,
        panelAlpha: 0.18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                _formatSelectedDate(lang),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.brand.neutralGrey,
                ),
              ),
            ),
            ...events.map((ev) => _buildEventTile(ev, lang)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Frosted panels: full blur only when [PerformanceConfig] allows (matches app-wide blur budget).
  Widget _calendarFrostPanel({
    required double borderRadius,
    required Widget child,
    double panelAlpha = 0.15,
  }) {
    final decoration = BoxDecoration(
      color: Colors.white.withValues(alpha: panelAlpha),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    );

    if (!PerformanceConfig.useBlur) {
      return Container(decoration: decoration, child: child);
    }

    final sigma = PerformanceConfig.blurSigma <= 0
        ? 16.0
        : (PerformanceConfig.blurSigma * 16 / 15).clamp(4.0, 16.0);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Container(decoration: decoration, child: child),
    );
  }

  Widget _buildEventTile(_CalEvent ev, String lang) {
    final isExam = ev.type == 'exam';
    final color = isExam
        ? context.brand.primaryPurple
        : context.brand.sunsetWarning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ev.subject,
                  style: TextStyle(
                    color: context.brand.neutralGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSelectedDate(String lang) {
    if (_selectedDay == null) return '';
    final d = _selectedDay!;
    final monthsEl = [
      'Ιαν',
      'Φεβ',
      'Μαρ',
      'Απρ',
      'Μαι',
      'Ιουν',
      'Ιουλ',
      'Αυγ',
      'Σεπ',
      'Οκτ',
      'Νοε',
      'Δεκ',
    ];
    final monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final mName = lang == 'el' ? monthsEl[d.month - 1] : monthsEn[d.month - 1];
    return '${d.day} $mName ${d.year}';
  }
}

class _CalEvent {
  final String type;
  final String subject;
  final String title;
  _CalEvent({required this.type, required this.subject, required this.title});
}
