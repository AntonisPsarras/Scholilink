import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../l10n.dart';

/// A reusable dialog that shows homework types and lets the user pick one.
/// Returns the selected type string ('daily' or 'project'), or null if cancelled.
Future<String?> showTypePickerDialog({
  required BuildContext context,
  String? currentType,
  required S s,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TypePickerDialog(currentType: currentType, s: s),
  );
}

class _TypePickerDialog extends StatelessWidget {
  final String? currentType;
  final S s;

  const _TypePickerDialog({this.currentType, required this.s});

  @override
  Widget build(BuildContext context) {
    final types = [
      {'id': 'daily', 'label': s.dailyHomework, 'icon': Icons.assignment},
      {'id': 'project', 'label': s.projectHomework, 'icon': Icons.architecture},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.homeworkType,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final isSelected = type['id'] == currentType;
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: isSelected,
                      selectedTileColor: context.brand.royalLavender.withValues(
                        alpha: 0.1,
                      ),
                      leading: Icon(
                        type['icon'] as IconData,
                        color: isSelected
                            ? context.brand.royalLavender
                            : context.brand.neutralGrey,
                        size: 20,
                      ),
                      title: Text(
                        type['label'] as String,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? context.brand.royalLavender
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      onTap: () =>
                          Navigator.of(context).pop(type['id'] as String),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(s.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
