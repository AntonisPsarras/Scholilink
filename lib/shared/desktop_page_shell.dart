import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../shared/responsive_layout.dart';
import '../features/dashboard/presentation/desktop_sidebar_nav.dart';
import '../features/dashboard/presentation/desktop_social_sidebar.dart';

/// Wraps a full-page screen with the standard desktop left + right sidebars.
/// On mobile (≤900px) the [child] is returned unchanged.
///
/// Use this when pushing secondary routes (e.g. ScheduleEditorScreen,
/// ClassroomChatScreen) that would otherwise lose the sidebar chrome.
class DesktopPageShell extends ConsumerWidget {
  final Widget child;

  /// Which nav item in the left sidebar should appear highlighted.
  /// 0 = Κεντρική, 1 = Εργασίες, 2 = Πρόγραμμα, 3 = Μηνύματα, 4 = Προφίλ
  final int selectedNavIndex;

  const DesktopPageShell({
    super.key,
    required this.child,
    this.selectedNavIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ResponsiveLayout.isDesktop(context)) return child;

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            DesktopSidebarNav(
              selectedIndex: selectedNavIndex,
              // Tapping nav items in sub-pages pops back to home.
              onItemTapped: (_) => Navigator.of(context).maybePop(),
            ),
            Expanded(child: child),
            const DesktopSocialSidebar(),
          ],
        ),
      ),
    );
  }
}
