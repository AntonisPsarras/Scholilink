import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import '../domain/exam_model.dart';
import '../domain/deadline_model.dart';

/// Google Calendar REST API integration using the user's existing Google Sign-In token.
/// No extra login popup needed when the user is already signed in with Google.
/// If not signed in with Google (email/password), it triggers an incremental sign-in.
class GoogleCalendarService {
  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';
  static const String _eventsEndpoint =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  /// One [GoogleSignIn] for silent sign-in, interactive sign-in, and [showConnectDialog].
  static GoogleSignIn? _googleSignInCache;
  static bool _googleSignInInitialized = false;

  static Future<GoogleSignIn> _googleSignIn() async {
    final signIn = _googleSignInCache ??= GoogleSignIn.instance;
    if (!_googleSignInInitialized) {
      await signIn.initialize(
        // Pass clientId explicitly on web to avoid the meta-tag assertion.
        clientId: kIsWeb ? Config.googleClientId : null,
      );
      _googleSignInInitialized = true;
    }
    return signIn;
  }

  /// Calendar API all-day events use an exclusive [end.date] (day after the event day).
  static String _exclusiveEndDateString(DateTime localDate) {
    final start = DateTime(localDate.year, localDate.month, localDate.day);
    return _toDateStringStatic(start.add(const Duration(days: 1)));
  }

  static String _toDateStringStatic(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Ensures the user is signed in with Google AND has Calendar scope granted.
  /// Returns the access token, or null if the user declined.
  Future<String?> _getAccessToken(BuildContext context) async {
    try {
      final signIn = await _googleSignIn();
      // Try lightweight auth first (already authenticated / low-friction).
      GoogleSignInAccount? account = await signIn
          .attemptLightweightAuthentication();
      account ??= await signIn.authenticate(scopeHint: const [_calendarScope]);
      final signedInAccount = account;

      final headers = await signedInAccount.authorizationClient
          .authorizationHeaders(const <String>[
            _calendarScope,
          ], promptIfNecessary: true);
      final authHeader = headers?['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        if (kDebugMode) {
          debugPrint(
            'GoogleCalendarService: authorization header missing after sign-in',
          );
        }
        return null;
      }
      return authHeader.substring('Bearer '.length);
    } catch (e) {
      debugPrint('GoogleCalendarService: sign-in error: $e');
      return null;
    }
  }

  /// Creates a Google Calendar event for an exam.
  /// Returns true if successful.
  Future<bool> syncExamToCalendar(Exam exam, BuildContext context) async {
    final token = await _getAccessToken(context);
    if (token == null) return false;

    final startStr = _toDateString(exam.date);
    final endStr = _exclusiveEndDateString(exam.date);
    final body = {
      'summary': 'Διαγώνισμα: ${exam.subject}',
      'description': exam.description.isNotEmpty
          ? exam.description
          : 'Προστέθηκε από το ScholiLink',
      'start': {'date': startStr, 'timeZone': 'Europe/Athens'},
      'end': {'date': endStr, 'timeZone': 'Europe/Athens'},
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 1440}, // 1 day before
          {'method': 'popup', 'minutes': 60}, // 1 hour before
        ],
      },
    };

    return await _postEvent(token, body);
  }

  /// Creates a Google Calendar event for a deadline (project/presentation).
  /// Returns true if successful.
  Future<bool> syncDeadlineToCalendar(
    Deadline deadline,
    BuildContext context,
  ) async {
    final token = await _getAccessToken(context);
    if (token == null) return false;

    final startStr = _toDateString(deadline.date);
    final endStr = _exclusiveEndDateString(deadline.date);
    final typeLabel = deadline.isPresentation ? 'Παρουσίαση' : 'Project';
    final body = {
      'summary': '$typeLabel: ${deadline.title}',
      'description': 'Μάθημα: ${deadline.subject}\n${deadline.description}',
      'start': {'date': startStr, 'timeZone': 'Europe/Athens'},
      'end': {'date': endStr, 'timeZone': 'Europe/Athens'},
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 1440}, // 1 day before
          {'method': 'popup', 'minutes': 60},
        ],
      },
    };

    return await _postEvent(token, body);
  }

  Future<bool> _postEvent(String accessToken, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_eventsEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        if (kDebugMode) {
          debugPrint(
            'GoogleCalendarService: error ${response.statusCode} ${response.body}',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('GoogleCalendarService: HTTP error: $e');
      return false;
    }
  }

  String _toDateString(DateTime date) => _toDateStringStatic(date);

  /// Shows a dialog explaining that Calendar access is needed, then triggers sign-in.
  /// Call this when the user first enables the sync toggle.
  static Future<bool> showConnectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.calendar_today, color: Color(0xFF4285F4), size: 24),
            SizedBox(width: 12),
            Text(
              'Google Calendar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Το ScholiLink θα αποθηκεύει διαγωνίσματα και προθεσμίες στο Google Calendar σου, '
          'ώστε να λαμβάνεις υπενθυμίσεις απευθείας στο τηλέφωνό σου.\n\n'
          'Θα σου ζητηθεί να επιλέξεις τον λογαριασμό Google που θέλεις να συνδέσεις.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Σύνδεση'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    // Actually trigger sign-in with calendar scope (same instance as sync methods)
    try {
      final signIn = await _googleSignIn();
      await signIn.authenticate(scopeHint: const [_calendarScope]);
      return true;
    } catch (e) {
      debugPrint('GoogleCalendarService: connect error: $e');
      return false;
    }
  }
}

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService();
});
