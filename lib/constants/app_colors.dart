import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors & Gradients
  static const Color primaryBlue = Color(0xFF0084FF);
  static const Color primaryCyan = Color(0xFF00D2B5);
  static const Color darkNavy = Color(0xFF0A1E46);
  static const Color darkNavyDeep = Color(0xFF061129);

  // Backgrounds
  static const Color scaffoldBackground = Color(0xFFF4F7FB);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color fieldBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color errorRed = Color(0xFFE11D48);

  // Status Badges & Quick Action Colors
  static const Color lostThemeStart = Color(0xFF0084FF);
  static const Color lostThemeEnd = Color(0xFF0A1E46);
  static const Color foundThemeStart = Color(0xFF196173);
  static const Color foundThemeEnd = Color(0xFF0A1E46);
  static const Color lostBadgeBg = Color(0xFFE5F2FF);
  static const Color lostBadgeText = Color(0xFF0084FF);
  static const Color foundBadgeBg = Color(0xFFE6F9F3);
  static const Color foundBadgeText = Color(0xFF196173);
  static const Color matchedBadgeBg = Color(0xFFE6F8F6);
  static const Color matchedBadgeText = Color(0xFF0D9488);

  // Gradients
  static const LinearGradient authHeaderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF040A1A), Color(0xFF0A224E), Color(0xFF06132D)],
  );

  static const LinearGradient dashboardHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF061129),
      Color(0xFF0A1E46),
      Color(0xFF0E2A60),
    ],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0084FF), Color(0xFF00D2B5)],
  );

  static const LinearGradient reportLostGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lostThemeStart, lostThemeEnd],
  );

  static const LinearGradient reportFoundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [foundThemeStart, foundThemeEnd],
  );
}
