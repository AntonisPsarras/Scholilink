import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../data/dashboard_logic.dart';

/// Matches [ScheduleEditorScreen] canonical period slot strings (index + 1 = period number).
const kSchedulePeriodSlotTimes = [
  '08:15 - 09:00',
  '09:05 - 09:50',
  '10:00 - 10:45',
  '10:55 - 11:40',
  '11:50 - 12:35',
  '12:40 - 13:25',
  '13:30 - 14:10',
];

String _englishWeekdayFromDateTime(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    case DateTime.sunday:
      return 'Sunday';
    default:
      return 'Monday';
  }
}

Map<String, dynamic>? _dayDataForName(
  List<Map<String, dynamic>> days,
  String dayName,
) {
  for (final d in days) {
    if ((d['dayName'] as String?) == dayName) return d;
  }
  return null;
}

bool _isTutoringSlot(Map<String, String> clsMap) {
  final subjLow = (clsMap['subject'] ?? '').toLowerCase();
  final isTutoringFallback =
      subjLow.contains('φροντ') ||
      subjLow.contains('tutoring') ||
      subjLow.contains('personal') ||
      subjLow.contains('ιδιαιτ');
  final type =
      clsMap['type'] ?? (isTutoringFallback ? 'frontistirio' : 'school');
  return type == 'frontistirio';
}

int _timeToMinutes(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return 0;
  final startPart = timeStr.split(' - ').first.trim();
  final parts = startPart.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

List<Map<String, String>> _schoolClassesSorted(Map<String, dynamic>? dayData) {
  if (dayData == null) return [];
  final classes = List<Map<String, dynamic>>.from(dayData['classes'] ?? []);
  final out = <Map<String, String>>[];
  for (final c in classes) {
    final clsMap = Map<String, String>.from(
      c.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
    );
    if (_isTutoringSlot(clsMap)) continue;
    out.add(clsMap);
  }
  out.sort(
    (a, b) => _timeToMinutes(a['time']).compareTo(_timeToMinutes(b['time'])),
  );
  return out;
}

DateTime? _parseBoundaryOnDate(
  String timeRange,
  DateTime date, {
  required bool end,
}) {
  final parts = timeRange.split(' - ');
  if (parts.isEmpty) return null;
  final segment = (end && parts.length > 1 ? parts[1] : parts.first).trim();
  final hm = segment.split(':');
  if (hm.length < 2) return null;
  final h = int.tryParse(hm[0]) ?? 0;
  final m = int.tryParse(hm[1]) ?? 0;
  return DateTime(date.year, date.month, date.day, h, m);
}

class _Slot {
  const _Slot({
    required this.start,
    required this.end,
    required this.subject,
    required this.room,
    required this.periodNumber,
  });

  final DateTime start;
  final DateTime end;
  final String subject;
  final String room;
  final int periodNumber;
}

List<_Slot> _slotsForDay(
  List<Map<String, String>> schoolClasses,
  DateTime calendarDate,
) {
  final slots = <_Slot>[];
  for (final c in schoolClasses) {
    final timeStr = c['time'] ?? '';
    final start = _parseBoundaryOnDate(timeStr, calendarDate, end: false);
    final end = _parseBoundaryOnDate(timeStr, calendarDate, end: true);
    if (start == null || end == null) continue;
    final rawSubject = c['subject'] ?? '';
    final subjectParts = rawSubject
        .split(' & ')
        .where((s) => s.isNotEmpty)
        .toList();
    final subject = subjectParts.isNotEmpty ? subjectParts.first : rawSubject;
    final room = (c['room'] ?? '').trim();
    final idx = kSchedulePeriodSlotTimes.indexOf(timeStr);
    final periodNumber = idx >= 0 ? idx + 1 : 0;
    slots.add(
      _Slot(
        start: start,
        end: end,
        subject: subject,
        room: room,
        periodNumber: periodNumber,
      ),
    );
  }
  slots.sort((a, b) => a.start.compareTo(b.start));
  return slots;
}

String _formatEta(Duration d, S s) {
  if (d.isNegative) return '';
  final totalMin = d.inMinutes;
  if (s.lang != 'el') {
    if (totalMin < 1) return 'Soon';
    if (totalMin < 60) return 'In $totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (m == 0) return 'In $h h';
    return 'In ${h}h ${m}m';
  }
  if (totalMin < 1) return 'Σύντομα';
  if (totalMin < 60) return 'Σε $totalMin λεπτά';
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) {
    return h == 1 ? 'Σε 1 ώρα' : 'Σε $h ώρες';
  }
  return 'Σε $h ${h == 1 ? 'ώρα' : 'ώρες'} $m λεπτά';
}

String _weekdayTitle(DateTime date, S s) {
  switch (date.weekday) {
    case DateTime.monday:
      return s.monday;
    case DateTime.tuesday:
      return s.tuesday;
    case DateTime.wednesday:
      return s.wednesday;
    case DateTime.thursday:
      return s.thursday;
    case DateTime.friday:
      return s.friday;
    default:
      return '';
  }
}

