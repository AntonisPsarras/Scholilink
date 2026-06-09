import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/animated_liquid_background.dart';
import 'app_brand_colors.dart';

export 'app_brand_colors.dart';

extension AppBrandContext on BuildContext {
  AppBrandColors get brand =>
      Theme.of(this).extension<AppBrandColors>() ?? AppBrandColors.light;
}

/// Chat bubbles (class/direct): frosted white in light mode; elevated dark surfaces in dark mode.
extension ChatBubbleSurfaces on BuildContext {
  Color chatBubbleGlassFill(bool isMe) {
    final t = Theme.of(this);
    if (t.brightness == Brightness.light) {
      return isMe
          ? Colors.white.withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.4);
    }
    return isMe
        ? brand.primaryPurple.withValues(alpha: 0.32)
        : const Color(0xFF2A2A3D);
  }

  /// Text field / pill fill inside chat composers and similar strips.
  Color get chatComposerInputFill =>
      Theme.of(this).brightness == Brightness.dark
      ? brand.inputFill
      : Colors.white.withValues(alpha: 0.5);
}

/// Root theming. Use `context.brand` for brand colors (see [AppBrandContext]).
class AppTheme {
  // Backward-compatible static colors used across older screens.
  // These map to the light brand palette to preserve previous UI tone.
  static const Color primaryPurple = Color(0xFFA28EF9);
  static const Color darkText = Color(0xFF2D3748);
  static const Color neutralGrey = Color(0xFF7A8B99);
  static const Color sunsetWarning = Color(0xFFFFD89D);

  static ThemeData get lightTheme {
    const brand = AppBrandColors.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: brand.darkText,
      brightness: Brightness.light,
      primary: brand.darkText,
      surface: Colors.white.withValues(alpha: 0.6),
      error: brand.errorRed,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: baseScheme,
      extensions: const [AppBrandColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: brand.darkText,
        iconTheme: IconThemeData(color: brand.darkText),
        titleTextStyle: GoogleFonts.fustat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: brand.darkText,
        ),
      ),
      iconTheme: IconThemeData(color: brand.darkText),
      textTheme: GoogleFonts.fustatTextTheme().copyWith(
        displayLarge: GoogleFonts.fustat(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: brand.darkText,
        ),
        headlineMedium: GoogleFonts.fustat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: brand.darkText,
        ),
        bodyLarge: GoogleFonts.fustat(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: brand.darkText,
        ),
        labelSmall: GoogleFonts.fustat(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: brand.neutralGrey,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  static ThemeData get darkTheme {
    const brand = AppBrandColors.dark;
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brand.primaryPurple,
      onPrimary: const Color(0xFF12121C),
      primaryContainer: const Color(0xFF2D3250),
      onPrimaryContainer: const Color(0xFFE0D8FF),
      secondary: brand.royalLavender,
      onSecondary: const Color(0xFF12121C),
      tertiary: brand.mintSuccess,
      onTertiary: const Color(0xFF12121C),
      error: brand.errorRed,
      onError: const Color(0xFF12121C),
      surface: const Color(0xFF1E2235),
      onSurface: brand.darkText,
      onSurfaceVariant: brand.neutralGrey,
      outline: const Color(0xFF3D4458),
      outlineVariant: const Color(0xFF2A3145),
      shadow: const Color(0x66071118),
      scrim: const Color(0xCC0A0C12),
      inverseSurface: const Color(0xFFE8ECF3),
      onInverseSurface: const Color(0xFF12121C),
      surfaceContainerHighest: const Color(0xFF252A3E),
      surfaceContainerHigh: const Color(0xFF22263A),
      surfaceContainer: const Color(0xFF1E2235),
      surfaceContainerLow: const Color(0xFF1A1D2E),
      surfaceContainerLowest: const Color(0xFF12121C),
      surfaceTint: brand.primaryPurple,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: colorScheme,
      extensions: const [AppBrandColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: brand.darkText,
        iconTheme: IconThemeData(color: brand.darkText),
        titleTextStyle: GoogleFonts.fustat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: brand.darkText,
        ),
      ),
      iconTheme: IconThemeData(color: brand.darkText),
      textTheme:
          GoogleFonts.fustatTextTheme(
            ThemeData.dark(useMaterial3: true).textTheme,
          ).copyWith(
            displayLarge: GoogleFonts.fustat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: brand.darkText,
            ),
            headlineMedium: GoogleFonts.fustat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: brand.darkText,
            ),
            bodyLarge: GoogleFonts.fustat(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: brand.darkText,
            ),
            labelSmall: GoogleFonts.fustat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: brand.neutralGrey,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.inputFill,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        floatingLabelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        helperStyle: TextStyle(color: brand.neutralGrey),
        errorStyle: TextStyle(color: brand.errorRed),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: brand.primaryPurple.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: brand.errorRed.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: brand.errorRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(8),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand.darkText,
          side: BorderSide(color: brand.primaryPurple.withValues(alpha: 0.45)),
          backgroundColor: brand.primaryPurple.withValues(alpha: 0.12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.primaryPurple.withValues(alpha: 0.22),
          foregroundColor: brand.darkText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
    );
  }

  /// Full-screen gradient behind authenticated UI. Uses [AnimatedLiquidBackground]
  /// with tier-based and reduced-motion static fallbacks.
  static Widget globalGradient({required Widget child}) {
    return AnimatedLiquidBackground(child: child);
  }
}
