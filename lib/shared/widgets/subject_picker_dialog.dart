import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A reusable dialog that shows the user's subjects and lets them pick one.
/// Returns the selected subject string, or null if cancelled.
Future<String?> showSubjectPickerDialog({
  required BuildContext context,
  required List<String> subjects,
  String? title,
  String? currentSubject,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SubjectPickerDialog(
      subjects: subjects,
      title: title ?? 'Select Subject',
      currentSubject: currentSubject,
    ),
  );
}

class _SubjectPickerDialog extends StatefulWidget {
  final List<String> subjects;
  final String title;
  final String? currentSubject;

  const _SubjectPickerDialog({
    required this.subjects,
    required this.title,
    this.currentSubject,
  });

  @override
  State<_SubjectPickerDialog> createState() => _SubjectPickerDialogState();
}

class _SubjectPickerDialogState extends State<_SubjectPickerDialog> {
  final _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.subjects;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.subjects;
      } else {
        final lower = query.toLowerCase();
        _filtered = widget.subjects
            .where((s) => s.toLowerCase().contains(lower))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480, maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: lang == 'el' ? 'Αναζήτηση...' : 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            lang == 'el'
                                ? 'Δεν βρέθηκαν διαθέσιμα μαθήματα'
                                : 'No subjects available yet',
                            style: TextStyle(color: context.brand.neutralGrey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final subject = _filtered[index];
                          final isSelected = subject == widget.currentSubject;
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: isSelected,
                            selectedTileColor: context.brand.royalLavender
                                .withValues(alpha: 0.1),
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? context.brand.royalLavender
                                  : context.brand.neutralGrey,
                              size: 20,
                            ),
                            title: Text(
                              subject,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? context.brand.royalLavender
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(subject),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(lang == 'el' ? 'Ακύρωση' : 'Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
