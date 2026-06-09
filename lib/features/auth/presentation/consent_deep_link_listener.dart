import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';

bool isParentalConsentDeepLink(Uri uri) {
  if (uri.scheme == 'scholilink' && uri.host == 'consent') {
    return true;
  }
  if (uri.scheme == 'https' &&
      uri.host == 'student-dashboard-greece.web.app' &&
      uri.path.contains('consent')) {
    return true;
  }
  return false;
}

class ConsentDeepLinkListener extends ConsumerStatefulWidget {
  const ConsentDeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConsentDeepLinkListener> createState() =>
      _ConsentDeepLinkListenerState();
}

class _ConsentDeepLinkListenerState
    extends ConsumerState<ConsentDeepLinkListener> {
  late final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initLinks();
  }

  Future<void> _initLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && mounted) {
        await _handleUri(initial);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ConsentDeepLink initial link: $e\n$st');
      }
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) _handleUri(uri);
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('ConsentDeepLink stream: $e\n$st');
        }
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    if (!isParentalConsentDeepLink(uri)) return;

    final uid = uri.queryParameters['uid']?.trim();
    final token = uri.queryParameters['token']?.trim();
    if (uid == null || uid.isEmpty || token == null || token.isEmpty) {
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message:
              'Sign in as the student account that requested consent, then open the link again.',
          type: SnackBarType.warning,
        );
      }
      return;
    }

    final ok = await ref
        .read(authRepositoryProvider)
        .verifyParentalConsent(uid: uid, token: token);

    if (!mounted) return;
    if (ok) {
      CustomSnackBar.show(
        context: context,
        message: 'Parental consent confirmed. AI features are unlocked.',
        type: SnackBarType.success,
      );
    } else {
      CustomSnackBar.show(
        context: context,
        message:
            'Could not confirm consent. The link may be invalid or expired.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
