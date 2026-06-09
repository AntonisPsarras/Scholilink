import 'package:flutter/material.dart';

/// Brand and semantic colors that are not fully covered by [ColorScheme] alone.
/// Access via `context.brand` (see [AppBrandContext] in [app_theme.dart]).
@immutable
class AppBrandColors extends ThemeExtension<AppBrandColors> {
  const AppBrandColors({
    required this.backgroundSnow,
    required this.darkText,
    required this.neutralGrey,
    required this.royalLavender,
    required this.primaryPurple,
    required this.canvasBackground,
    required this.mintSuccess,
    required this.sunsetWarning,
    required this.dangerRose,
    required this.errorRed,
    required this.surfaceElevated,
    required this.inputFill,
    required this.glassBase,
    required this.glassSheenPink,
    required this.glassSheenCyan,
    required this.glassBorder,
    required this.glassShadow,
    required this.glassFlatShadow,
    required this.glassSpecularTop,
  });

  final Color backgroundSnow;
  final Color darkText;
  final Color neutralGrey;
  final Color royalLavender;
  final Color primaryPurple;
  final Color canvasBackground;
  final Color mintSuccess;
  final Color sunsetWarning;
  final Color dangerRose;
  final Color errorRed;

  /// Flat elevated panels (cards, glass in dark mode) — no gradient.
  final Color surfaceElevated;

  /// Filled text fields (`InputDecoration.fillColor`).
  final Color inputFill;

  /// Default frosted fill for [GlassContainer] (ARGB).
  final Color glassBase;
  final Color glassSheenPink;
  final Color glassSheenCyan;
  final Color glassBorder;
  final Color glassShadow;

  /// Softer shadow for flat dark surfaces (see [GlassContainer] dark path).
  final Color glassFlatShadow;
  final double glassSpecularTop;

  static const AppBrandColors light = AppBrandColors(
    backgroundSnow: Color(0xFFF7F9FB),
    darkText: Color(0xFF2D3748),
    neutralGrey: Color(0xFF7A8B99),
    royalLavender: Color(0xFF9098A9),
    primaryPurple: Color(0xFFA28EF9),
    canvasBackground: Color(0xFFECEEF0),
    mintSuccess: Color(0xFFA4F5A6),
    sunsetWarning: Color(0xFFFFD89D),
    dangerRose: Color(0xFFFF8A8A),
    errorRed: Color(0xFFEF4444),
    surfaceElevated: Color(0xE6FFFFFF),
    inputFill: Color(0x66FFFFFF),
    glassBase: Color(0x66FFFFFF),
    glassSheenPink: Color(0x44F3E5F5),
    glassSheenCyan: Color(0x44E0F7FA),
    glassBorder: Color(0xB3FFFFFF),
    glassShadow: Color(0x228B93A5),
    glassFlatShadow: Color(0x228B93A5),
    glassSpecularTop: 0.4,
  );

  /// Deep navy / slate with soft purple accents — no pure black.
  static const AppBrandColors dark = AppBrandColors(
    backgroundSnow: Color(0xFF12121C),
    darkText: Color(0xFFE8ECF3),
    neutralGrey: Color(0xFF9BA3B4),
    royalLavender: Color(0xFF9CA3C9),
    primaryPurple: Color(0xFFB8A8FF),
    canvasBackground: Color(0xFF1A1D2E),
    mintSuccess: Color(0xFF7DD89A),
    sunsetWarning: Color(0xFFF4C27A),
    dangerRose: Color(0xFFFF9B9B),
    errorRed: Color(0xFFF87171),
    surfaceElevated: Color(0xFF1E1E2C),
    inputFill: Color(0xFF252536),
    glassBase: Color(0x66303450),
    glassSheenPink: Color(0x5540305C),
    glassSheenCyan: Color(0x552A4558),
    glassBorder: Color(0x14FFFFFF),
    glassShadow: Color(0x66071118),
    glassFlatShadow: Color(0x40000000),
    glassSpecularTop: 0.12,
  );

  @override
  AppBrandColors copyWith({
    Color? backgroundSnow,
    Color? darkText,
    Color? neutralGrey,
    Color? royalLavender,
    Color? primaryPurple,
    Color? canvasBackground,
    Color? mintSuccess,
    Color? sunsetWarning,
    Color? dangerRose,
    Color? errorRed,
    Color? surfaceElevated,
    Color? inputFill,
    Color? glassBase,
    Color? glassSheenPink,
    Color? glassSheenCyan,
    Color? glassBorder,
    Color? glassShadow,
    Color? glassFlatShadow,
    double? glassSpecularTop,
  }) {
    return AppBrandColors(
      backgroundSnow: backgroundSnow ?? this.backgroundSnow,
      darkText: darkText ?? this.darkText,
      neutralGrey: neutralGrey ?? this.neutralGrey,
      royalLavender: royalLavender ?? this.royalLavender,
      primaryPurple: primaryPurple ?? this.primaryPurple,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      mintSuccess: mintSuccess ?? this.mintSuccess,
      sunsetWarning: sunsetWarning ?? this.sunsetWarning,
      dangerRose: dangerRose ?? this.dangerRose,
      errorRed: errorRed ?? this.errorRed,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      inputFill: inputFill ?? this.inputFill,
      glassBase: glassBase ?? this.glassBase,
      glassSheenPink: glassSheenPink ?? this.glassSheenPink,
      glassSheenCyan: glassSheenCyan ?? this.glassSheenCyan,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      glassFlatShadow: glassFlatShadow ?? this.glassFlatShadow,
      glassSpecularTop: glassSpecularTop ?? this.glassSpecularTop,
    );
  }

  @override
  AppBrandColors lerp(ThemeExtension<AppBrandColors>? other, double t) {
    if (other is! AppBrandColors) return this;
    return AppBrandColors(
      backgroundSnow: Color.lerp(backgroundSnow, other.backgroundSnow, t)!,
      darkText: Color.lerp(darkText, other.darkText, t)!,
      neutralGrey: Color.lerp(neutralGrey, other.neutralGrey, t)!,
      royalLavender: Color.lerp(royalLavender, other.royalLavender, t)!,
      primaryPurple: Color.lerp(primaryPurple, other.primaryPurple, t)!,
      canvasBackground: Color.lerp(
        canvasBackground,
        other.canvasBackground,
        t,
      )!,
      mintSuccess: Color.lerp(mintSuccess, other.mintSuccess, t)!,
      sunsetWarning: Color.lerp(sunsetWarning, other.sunsetWarning, t)!,
      dangerRose: Color.lerp(dangerRose, other.dangerRose, t)!,
      errorRed: Color.lerp(errorRed, other.errorRed, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      glassBase: Color.lerp(glassBase, other.glassBase, t)!,
      glassSheenPink: Color.lerp(glassSheenPink, other.glassSheenPink, t)!,
      glassSheenCyan: Color.lerp(glassSheenCyan, other.glassSheenCyan, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      glassFlatShadow: Color.lerp(glassFlatShadow, other.glassFlatShadow, t)!,
      glassSpecularTop:
          glassSpecularTop + (other.glassSpecularTop - glassSpecularTop) * t,
    );
  }
}
