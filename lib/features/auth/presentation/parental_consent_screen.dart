import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/l10n.dart';
import '../data/auth_repository.dart';
import '../domain/parental_consent_eligibility.dart';
import 'parental_consent_providers.dart';

class ParentalConsentScreen extends ConsumerStatefulWidget {
  const ParentalConsentScreen({super.key});

  @override
  ConsumerState<ParentalConsentScreen> createState() =>
      _ParentalConsentScreenState();
}

class _ParentalConsentScreenState extends ConsumerState<ParentalConsentScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestConsent(String lang, {String? targetEmail}) async {
    final s = S(lang);
    final email = targetEmail ?? _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      CustomSnackBar.show(
        context: context,
        message: s.invalidEmail,
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestParentalConsent(email, lang: lang);

      ref.read(parentalConsentUiProvider.notifier).startResendCooldown();

      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Το αίτημα στάλθηκε! Ενημερώστε τον γονέα σας να ελέγξει τα εισερχόμενά του.'
              : 'Request sent! Please ask your parent to check their inbox.',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Αποτυχία αποστολής. Δοκιμάστε ξανά.'
              : 'Could not send request. Please try again.',
          type: SnackBarType.error,
        );
      }
      if (kDebugMode) {
        debugPrint('requestParentalConsent: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetConsent(String lang) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetParentalConsent();
      _emailController.clear();
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Μπορείτε τώρα να εισάγετε διαφορετικό email.'
              : 'You can now enter a different email.',
          type: SnackBarType.info,
        );
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
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    if (user.hasParentalConsent || !requiresParentalAiGate(user)) {
      return const SizedBox.shrink();
    }

    final lang = user.preferredLanguage;
    final s = S(lang);
    final isPending = user.consentVerificationStatus == 'pending';
    final ui = ref.watch(parentalConsentUiProvider);
    final canResend = ui.canResend;

    return GlassContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.1).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Icon(
              isPending
                  ? Icons.mark_email_unread_rounded
                  : Icons.admin_panel_settings_rounded,
              size: 64,
              color: isPending
                  ? context.brand.sunsetWarning
                  : context.brand.primaryPurple,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isPending
                ? (lang == 'el' ? 'Αναμονή Έγκρισης' : 'Waiting for Approval')
                : s.parentalConsentRequired,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.brand.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isPending
                ? (lang == 'el'
                      ? 'Ένας σύνδεσμος έγκρισης έχει σταλεί στο email του γονέα σας. Μόλις τον πατήσουν, η πρόσβαση AI θα ενεργοποιηθεί αυτόματα.'
                      : 'An approval link has been sent to your parent\'s email. Once they click it, AI access will be enabled automatically.')
                : '${s.parentalConsentDesc}\n\n${s.parentalConsentPrompt}',
            style: TextStyle(
              fontSize: 16,
              color: context.brand.darkText.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!isPending) ...[
            CustomTextField(
              controller: _emailController,
              hintText: lang == 'el' ? 'Email Γονέα' : 'Parent Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            CustomButton(
              onPressed: () {
                if (_isLoading) return;
                _requestConsent(lang);
              },
              text: lang == 'el' ? 'Αποστολή Συνδέσμου' : 'Send Approval Link',
              isLoading: _isLoading,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.brand.sunsetWarning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.brand.sunsetWarning.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: context.brand.sunsetWarning,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.parentEmail ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.brand.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang == 'el' ? 'Εκκρεμεί η έγκριση' : 'Approval pending',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.brand.sunsetWarning.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              onPressed: () {
                if (_isLoading || !canResend) return;
                _requestConsent(lang, targetEmail: user.parentEmail);
              },
              text: canResend
                  ? (lang == 'el' ? 'Επαναποστολή Συνδέσμου' : 'Resend Link')
                  : (lang == 'el'
                        ? 'Επαναποστολή (${ui.resendCooldownSeconds}s)'
                        : 'Resend (${ui.resendCooldownSeconds}s)'),
              isLoading: _isLoading,
              backgroundColor: context.brand.primaryPurple,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : () => _resetConsent(lang),
              child: Text(
                lang == 'el' ? 'Χρήση άλλου Email' : 'Use different Email',
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
