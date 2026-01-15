import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

/// Styled date picker widget
///
/// Provides consistent date picker styling across the app.
/// Wraps Flutter's date picker with app-specific theming.
class AppDatePicker {
  AppDatePicker._();

  /// Show date picker with app styling
  ///
  /// Returns selected date or null if cancelled
  static Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) async {
    final now = DateTime.now();
    final effectiveInitialDate = initialDate ?? now;
    final effectiveFirstDate = firstDate ?? DateTime(now.year - 100);
    final effectiveLastDate = lastDate ?? DateTime(now.year + 100);

    return showDatePicker(
      context: context,
      initialDate: effectiveInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      helpText: helpText,
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

  /// Show date range picker with app styling
  ///
  /// Returns selected date range or null if cancelled
  static Future<DateTimeRange?> pickDateRange({
    required BuildContext context,
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) async {
    final now = DateTime.now();
    final effectiveFirstDate = firstDate ?? DateTime(now.year - 100);
    final effectiveLastDate = lastDate ?? now;

    return showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      helpText: helpText,
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
