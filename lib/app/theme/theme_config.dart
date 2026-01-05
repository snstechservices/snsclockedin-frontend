import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Theme configuration for SNS Clocked In app
/// Uses design system tokens from UI_UX_DESIGN_SYSTEM.md
class ThemeConfig {
  ThemeConfig._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.lightTextTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 1.5, // Low elevation per design system
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ).copyWith(
        titleTextStyle: AppTypography.lightTextTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: AppTypography.appBarWeight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48), // WCAG minimum touch target
          padding: AppSpacing.buttonPadding,
          elevation: 1.5, // Low elevation per design system
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
          side: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.muted,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.muted,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        labelStyle: AppTypography.lightTextTheme.labelLarge,
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5, // Low elevation per design system
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumAll,
        ),
        margin: AppSpacing.cardMargin,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: AppColors.textPrimaryDark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: AppTypography.darkTextTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 1.5,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ).copyWith(
        titleTextStyle: AppTypography.darkTextTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: AppTypography.appBarWeight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          elevation: 1.5,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
          side: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFillDark,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.dividerDark,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.dividerDark,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        labelStyle: AppTypography.darkTextTheme.labelLarge,
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumAll,
        ),
        margin: AppSpacing.cardMargin,
      ),
    );
  }
}
