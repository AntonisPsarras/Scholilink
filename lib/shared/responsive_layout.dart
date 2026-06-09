import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileScaffold;
  final Widget desktopScaffold;
  final Widget? tabletScaffold;

  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1280.0;

  const ResponsiveLayout({
    super.key,
    required this.mobileScaffold,
    required this.desktopScaffold,
    this.tabletScaffold,
  });

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static bool isDesktopWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1600;
  }

  static T valueForBreakpoint<T>({
    required double width,
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (width >= desktopBreakpoint) {
      return desktop;
    }
    if (width >= tabletBreakpoint) {
      return tablet;
    }
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint) {
          return desktopScaffold;
        }
        if (constraints.maxWidth >= tabletBreakpoint &&
            tabletScaffold != null) {
          return tabletScaffold!;
        }
        {
          return mobileScaffold;
        }
      },
    );
  }
}
