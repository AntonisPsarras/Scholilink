import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/l10n.dart';
import '../../auth/data/auth_repository.dart';

class DesktopSidebarNav extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const DesktopSidebarNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(authStateProvider).value?.preferredLanguage ?? 'el';
    final s = S(lang);

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: GlassContainer(
        borderRadius: 24,
        blur: dark ? 0 : 15.0,
        backgroundColor: dark
            ? context.brand.surfaceElevated
            : Colors.white.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo or Brand area
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school,
                    color: context.brand.royalLavender,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ScholiLink',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.brand.darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Navigation Items
              _navItem(
                context,
                s.lang == 'el' ? 'Κεντρική' : 'Home',
                Icons.dashboard_outlined,
                Icons.dashboard,
                0,
              ),
              const SizedBox(height: 12),
              _navItem(
                context,
                s.lang == 'el' ? 'Εργασίες' : 'Homework',
                Icons.book_outlined,
                Icons.book,
                1,
              ),
              const SizedBox(height: 12),
              _navItem(
                context,
                s.lang == 'el' ? 'Πρόγραμμα' : 'Schedule',
                Icons.school_outlined,
                Icons.school,
                2,
              ),
              const SizedBox(height: 12),
              _navItem(
                context,
                s.lang == 'el' ? 'Μηνύματα' : 'Messages',
                Icons.groups_outlined,
                Icons.groups,
                3,
              ),
              const SizedBox(height: 12),
              _navItem(
                context,
                s.lang == 'el' ? 'Προφίλ' : 'Profile',
                Icons.person_outline,
                Icons.person,
                4,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  static String _navSemanticLabel(int index) {
    switch (index) {
      case 0:
        return 'Αρχική';
      case 1:
        return 'Εργασίες';
      case 2:
        return 'Πρόγραμμα';
      case 3:
        return 'Τάξεις';
      case 4:
        return 'Προφίλ';
      default:
        return '';
    }
  }

  Widget _navItem(
    BuildContext context,
    String label,
    IconData iconOutline,
    IconData iconFilled,
    int index,
  ) {
    final isSelected = selectedIndex == index;
    return Semantics(
      label: _navSemanticLabel(index),
      selected: isSelected,
      button: true,
      child: LiquidTouch(
        onTap: () => onItemTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? iconFilled : iconOutline,
                color: isSelected
                    ? context.brand.darkText
                    : context.brand.neutralGrey,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? context.brand.darkText
                      : context.brand.neutralGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              if (isSelected) const Spacer(),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.shade200,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
