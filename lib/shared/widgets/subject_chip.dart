import 'package:flutter/material.dart';

/// Unified subject chip style used across dashboard/profile/settings.
class SubjectChip extends StatelessWidget {
  final String subject;
  final bool isFinalExam;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleted;
  final EdgeInsetsGeometry padding;

  const SubjectChip({
    super.key,
    required this.subject,
    this.isFinalExam = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onDeleted,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = selected ? Colors.white : cs.onSurface;

    final chip = Container(
      padding: padding,
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: selected
            ? cs.primary
            : (dark
                  ? const Color(0xFF2A2A3D)
                  : cs.primary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: 0.95)
              : isFinalExam
              ? Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: dark ? 0.8 : 0.6)
              : (dark
                    ? cs.outline.withValues(alpha: 0.4)
                    : cs.primary.withValues(alpha: 0.28)),
          width: isFinalExam ? 1.2 : 1,
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (isFinalExam)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : (dark ? Colors.white : cs.primary),
                    ),
                  ),
              ],
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(10),
              child: Icon(Icons.close_rounded, size: 14, color: textColor),
            ),
          ],
        ],
      ),
    );

    if (onTap == null && onLongPress == null) {
      return chip;
    }

    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: chip);
  }
}
