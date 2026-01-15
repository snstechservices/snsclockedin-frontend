import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

enum StatusBadgeType {
  pending,
  approved,
  rejected,
  cancelled,
  warning,
  info,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.outlined = true,
    this.compact = true,
  });

  final String label;
  final StatusBadgeType type;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colorsFor(type);
    final padding = compact
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: outlined ? bg : color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.35))
            : null,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.pending:
        return (AppColors.warning, AppColors.warning.withValues(alpha: 0.08));
      case StatusBadgeType.approved:
        return (AppColors.success, AppColors.success.withValues(alpha: 0.08));
      case StatusBadgeType.rejected:
        return (AppColors.error, AppColors.error.withValues(alpha: 0.08));
      case StatusBadgeType.cancelled:
        return (AppColors.textSecondary, AppColors.textSecondary.withValues(alpha: 0.08));
      case StatusBadgeType.warning:
        return (AppColors.warning, AppColors.warning.withValues(alpha: 0.08));
      case StatusBadgeType.info:
        return (AppColors.primary, AppColors.primary.withValues(alpha: 0.08));
    }
  }
}

