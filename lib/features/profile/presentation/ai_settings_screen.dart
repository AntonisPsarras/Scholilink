import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai_key_store.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStoredKey();
  }

  Future<void> _loadStoredKey() async {
    final key = await ref.read(aiKeyStoreProvider).readGeminiApiKey();
    if (!mounted) return;
    _controller.text = key ?? '';
    setState(() {});
  }

  bool _looksLikeGeminiKey(String value) {
    return RegExp(r'^AIza[\w-]{20,}$').hasMatch(value.trim());
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final subscriptionType =
        ref.read(authStateProvider).valueOrNull?.subscriptionType;
    if (raw.isNotEmpty &&
        !isByokSubscriptionEligible(subscriptionType)) {
      CustomSnackBar.show(
        context: context,
        message:
            (ref.read(authStateProvider).value?.preferredLanguage ?? 'el') ==
                'el'
            ? 'Το δικό σου API key είναι διαθέσιμο μόνο σε ScholiLink Pro.'
            : 'Bring-your-own API key is available on ScholiLink Pro only.',
        type: SnackBarType.warning,
      );
      return;
    }
    if (raw.isNotEmpty && !_looksLikeGeminiKey(raw)) {
      CustomSnackBar.show(
        context: context,
        message: 'The API key format looks invalid.',
        type: SnackBarType.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final store = ref.read(aiKeyStoreProvider);
      if (raw.isEmpty) {
        await store.clearGeminiApiKey();
      } else {
        await store.writeGeminiApiKey(raw);
      }
      if (!mounted) return;
      final isGreek =
          (ref.read(authStateProvider).value?.preferredLanguage ?? 'el') ==
          'el';
      CustomSnackBar.show(
        context: context,
        message: isGreek
            ? 'Οι ρυθμίσεις AI αποθηκεύτηκαν.'
            : 'AI settings saved.',
        type: SnackBarType.success,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionType =
        ref.watch(authStateProvider).valueOrNull?.subscriptionType;
    final isPro = isByokSubscriptionEligible(subscriptionType);
    final isGreek =
        ref.watch(authStateProvider).value?.preferredLanguage == 'el';

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('AI Configuration'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini API Key (optional)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPro
                          ? (isGreek
                                ? 'Πρόσθεσε δικό σου Gemini key για BYOK (δικό σου quota, χωρίς Sparks).'
                                : 'Add your Gemini key for BYOK mode (your quota, no Sparks).')
                          : (isGreek
                                ? 'Το BYOK είναι διαθέσιμο μόνο σε ScholiLink Pro. Άφησε κενό για τα ημερήσια Sparks.'
                                : 'BYOK is available on ScholiLink Pro only. Leave empty to use daily Sparks.'),
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      enabled: isPro,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'AIza...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving...' : 'Save'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await ref
                                      .read(aiKeyStoreProvider)
                                      .clearGeminiApiKey();
                                  if (!mounted) return;
                                  _controller.clear();
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
