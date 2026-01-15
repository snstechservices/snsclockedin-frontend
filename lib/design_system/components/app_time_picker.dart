import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

/// Styled time picker widget
///
/// Provides consistent time picker styling across the app.
/// Wraps Flutter's time picker with app-specific theming.
class AppTimePicker {
  AppTimePicker._();

  /// Show time picker with app styling
  ///
  /// Returns selected time or null if cancelled
  static Future<TimeOfDay?> pickTime({
    required BuildContext context,
    TimeOfDay? initialTime,
  }) async {
    final effectiveInitialTime = initialTime ?? TimeOfDay.now();

    return showTimePicker(
      context: context,
      initialTime: effectiveInitialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.surface,
          ),
          child: child!,
        );
      },
    );
  }
}
