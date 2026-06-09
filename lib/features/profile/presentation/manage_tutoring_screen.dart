import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class ManageTutoringScreen extends ConsumerStatefulWidget {
  const ManageTutoringScreen({super.key});

  @override
  ConsumerState<ManageTutoringScreen> createState() =>
      _ManageTutoringScreenState();
}

class _ManageTutoringScreenState extends ConsumerState<ManageTutoringScreen> {
  bool _hasTutoring = false;
  late List<String> _tutoringSubjects;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _hasTutoring = user?.hasTutoring ?? false;
    _tutoringSubjects = List.from(user?.tutoringSubjects ?? []);
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref
          .read(authRepositoryProvider)
          .updateUserProfile(
            user.copyWith(
              hasTutoring: _hasTutoring,
              tutoringSubjects: _hasTutoring ? _tutoringSubjects : [],
            ),
          );
      if (mounted) {
        final s = S(user.preferredLanguage);
        CustomSnackBar.show(
          context: context,
          message: s.profileUpdated,
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');

    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Use current subjects as available options
    final availableSubjects = user.subjects;

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.manageTutoring),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(s.save),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  s.manageTutoring,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  s.tutoringDesc,
                  style: TextStyle(
                    color: context.brand.neutralGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(s.hasTutoring),
                    subtitle: Text(
                      s.lang == 'el'
                          ? 'Ενεργοποίησε αν πας σε φροντιστήριο ή κάνεις ιδιαίτερα'
                          : 'Enable if you attend a frontistirio or have private tutoring',
                    ),
                    value: _hasTutoring,
                    activeThumbColor: context.brand.royalLavender,
                    activeTrackColor: context.brand.royalLavender.withValues(
                      alpha: 0.5,
                    ),
                    onChanged: (val) => setState(() => _hasTutoring = val),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_hasTutoring) ...[
                  const SizedBox(height: 16),
                  Text(
                    s.tutoringSubjects,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (availableSubjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        s.lang == 'el'
                            ? 'Δεν έχετε μαθήματα. Παρακαλώ προσθέστε μαθήματα στο προφίλ σας για να τα επιλέξετε εδώ.'
                            : 'You have no subjects. Please add subjects to your profile first.',
                        style: TextStyle(color: context.brand.neutralGrey),
                      ),
                    )
                  else
                    ...availableSubjects.map((subject) {
                      final isTutored = _tutoringSubjects.contains(subject);
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            subject,
                            style: TextStyle(
                              color: isTutored
                                  ? context.brand.royalLavender
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isTutored
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          value: isTutored,
                          activeColor: context.brand.royalLavender,
                          onChanged: (_) {
                            setState(() {
                              if (isTutored) {
                                _tutoringSubjects.remove(subject);
                              } else {
                                _tutoringSubjects.add(subject);
                              }
                            });
                          },
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
