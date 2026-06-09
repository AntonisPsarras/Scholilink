import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/exam_model.dart';
import '../domain/deadline_model.dart';

class DeviceCalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin;

  DeviceCalendarService() : _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<bool> _requestPermissions() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && (permissionsGranted.data == false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess ||
            (permissionsGranted.data == false)) {
          return false;
        }
      }
      return permissionsGranted.isSuccess && (permissionsGranted.data == true);
    } catch (e) {
      return false;
    }
  }

  Future<Calendar?> _getDefaultCalendar() async {
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess &&
        calendarsResult.data != null &&
        calendarsResult.data!.isNotEmpty) {
      // Prioritize primary/default calendars
      final calendars = calendarsResult.data!;

      // 1. Check for explicit isDefault
      try {
        return calendars.firstWhere(
          (c) => c.isDefault == true && c.isReadOnly == false,
        );
      } catch (_) {}

      // 2. Look for "primary" in account name (common for Google)
      try {
        return calendars.firstWhere(
          (c) =>
              (c.accountName?.toLowerCase().contains('gmail') ?? false) &&
              c.isReadOnly == false,
        );
      } catch (_) {}

      // 3. Fallback to first writable
      try {
        return calendars.firstWhere((c) => c.isReadOnly == false);
      } catch (_) {}
    }
    return null;
  }

  Future<bool> syncExamToCalendar(
    Exam exam, {
    String? localizedTitle,
    String? localizedDescription,
  }) async {
    if (!await _requestPermissions()) return false;

    final calendar = await _getDefaultCalendar();
    if (calendar == null || calendar.id == null) return false;

    final eventToCreate = Event(
      calendar.id,
      title: localizedTitle ?? 'Διαγώνισμα: ${exam.subject}',
      description:
          localizedDescription ??
          (exam.description.isNotEmpty
              ? exam.description
              : 'Προστέθηκε από το ScholiLink'),
      start: tz.TZDateTime.from(exam.date, tz.local),
      end: tz.TZDateTime.from(
        exam.date.add(const Duration(hours: 1)),
        tz.local,
      ),
      allDay: true,
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(
      eventToCreate,
    );
    return result?.isSuccess == true;
  }

  Future<bool> syncDeadlineToCalendar(
    Deadline deadline, {
    String? localizedTitle,
    String? localizedDescription,
  }) async {
    if (!await _requestPermissions()) return false;

    final calendar = await _getDefaultCalendar();
    if (calendar == null || calendar.id == null) return false;

    final eventToCreate = Event(
      calendar.id,
      title:
          localizedTitle ??
          '${deadline.isPresentation ? 'Παρουσίαση' : 'Project'}: ${deadline.title}',
      description:
          localizedDescription ??
          'Μάθημα: ${deadline.subject}\n\n${deadline.description}',
      start: tz.TZDateTime.from(deadline.date, tz.local),
      end: tz.TZDateTime.from(
        deadline.date.add(const Duration(hours: 1)),
        tz.local,
      ),
      allDay: true,
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(
      eventToCreate,
    );
    return result?.isSuccess == true;
  }
}

final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});