class NextClassBannerView {
  const NextClassBannerView({
    required this.primaryLine,
    required this.secondaryLine,
  });

  final String primaryLine;
  final String secondaryLine;
}

NextClassBannerView? computeNextClassBannerView(
  List<Map<String, dynamic>> days,
  DateTime now,
  S s,
) {
  if (days.isEmpty) return null;
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
    return null;
  }

  final todayDate = DateTime(now.year, now.month, now.day);
  final todayKey = _englishWeekdayFromDateTime(now.weekday);
  final todayDay = _dayDataForName(days, todayKey);
  final todaySchool = _schoolClassesSorted(todayDay);
  final todaySlots = _slotsForDay(todaySchool, todayDate);

  for (final slot in todaySlots) {
    if (!now.isBefore(slot.start) && now.isBefore(slot.end)) {
      final roomBit = slot.room.isNotEmpty ? ' · ${slot.room}' : '';
      final head = s.lang == 'el'
          ? 'Τώρα: ${slot.subject}'
          : 'Now: ${slot.subject}';
      final periodBit = slot.periodNumber > 0
          ? s.hourLabel(slot.periodNumber)
          : '';
      return NextClassBannerView(
        primaryLine: '$head$roomBit',
        secondaryLine: periodBit,
      );
    }
  }

  for (final slot in todaySlots) {
    if (now.isBefore(slot.start)) {
      final eta = _formatEta(slot.start.difference(now), s);
      final roomBit = slot.room.isNotEmpty ? ' · ${slot.room}' : '';
      final periodBit = slot.periodNumber > 0
          ? s.hourLabel(slot.periodNumber)
          : '';
      final secondary = [if (periodBit.isNotEmpty) periodBit, eta].join(' · ');
      return NextClassBannerView(
        primaryLine: '${slot.subject}$roomBit',
        secondaryLine: secondary,
      );
    }
  }

  final calendarTomorrow = todayDate.add(const Duration(days: 1));

  for (int offset = 1; offset <= 7; offset++) {
    final d = todayDate.add(Duration(days: offset));
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      continue;
    }
    final key = _englishWeekdayFromDateTime(d.weekday);
    final dayData = _dayDataForName(days, key);
    final school = _schoolClassesSorted(dayData);
    if (school.isEmpty) continue;

    final slots = _slotsForDay(school, DateTime(d.year, d.month, d.day));
    if (slots.isEmpty) continue;

    final slot = slots.first;
    final eta = _formatEta(slot.start.difference(now), s);
    final roomBit = slot.room.isNotEmpty ? ' · ${slot.room}' : '';
    final periodBit = slot.periodNumber > 0
        ? s.hourLabel(slot.periodNumber)
        : '';

    final isCalendarTomorrow =
        d.year == calendarTomorrow.year &&
        d.month == calendarTomorrow.month &&
        d.day == calendarTomorrow.day;
    final prefix = isCalendarTomorrow
        ? (s.lang == 'el' ? 'Αύριο:' : 'Tomorrow:')
        : '${_weekdayTitle(d, s)}:';

    final secondary = [if (periodBit.isNotEmpty) periodBit, eta].join(' · ');

    return NextClassBannerView(
      primaryLine: '$prefix ${slot.subject}$roomBit',
      secondaryLine: secondary,
    );
  }

  return null;
}

/// Header banner: next class / now / tomorrow, using [activeScheduleInfoProvider].
class NextClassBanner extends ConsumerStatefulWidget {
  const NextClassBanner({super.key, required this.classId, required this.s});

  final String classId;
  final S s;

  @override
  ConsumerState<NextClassBanner> createState() => _NextClassBannerState();
}

class _NextClassBannerState extends ConsumerState<NextClassBanner> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeScheduleInfoProvider(widget.classId));
    return async.when(
      data: (bundle) {
        final view = computeNextClassBannerView(bundle.days, _now, widget.s);
        if (view == null) return const SizedBox.shrink();

        final isTemp = bundle.isTemporarySubstitution;
        final warning = Theme.of(context).brightness == Brightness.dark
            ? context.brand.sunsetWarning
            : const Color(0xFFB45309);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: 16,
            blur: 0,
            animate: false,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? context.brand.primaryPurple.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: context.brand.royalLavender.withValues(alpha: 0.22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTemp)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.s.lang == 'el'
                          ? '⚠ Αναπληρωματικό'
                          : '⚠ Substitute schedule',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: warning,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                Text(
                  view.primaryLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.brand.darkText,
                    height: 1.2,
                  ),
                ),
                if (view.secondaryLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    view.secondaryLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.brand.neutralGrey,
                      height: 1.2,
                    ),
                  ),
                ],
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
