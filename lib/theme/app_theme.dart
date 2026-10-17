import 'package:flutter/material.dart';

/// Colours taken from the Liberian flag: blue canton, red stripes, white star.
class AppColors {
  static const Color navy = Color(0xFF002868);
  static const Color navyDark = Color(0xFF001A45);
  static const Color red = Color(0xFFBF0A30);
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color bg = Color(0xFFF4F6FA);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF15803D);
  static const Color amber = Color(0xFFD97706);
  static const Color navySoft = Color(0xFFE7EDF8);
  static const Color redSoft = Color(0xFFFCE8EC);
  static const Color greenSoft = Color(0xFFE6F4EA);
  static const Color amberSoft = Color(0xFFFFF4E0);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.red,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      visualDensity: VisualDensity.standard,
    );
  }
}

class AppText {
  static const TextStyle h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2);
  static const TextStyle h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const TextStyle body = TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4);
  static const TextStyle muted = TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35);
  static const TextStyle small = TextStyle(fontSize: 12, color: AppColors.muted);
}
