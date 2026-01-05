import 'package:flutter/material.dart';

/// Brand and semantic colors based on UI_UX_DESIGN_SYSTEM.md
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF1976D2); // Blue 700
  static const Color primaryVariant = Color(0xFF1565C0); // Blue 800
  static const Color secondary = Color(0xFF2196F3); // Blue 500

  // Semantic Colors
  static const Color success = Color(0xFF2E7D32); // Green 800
  static const Color warning = Color(0xFFED6C02); // Orange 700
  static const Color error = Color(0xFFD32F2F); // Red 700
  static const Color muted = Color(0xFF9E9E9E); // Grey 500

  // Background Colors (Light Theme)
  static const Color background = Color(0xFFF6F8FB); // Light grey-blue
  static const Color surface = Color(0xFFFFFFFF); // White

  // Dark Theme Colors
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark grey
  static const Color inputFillDark = Color(0xFF2A2A2A); // Darker grey
  static const Color dividerDark = Color(0xFF424242); // Medium grey

  // Text Colors (Light Theme)
  static const Color textPrimary = Color(0xFF000000); // Black 87%
  static const Color textSecondary = Color(0x99000000); // Black 60%
  static const Color textDisabled = Color(0x61000000); // Black 38%

  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // White
  static const Color textSecondaryDark = Color(0xB3FFFFFF); // White 70%
}
