import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';

/// The same subject mapping from onboarding, used to show default subjects.
/// NOTE: Α' Λυκείου uses "Νέα Ελληνικά" (a combined subject) — the separate
/// "Νέα Ελληνική Γλώσσα" and "Νεοελληνική Λογοτεχνία" from Gymnasio are NOT
/// offered as two separate subjects at this level.
final Map<String, List<String>> _subjectMapping = {
  'Α\' Γυμνασίου': [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Οδύσσεια',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Γεωγραφία',
    'Οικιακή Οικονομία',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  'Β\' Γυμνασίου': [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Ιλιάδα',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Γεωγραφία',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  'Γ\' Γυμνασίου': [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Ελένη',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Κοινωνική & Πολιτική Αγωγή',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  // Α' Λυκείου: "Νέα Ελληνικά" is the unified language/literature subject.
  // "Νέα Ελληνική Γλώσσα" and "Νεοελληνική Λογοτεχνία" are NOT listed separately here.
  'Α\' Λυκείου': [
    'Νέα Ελληνικά',
    'Αρχαία Ελληνικά',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Άλγεβρα',
    'Γεωμετρία',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Κοινωνική & Πολιτική Αγωγή',
    'Εφαρμογές Πληροφορικής',
    'Φυσική Αγωγή',
  ],
  'Β\' Λυκείου - Γενικής Παιδείας': [
    'Νεοελληνική Γλώσσα και Λογοτεχνία',
    'Αρχαία Ελληνικά — Σοφοκλέους Αντιγόνη / Θουκυδίδη Περικλέους Επιτάφιος',
    'Άλγεβρα',
    'Γεωμετρία',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Φιλοσοφία (ή μάθημα επιλογής)',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Θρησκευτικά',
    'Φυσική Αγωγή',
  ],
  'Β\' Λυκείου - Ανθρωπιστικών': [
    'Αρχαία Ελληνική Γλώσσα και Γραμματεία',
    'Λατινικά',
  ],
  'Β\' Λυκείου - Θετικών Σπουδών': [
    'Μαθηματικά Προσανατολισμού',
    'Φυσική Προσανατολισμού',
  ],
  'Γ\' Λυκείου - Γενικής Παιδείας': [
    'Νεοελληνική Γλώσσα και Λογοτεχνία',
    'Θρησκευτικά',
    'Αγγλικά',
    'Φυσική Αγωγή',
    'Ιστορία',
  ],
  'Γ\' Λυκείου - Ανθρωπιστικών': ['Αρχαία Ελληνικά', 'Λατινικά', 'Ιστορία'],
  'Γ\' Λυκείου - Θετικών Σπουδών': ['Μαθηματικά', 'Φυσική', 'Χημεία'],
  'Γ\' Λυκείου - Σπουδών Υγείας': ['Βιολογία', 'Φυσική', 'Χημεία'],
  'Γ\' Λυκείου - Οικονομίας/Πληροφορικής': [
    'Μαθηματικά',
    'Πληροφορική',
    'Οικονομία',
  ],
};

class ManageSubjectsScreen extends ConsumerStatefulWidget {
  const ManageSubjectsScreen({super.key});

  @override
  ConsumerState<ManageSubjectsScreen> createState() =>
      _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends ConsumerState<ManageSubjectsScreen> {
  late List<String> _activeSubjects;
  late List<String> _defaultSubjects;
  bool _initialized = false;
  final _customSubjectController = TextEditingController();

  @override
  void dispose() {
    _customSubjectController.dispose();
    super.dispose();
  }

  void _initSubjects(List<String> currentSubjects, String? currentClass) {
    if (_initialized) return;
    _activeSubjects = List.from(currentSubjects);

    // Determine default subjects from the class mapping
    _defaultSubjects = [];
    if (currentClass != null) {
      if (_subjectMapping.containsKey(currentClass)) {
        _defaultSubjects = List.from(_subjectMapping[currentClass]!);
      } else {
        for (final key in _subjectMapping.keys) {
          if (currentClass.contains(key.split(' - ').first)) {
            _defaultSubjects.addAll(_subjectMapping[key]!);
          }
        }
        _defaultSubjects = _defaultSubjects.toSet().toList();
      }
    }

    // Include any subjects the user already has that aren't in defaults (custom/renamed)
    for (final s in _activeSubjects) {
      if (!_defaultSubjects.contains(s)) {
        _defaultSubjects.add(s);
      }
    }

    _initialized = true;
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_activeSubjects.contains(subject)) {
        _activeSubjects.remove(subject);
      } else {
        _activeSubjects.add(subject);
      }
    });
  }

  void _addCustomSubject() {
    final name = _customSubjectController.text.trim();
    if (name.isNotEmpty && !_defaultSubjects.contains(name)) {
      setState(() {
        _defaultSubjects.add(name);
        _activeSubjects.add(name);
      });
      _customSubjectController.clear();
    }
  }

  /// Shows a rename dialog for the given subject. Updates both [_defaultSubjects]
  /// and [_activeSubjects] so the renamed subject shows correctly everywhere.
  Future<void> _showRenameDialog(String subject, String lang) async {
    final controller = TextEditingController(text: subject);
    final cs = Theme.of(context).colorScheme;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surface,
        title: Text(
          lang == 'el' ? 'Μετονομασία Μαθήματος' : 'Rename Subject',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'el'
                  ? 'Το νέο όνομα θα χρησιμοποιείται παντού στην εφαρμογή.'
                  : 'The new name will be used everywhere in the app.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: lang == 'el' ? 'Νέο όνομα...' : 'New name...',
                fillColor: context.brand.inputFill,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.35),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.brand.primaryPurple,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang == 'el' ? 'Ακύρωση' : 'Cancel',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
            },
            child: Text(lang == 'el' ? 'Αποθήκευση' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName != subject && mounted) {
      setState(() {
        final defaultIdx = _defaultSubjects.indexOf(subject);
        if (defaultIdx >= 0) _defaultSubjects[defaultIdx] = newName;

        final activeIdx = _activeSubjects.indexOf(subject);
        if (activeIdx >= 0) _activeSubjects[activeIdx] = newName;
      });

      CustomSnackBar.show(
        context: context,
        message: lang == 'el'
            ? '"$subject" → "$newName"'
            : 'Renamed "$subject" to "$newName"',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref
          .read(authRepositoryProvider)
          .updateUserProfile(user.copyWith(subjects: _activeSubjects));
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
    final lang = user?.preferredLanguage ?? 'el';
    final s = S(lang);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _initSubjects(user.subjects, user.currentClass);

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            s.manageSubjects,
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: Icon(
                Icons.save_rounded,
                color: context.brand.primaryPurple,
              ),
              label: Text(
                s.save,
                style: TextStyle(
                  color: context.brand.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Hint banner ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.brand.primaryPurple.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.brand.primaryPurple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: context.brand.primaryPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang == 'el'
                              ? 'Πατήστε παρατεταμένα σε ένα μάθημα για να το μετονομάσετε.'
                              : 'Long-press a subject to rename it.',
                          style: TextStyle(
                            color: context.brand.primaryPurple,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Add custom subject ───────────────────────────────────────
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSubjectController,
                            style: TextStyle(color: context.brand.darkText),
                            decoration: InputDecoration(
                              hintText: s.customSubjectHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addCustomSubject(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addCustomSubject,
                          style: IconButton.styleFrom(
                            backgroundColor: context.brand.primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Subject toggles ─────────────────────────────────────────
                Text(
                  s.subjects,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),

                ..._defaultSubjects.map((subject) {
                  final isActive = _activeSubjects.contains(subject);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          subject,
                          style: TextStyle(
                            color: isActive
                                ? context.brand.royalLavender
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        value: isActive,
                        activeColor: context.brand.primaryPurple,
                        onChanged: (_) => _toggleSubject(subject),
                        secondary: IconButton(
                          tooltip: lang == 'el' ? 'Μετονομασία' : 'Rename',
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          onPressed: () => _showRenameDialog(subject, lang),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
