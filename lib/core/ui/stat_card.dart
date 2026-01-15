import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Reusable stat card widget for displaying statistics
///
/// Displays:
/// - Icon (color-coded)
/// - Title (label)
/// - Value (count/number in large bold text)
/// - Optional subtitle
///
/// Uses AppCard as base with consistent styling
///
/// Example usage:
/// ```dart
/// StatCard(
///   title: 'Total Employees',
///   value: '42',
///   icon: Icons.people,
///   color: AppColors.primary,
///   width: 140,
/// )
/// ```
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.width,
    this.dense = false,
    this.borderColor,
    this.onTap,
  });

  /// Title/label text (e.g., "Pending", "Total Employees")
  final String title;

  /// Value to display (e.g., "5", "42")
  final String value;

  /// Icon to display
  final IconData icon;

  /// Color theme for the card (primary, success, warning, error)
  final Color color;

  /// Optional subtitle text
  final String? subtitle;

  /// Optional width constraint
  final double? width;

  /// Dense layout for compact spaces
  final bool dense;

  /// Optional border color
  final Color? borderColor;

  /// Optional tap handler
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: width,
      padding: dense ? AppSpacing.smAll : AppSpacing.lgAll,
      borderColor: borderColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Icon(
            icon,
            color: color,
            size: dense ? 18 : 24,
          ),
          SizedBox(height: dense ? AppSpacing.xs : AppSpacing.sm),
          // Title
          Text(
            title,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: dense ? 11 : 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Value
          Text(
            value,
            style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: dense ? 16 : 20,
            ),
          ),
          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
