import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Schedule a homework reminder the night before [dueDate]. Cancels any
  /// existing notification for [homeworkId] first, then schedules if enabled.
  /// [reminderTime] uses only hour/minute; `null` means 20:00.
  Future<void> scheduleHomeworkReminder({
    required String homeworkId,
    required DateTime dueDate,
    required String subject,
    required String content,
    required String lang,
    bool reminderEnabled = true,
    DateTime? reminderTime,
  }) async {
    if (!_initialized) await initialize();

    await cancelReminder(homeworkId);
    if (!reminderEnabled) return;

    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final reminderDay = dueDay.subtract(const Duration(days: 1));

    final int h;
    final int minute;
    if (reminderTime != null) {
      h = reminderTime.hour;
      minute = reminderTime.minute;
    } else {
      h = 20;
      minute = 0;
    }

    final scheduledLocal = DateTime(
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      h,
      minute,
    );

    if (scheduledLocal.isBefore(DateTime.now())) return;

    final id = homeworkId.hashCode.abs() % 2147483647;

    final title = lang == 'el'
        ? '📚 Μην ξεχάσεις την εργασία σου!'
        : '📚 Don\'t forget your homework!';
    final body = lang == 'el'
        ? '$subject: $content — Λήξη αύριο!'
        : '$subject: $content — Due tomorrow!';

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledLocal, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'homework_reminders',
            'Homework Reminders',
            channelDescription: 'Reminders for uncompleted homework',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> showForgottenHomeworkNotification({
    required String subject,
    required String lang,
  }) async {
    if (!_initialized) await initialize();

    final id =
        DateTime.now().millisecondsSinceEpoch.hashCode.abs() % 2147483647;

    final title = lang == 'el' ? '❌ Ξεχασμένη Εργασία' : '❌ Forgotten Homework';
    final body = lang == 'el'
        ? 'Η εργασία για το μάθημα "$subject" έληξε και μεταφέρθηκε στο ιστορικό.'
        : 'The homework for "$subject" has expired and moved to history.';

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'homework_forgotten',
            'Forgotten Homework',
            channelDescription: 'Alerts for forgotten homework',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to show forgotten notification: $e');
    }
  }

  /// Cancel a homework reminder when homework is marked complete.
  Future<void> cancelReminder(String homeworkId) async {
    if (!_initialized) await initialize();
    final id = homeworkId.hashCode.abs() % 2147483647;
    await _plugin.cancel(id);
  }
}
