import 'package:flutter/material.dart';

import 'responsive_layout.dart';

/// Bottom padding for the floating island nav in [FloatingIslandNav].
const double kFloatingNavOuterBottomPadding = 24;

/// Height of the glass nav bar (excluding outer padding).
const double kFloatingNavBarHeight = 70;

/// FAB vertical offset from physical bottom (see [HomeScaffold]).
const double kShellFabBottomPadding = 80;

/// Center FAB diameter.
const double kShellFabSize = 56;

/// Extra breathing room below the FAB so list content / ads clear comfortably.
const double kShellContentExtraBelowFab = 20;

/// Minimum fallback when not using mobile shell (should be rare).
const double kShellBottomFallbackPadding = 100;

/// Bottom scroll padding for tab bodies under the mobile floating nav + FAB.
///
/// Uses safe area + FAB stack (taller than nav alone) so ads and last list
/// rows do not sit under the center [+] or the island bar.
double shellBottomContentPadding(
  BuildContext context, {
  bool useMobileFloatingChrome = true,
}) {
  if (!useMobileFloatingChrome ||
      ResponsiveLayout.isDesktop(context) ||
      ResponsiveLayout.isTablet(context)) {
    return kShellBottomFallbackPadding;
  }

  final safeBottom = MediaQuery.paddingOf(context).bottom;
  final belowFab =
      kShellFabBottomPadding + kShellFabSize + kShellContentExtraBelowFab;
  return safeBottom + belowFab;
}

/// Bottom padding for full-screen pushed routes (no home floating nav/FAB).
double pushedRouteBottomPadding(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom + 32;
}
