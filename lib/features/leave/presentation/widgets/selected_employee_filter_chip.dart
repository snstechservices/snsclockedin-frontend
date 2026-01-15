import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';

/// Reusable chip widget for displaying selected employee filter
/// Shows employee name, optional department, and a clear button
class SelectedEmployeeFilterChip extends StatelessWidget {
  const SelectedEmployeeFilterChip({super.key});

  @override
  Widget build(BuildContext context) {
    final contextStore = context.watch<AdminLeaveContextStore>();
    
    if (!contextStore.hasSelectedEmployee) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              contextStore.selectedEmployeeName ?? 'Employee',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (contextStore.selectedEmployeeDepartment != null) ...[
              Text(
                ' • ${contextStore.selectedEmployeeDepartment}',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: () => contextStore.clearSelectedEmployee(),
              borderRadius: AppRadius.smAll,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
