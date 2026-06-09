import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/firebase_functions_helpers.dart';

class EmailService {
  static const String _baseUrl =
      'https://student-dashboard-greece.web.app/consent.html';

  /// Sends parental consent email via Cloud Function (EmailJS secrets stay on the server).
  static Future<bool> sendConsentEmail({
    required String parentEmail,
    required String studentName,
    required String token,
    required String uid,
    required String lang,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('EmailJS: Sending consent request via Cloud Function');
      }

      await refreshAuthTokenForCallable();
      final callable =
          FirebaseFunctions.instanceFor(
            app: Firebase.app(),
            region: 'us-central1',
          ).httpsCallable(
            'sendParentalConsentEmail',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          );

      await callable.call({
        'parentEmail': parentEmail,
        'studentName': studentName,
        'token': token,
        'uid': uid,
        'lang': lang,
      });

      if (kDebugMode) {
        debugPrint('EmailJS: consent request completed');
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('EmailJS Cloud Function (${e.code}): ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Email Service Exception: $e');
      }
    }

    if (kDebugMode) {
      debugPrint('EmailJS: Falling back to local mail app...');
    }
    return await sendViaMailApp(
      parentEmail: parentEmail,
      studentName: studentName,
      token: token,
      uid: uid,
      lang: lang,
    );
  }

  static String _buildApprovalLink(
    String studentName,
    String token,
    String uid,
  ) {
    final String encodedName = Uri.encodeComponent(studentName);
    return '$_baseUrl?uid=$uid&token=$token&name=$encodedName';
  }

  /// Original mailto logic as a robust fallback
  static Future<bool> sendViaMailApp({
    required String parentEmail,
    required String studentName,
    required String token,
    required String uid,
    required String lang,
  }) async {
    final String approvalLink = _buildApprovalLink(studentName, token, uid);

    final subject = Uri.encodeComponent(
      lang == 'el'
          ? 'Αίτημα Γονικής Συναίνεσης - ScholiLink'
          : 'Parental Consent Request - ScholiLink',
    );

    final body = Uri.encodeComponent(
      lang == 'el'
          ? 'Γεια σας,\n\n$studentName χρησιμοποιεί το ScholiLink και χρειάζεται τη γονική σας συναίνεση για τη χρήση λειτουργιών τεχνητής νοημοσύνης.\n\nΓια να εγκρίνετε το αίτημα, παρακαλούμε πατήστε στον παρακάτω σύνδεσμο:\n\n🔗 Σύνδεσμος Έγκρισης:\n$approvalLink\n\nΜε εκτίμηση,\nΗ Ομάδα ScholiLink'
          : 'Dear Parent/Guardian,\n\n$studentName is using ScholiLink and requires your parental consent to use AI features.\n\nTo approve this request, please click the link below:\n\n🔗 Approval Link:\n$approvalLink\n\nKind regards,\nThe ScholiLink Team',
    );

    final mailtoUri = Uri.parse(
      'mailto:$parentEmail?subject=$subject&body=$body',
    );

    if (await canLaunchUrl(mailtoUri)) {
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
