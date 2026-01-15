import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Clickable stat card that can be used for filtering
///
/// Extends StatCard with:
/// - Tap handler
/// - Selected state styling (highlighted border and background)
/// - Visual feedback
///
/// Used for status-based filtering (e.g., Pending/Approved/Rejected)
class ClickableStatCard extends StatelessWidget {
  const ClickableStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSelected = false,
    this.subtitle,
    this.width,
  });

  /// Title/label text
  final String title;

  /// Value to display
  final String value;

  /// Icon to display
  final IconData icon;

  /// Color theme for the card
  final Color color;

  /// Callback when card is tapped
  final VoidCallback onTap;

  /// Whether this card is currently selected (affects styling)
  final bool isSelected;

  /// Optional subtitle text
  final String? subtitle;

  /// Optional width constraint
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: AppRadius.mediumAll,
          border: Border.all(
            color: isSelected ? color : AppColors.textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Title
            Text(
              title,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Value
            Text(
              value,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
      ),
    );
  }
}
