import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

/// Typography system based on UI_UX_DESIGN_SYSTEM.md
class AppTypography {
  AppTypography._();

  // Font Family - OpenSans
  static const String fontFamily = 'OpenSans';

  // Typography Scale
  static const double displaySize = 28;
  static const double titleSize = 20;
  static const double bodyLargeSize = 16;
  static const double bodyMediumSize = 14;
  static const double captionSize = 12;

  // Font Weights
  static const FontWeight displayWeight = FontWeight.w900; // Black
  static const FontWeight titleWeight = FontWeight.w700; // Bold
  static const FontWeight bodyWeight = FontWeight.w400; // Regular
  static const FontWeight captionWeight = FontWeight.w300; // Light
  static const FontWeight appBarWeight = FontWeight.w600; // Semi-bold

  /// Light theme text theme
  static TextTheme get lightTextTheme {
    return TextTheme(
      // Display Hero (28px, 900)
      displayLarge: const TextStyle(
        fontSize: displaySize,
        fontWeight: displayWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
        height: 22 / 28,
      ),
      // Title Large (20px, 700)
      headlineMedium: const TextStyle(
        fontSize: titleSize,
        fontWeight: titleWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
      ),
      // Body Large (16px, 400)
      bodyLarge: const TextStyle(
        fontSize: bodyLargeSize,
        fontWeight: bodyWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
      ),
      // Body Medium (14px, 400)
      bodyMedium: const TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: bodyWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
      ),
      // Small Caption (12px, 300)
      bodySmall: const TextStyle(
        fontSize: captionSize,
        fontWeight: captionWeight,
        fontFamily: fontFamily,
        color: AppColors.textSecondary,
      ),
      // Label (14px, 500) - for form labels
      labelLarge: const TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Dark theme text theme
  static TextTheme get darkTextTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: displaySize,
        fontWeight: displayWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimaryDark,
        height: 22 / 28,
      ),
      headlineMedium: TextStyle(
        fontSize: titleSize,
        fontWeight: titleWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLargeSize,
        fontWeight: bodyWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: bodyWeight,
        fontFamily: fontFamily,
        color: AppColors.textPrimaryDark,
      ),
      bodySmall: TextStyle(
        fontSize: captionSize,
        fontWeight: captionWeight,
        fontFamily: fontFamily,
        color: AppColors.textSecondaryDark,
      ),
      labelLarge: TextStyle(
        fontSize: bodyMediumSize,
        fontWeight: FontWeight.w500,
        fontFamily: fontFamily,
        color: AppColors.textPrimaryDark,
      ),
    );
  }
}
