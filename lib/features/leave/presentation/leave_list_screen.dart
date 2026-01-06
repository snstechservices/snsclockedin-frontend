import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Employee leave list screen
class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
  @override
  void initState() {
    super.initState();
    // Seed sample data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveStore>().seedSampleData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final leaveStore = context.watch<LeaveStore>();
    final userLeaves = leaveStore.getLeaveRequestsByUserId(appState.userId ?? 'current_user');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: userLeaves.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
                padding: AppSpacing.lgAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'My Leave Requests',
                      style: AppTypography.lightTextTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...userLeaves.map((leave) => _buildLeaveCard(leave)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/e/leave/apply'),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Leave Requests',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap the button below to apply for leave',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.go('/e/leave/apply'),
              icon: const Icon(Icons.add),
              label: const Text('Apply Leave'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequest leave) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leave.leaveTypeDisplay,
                style: AppTypography.lightTextTheme.headlineMedium,
              ),
              _buildStatusChip(leave.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                style: AppTypography.lightTextTheme.bodyMedium,
              ),
              if (leave.isHalfDay) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    leave.halfDayPart == HalfDayPart.am ? 'AM' : 'PM',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            leave.daysDisplay,
            style: AppTypography.lightTextTheme.bodySmall,
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              leave.reason,
              style: AppTypography.lightTextTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(LeaveStatus status) {
    Color color;
    switch (status) {
      case LeaveStatus.pending:
        color = AppColors.warning;
        break;
      case LeaveStatus.approved:
        color = AppColors.success;
        break;
      case LeaveStatus.rejected:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        status == LeaveStatus.pending
            ? 'Pending'
            : status == LeaveStatus.approved
                ? 'Approved'
                : 'Rejected',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

