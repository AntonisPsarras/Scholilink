import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/performance_config.dart';

class FloatingIslandNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Map<int, int>? badges; // Map from index to badge count

  const FloatingIslandNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: dark
              ? _darkNavChrome(context)
              : _lightLiquidGlassChrome(context),
        ),
      ),
    );
  }

  Widget _darkNavChrome(BuildContext context) {
    final barTint = context.brand.surfaceElevated;
    return GlassContainer(
      height: 70,
      borderRadius: 40,
      blur: 0,
      backgroundColor: barTint,
      child: _navLayout(context, dark: true),
    );
  }

  /// Light mode: stronger frosted capsule with blur and elevation (avoids weak
  /// [GlassContainer] gradient dilution on opaque tints).
  Widget _lightLiquidGlassChrome(BuildContext context) {
    const double radius = 40;
    const double height = 70;
    final brand = context.brand;
    final blurSigma = PerformanceConfig.useBlur
        ? math.min(10.0, PerformanceConfig.blurSigma)
        : 0.0;

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1),
        ),
      ),
      child: _navLayout(context, dark: false),
    );

    if (blurSigma > 0) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: body,
        ),
      );
    } else {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: body,
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: brand.glassShadow.withValues(alpha: 0.55),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: body,
      ),
    );
  }

  Widget _navLayout(BuildContext context, {required bool dark}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int itemCount = 5;
        final double itemWidth = constraints.maxWidth / itemCount;
        const double indicatorSize = 50.0;
        final double leftPosition =
            (selectedIndex * itemWidth) + (itemWidth / 2) - (indicatorSize / 2);

        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubicEmphasized,
              left: leftPosition,
              top: (70 - indicatorSize) / 2,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: context.brand.primaryPurple.withValues(
                    alpha: dark ? 0.14 : 0.2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: dark
                      ? [
                          BoxShadow(
                            color: context.brand.primaryPurple.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(
                  context,
                  Icons.dashboard_outlined,
                  Icons.dashboard,
                  0,
                  itemWidth,
                ),
                _navItem(
                  context,
                  Icons.book_outlined,
                  Icons.book,
                  1,
                  itemWidth,
                ),
                _navItem(
                  context,
                  Icons.school_outlined,
                  Icons.school,
                  2,
                  itemWidth,
                ),
                _navItem(
                  context,
                  Icons.groups_outlined,
                  Icons.groups,
                  3,
                  itemWidth,
                  badgeCount: badges?[3],
                ),
                _navItem(
                  context,
                  Icons.person_outline,
                  Icons.person,
                  4,
                  itemWidth,
                ),
              ],
            ),
          ],
        );
      },
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
    IconData iconOutline,
    IconData iconFilled,
    int index,
    double width, {
    int? badgeCount,
  }) {
    final isSelected = selectedIndex == index;
    final accent = context.brand.primaryPurple;
    final muted = context.brand.neutralGrey;

    return SizedBox(
      width: width,
      height: 70,
      child: Center(
        child: Semantics(
          label: _navSemanticLabel(index),
          selected: isSelected,
          button: true,
          child: LiquidTouch(
            onTap: () => onItemTapped(index),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? iconFilled : iconOutline,
                        color: isSelected ? accent : muted,
                        size: 28,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.brand.errorRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
