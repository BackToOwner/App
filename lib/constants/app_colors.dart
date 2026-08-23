import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors & Gradients
  static const Color primaryBlue = Color(0xFF1D4ED8);
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

  // Status Badges & Quick Action Colors
  static const Color lostRedStart = Color(0xFFFF5252);
  static const Color lostRedEnd = Color(0xFFE11D48);

  static const Color foundGreenStart = Color(0xFF10B981);
  static const Color foundGreenEnd = Color(0xFF059669);

  static const Color lostBadgeBg = Color(0xFFFFECEF);
  static const Color lostBadgeText = Color(0xFFF43F5E);

  static const Color foundBadgeBg = Color(0xFFE6F9F3);
  static const Color foundBadgeText = Color(0xFF10B981);

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
    colors: [Color(0xFF08183A), Color(0xFF0C2C69), Color(0xFF1246A3)],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF00D2B5)],
  );

  static const LinearGradient reportLostGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5252), Color(0xFFE11D48)],
  );

  static const LinearGradient reportFoundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );
}
