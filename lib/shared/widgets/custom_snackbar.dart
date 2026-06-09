import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SnackBarType { info, success, warning, error }

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    Color backgroundColor;
    Color textColor = Colors.white;
    IconData iconData;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xFFA4F5A6); // Success Mint
        textColor = const Color(0xFF2D3748); // Dark text for light background
        iconData = Icons.check_circle_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = const Color(0xFFFFD89D); // Warning Sunset
        textColor = const Color(0xFF2D3748); // Dark text for light background
        iconData = Icons.warning_amber_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = const Color(0xFFFF8A8A); // Danger Rose
        iconData = Icons.error_outline;
        break;
      case SnackBarType.info:
        backgroundColor = const Color(0xFFA28EF9); // Primary Purple
        iconData = Icons.info_outline;
        break;
    }

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(iconData, color: textColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.fustat(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
