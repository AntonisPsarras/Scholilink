import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/responsive_layout.dart';
import '../../../core/spark_sync.dart';
import '../../../features/auth/data/auth_repository.dart';

class UpgradeProScreen extends ConsumerStatefulWidget {
  const UpgradeProScreen({super.key});

  @override
  ConsumerState<UpgradeProScreen> createState() => _UpgradeProScreenState();
}

class _UpgradeProScreenState extends ConsumerState<UpgradeProScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  int _step = 1;
  bool _sending = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _callableMessage(dynamic e, String fallback) {
    if (e is FirebaseFunctionsException) return e.message ?? fallback;
    return fallback;
  }

  Future<void> _submitSend() async {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    final trimmed = _emailController.text.trim();
    if (!trimmed.contains('@')) {
      CustomSnackBar.show(
        context: context,
        message: 'Βάλε ένα έγκυρο email.',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final alreadyPro = await repo.sendProActivationCode(trimmed);
      await syncSparkStatusFromServer(ref);
      if (!mounted) return;
      if (alreadyPro) {
        CustomSnackBar.show(
          context: context,
          message: 'Ο λογαριασμός έχει ήδη ScholiLink Pro.',
          type: SnackBarType.info,
        );
        Navigator.of(context).pop();
      } else {
        CustomSnackBar.show(
          context: context,
          message: 'Ο κωδικός εστάλη. Δες τα εισερχόμενά σου ή το φάκελο spam.',
          type: SnackBarType.success,
        );
        setState(() {
          _step = 2;
          _codeController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context: context,
        message: _callableMessage(e, 'Αποστολή δεν ήταν δυνατή.'),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitUnlock() async {
    if (_unlocking) return;
    FocusScope.of(context).unfocus();
    final digits = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      CustomSnackBar.show(
        context: context,
        message: 'Βάλε τον 6ψήφιο κωδικό από το email σου.',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _unlocking = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final skippedRedeem = await repo.verifyProActivationAndUnlock(digits);
      await syncSparkStatusFromServer(ref);
      if (!mounted) return;
      CustomSnackBar.show(
        context: context,
        message: skippedRedeem
            ? 'Ο λογαριασμός είχε ήδη ενεργό το Pro.'
            : 'Το ScholiLink Pro ενεργοποιήθηκε!',
        type: SnackBarType.success,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context: context,
        message: _callableMessage(e, 'Η επιβεβαίωση απέτυχε.'),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Widget _buildActivationFlow(BuildContext context) {
    final brand = context.brand;
    final muted = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: brand.neutralGrey,
    );

    if (_step == 1) {
      return GlassContainer(
        animate: false,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ξεκλείδωμα με email',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: brand.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Βάλε το email που χρησιμοποιείς στο λογαριασμό ScholiLink. Θα σου στείλουμε μοναδικό κωδικό.',
              style: muted,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                hintText: 'το email του λογαριασμού σου',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _gradientButton(
              context,
              label: _sending ? 'Γίνεται αποστολή…' : 'Αποστολή κωδικού',
              loading: _sending,
              onTap: _submitSend,
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      animate: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Βάλε τον κωδικό',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: brand.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ο 6ψήφιος κωδικός ήρθε στο email σας. Ο κωδικός λήγει σε 15 λεπτά.',
            style: muted,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
              hintText: '123456',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _gradientButton(
            context,
            label: _unlocking ? 'Επαλήθευση…' : 'Ξεκλείδωσε το Pro',
            loading: _unlocking,
            onTap: _submitUnlock,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _unlocking
                ? null
                : () {
                    setState(() {
                      _step = 1;
                      _codeController.clear();
                    });
                  },
            child: Text(
              'Επιστροφή στην αλλαγή email',
              style: TextStyle(
                color: brand.royalLavender,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientButton(
    BuildContext context, {
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return LiquidTouch(
      onTap: loading ? () {} : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.brand.royalLavender, const Color(0xFFB1A2FB)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: context.brand.royalLavender.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'ScholiLink Pro',
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: context.brand.darkText),
        ),
        body: isDesktop
            ? _buildDesktopBody(context)
            : _buildMobileBody(context),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 80,
              color: context.brand.royalLavender,
            ),
            const SizedBox(height: 16),
            Text(
              'Γίνε PRO. Απογείωσε το διάβασμά σου.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.brand.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ξεκλείδωσε έως 500 AI Sparks την ημέρα, προηγμένα στατιστικά και πολλά άλλα.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: context.brand.neutralGrey),
            ),
            const SizedBox(height: 32),
            const GlassContainer(
              animate: false,
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  _FeatureRow(
                    icon: Icons.auto_awesome,
                    title: '500 AI Sparks την ημέρα',
                    description:
                        'Πολύ μεγαλύτερο ημερήσιο όριο από το δωρεάν πλάνο για τον AI Βοηθό και τις Έξυπνες Σημειώσεις.',
                  ),
                  Divider(height: 32),
                  _FeatureRow(
                    icon: Icons.analytics,
                    title: 'Προηγμένα Στατιστικά',
                    description:
                        'Δες ακριβώς πού υστερείς και πού υπερέχεις με αναλυτικά charts βαθμολογιών.',
                  ),
                  Divider(height: 32),
                  _FeatureRow(
                    icon: Icons.notifications_active,
                    title: 'Έξυπνες Ειδοποιήσεις',
                    description:
                        'Έξυπνες υπενθυμίσεις διαβάσματος για να μην ξεχάσεις ποτέ ξανά deadline.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildActivationFlow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.workspace_premium,
                  size: 72,
                  color: context.brand.royalLavender,
                ),
                const SizedBox(height: 16),
                Text(
                  'Γίνε PRO. Απογείωσε το διάβασμά σου.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.brand.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ξεκλείδωσε όλα τα δυνατά εργαλεία που χρειάζεσαι για να πετύχεις.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.brand.neutralGrey,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GlassContainer(
                        animate: false,
                        padding: const EdgeInsets.all(24),
                        borderRadius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.brand.neutralGrey.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Δωρεάν',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: context.brand.neutralGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Βασικά',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: context.brand.darkText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                            _planFeatureRow(
                              context,
                              '25 AI Sparks την ημέρα',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'AI Βοηθός (βασικός)',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Έξυπνες Σημειώσεις (βασικές)',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Πρόγραμμα & εξετάσεις',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Βαθμολογίες',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              '500 AI Sparks την ημέρα',
                              included: false,
                            ),
                            _planFeatureRow(
                              context,
                              'Προηγμένα Στατιστικά',
                              included: false,
                            ),
                            _planFeatureRow(
                              context,
                              'Έξυπνες Ειδοποιήσεις',
                              included: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: GlassContainer(
                        animate: false,
                        padding: const EdgeInsets.all(24),
                        borderRadius: 24,
                        backgroundColor: context.brand.royalLavender.withValues(
                          alpha: 0.08,
                        ),
                        border: Border.all(
                          color: context.brand.royalLavender.withValues(
                            alpha: 0.4,
                          ),
                          width: 1.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.brand.royalLavender,
                                        const Color(0xFFB1A2FB),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.workspace_premium,
                                  color: context.brand.royalLavender,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ξεκλείδωμα με κωδικό',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: context.brand.darkText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                            _planFeatureRow(
                              context,
                              '25 AI Sparks την ημέρα',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'AI Βοηθός (βασικός)',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Έξυπνες Σημειώσεις (βασικές)',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Πρόγραμμα & εξετάσεις',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Βαθμολογίες',
                              included: true,
                            ),
                            _planFeatureRow(
                              context,
                              '500 AI Sparks την ημέρα',
                              included: true,
                              highlight: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Προηγμένα Στατιστικά',
                              included: true,
                              highlight: true,
                            ),
                            _planFeatureRow(
                              context,
                              'Έξυπνες Ειδοποιήσεις',
                              included: true,
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const GlassContainer(
                  animate: false,
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _FeatureRow(
                        icon: Icons.auto_awesome,
                        title: '500 AI Sparks την ημέρα',
                        description:
                            'Πολύ μεγαλύτερο ημερήσιο όριο από το δωρεάν πλάνο για τον AI Βοηθό και τις Έξυπνες Σημειώσεις.',
                      ),
                      Divider(height: 32),
                      _FeatureRow(
                        icon: Icons.analytics,
                        title: 'Προηγμένα Στατιστικά',
                        description:
                            'Δες ακριβώς πού υστερείς και πού υπερέχεις με αναλυτικά charts βαθμολογιών.',
                      ),
                      Divider(height: 32),
                      _FeatureRow(
                        icon: Icons.notifications_active,
                        title: 'Έξυπνες Ειδοποιήσεις',
                        description:
                            'Έξυπνες υπενθυμίσεις διαβάσματος για να μην ξεχάσεις ποτέ ξανά deadline.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildActivationFlow(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _planFeatureRow(
    BuildContext context,
    String label, {
    required bool included,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18,
            color: included
                ? (highlight
                      ? context.brand.royalLavender
                      : context.brand.mintSuccess)
                : context.brand.neutralGrey.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: included
                    ? context.brand.darkText
                    : context.brand.neutralGrey.withValues(alpha: 0.5),
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.brand.royalLavender.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: context.brand.royalLavender),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: context.brand.neutralGrey, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
