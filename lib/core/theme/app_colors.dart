import 'package:flutter/material.dart';

/// Soft mint cafe POS theme (from design mockups).
abstract final class AppColors {
  // Brand (mint / teal)
  static const Color primary = Color(0xFF7EC8C0);
  static const Color primaryDark = Color(0xFF4FA89F);
  static const Color primaryLight = Color(0xFFB8E0D8);
  static const Color primarySoft = Color(0xFFE5F6F3);
  static const Color mint = Color(0xFFAEE2D7);
  static const Color mintBar = Color(0xFF98DBC6);

  // Accent pastels (category chips)
  static const Color coral = Color(0xFFE8A090);
  static const Color gold = Color(0xFFE8C96A);
  static const Color sky = Color(0xFF8BB8E8);
  static const Color emerald = Color(0xFF2D8A6A);
  /// Dark green app / MPOS header bar
  static const Color appBar = Color(0xFF1F6B52);

  // Surfaces
  static const Color background = Color(0xFFF3FAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF2F1);
  static const Color chipGrey = Color(0xFFE8ECEB);
  /// Corporate gray for product image placeholders
  static const Color corporateGray = Color(0xFFD1D5D8);

  // Text
  static const Color textPrimary = Color(0xFF1A1F1E);
  static const Color textSecondary = Color(0xFF6B7371);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF2D8A6A);
  static const Color warning = Color(0xFFE8C96A);
  static const Color error = Color(0xFFE05A5A);
  static const Color info = Color(0xFF8BB8E8);

  // Legacy aliases used across app
  static const Color primaryMuted = primaryLight;
  static const Color accent = primaryDark;
  static const Color accentGold = gold;
  static const Color slate900 = textPrimary;
  static const Color slate700 = Color(0xFF3D4442);
  static const Color slate500 = textSecondary;
  static const Color slate200 = Color(0xFFD5DCDA);
  static const Color slate100 = surfaceMuted;
  static const Color surfaceTint = primarySoft;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FA89F), Color(0xFF7EC8C0), Color(0xFFAEE2D7)],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE5F6F3), Color(0xFFF3FAF8), Color(0xFFFFFFFF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF3FAF8)],
  );

  static const List<Color> categoryColors = [primary, coral, gold, sky];
}
