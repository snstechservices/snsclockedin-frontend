import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Timesheet entry status
enum TimesheetStatus {
  approved,
  pending,
}

/// Mock timesheet entry
class TimesheetEntry {
  const TimesheetEntry({
    required this.date,
    required this.totalHours,
    required this.status,
  });

  final String date;
  final String totalHours;
  final TimesheetStatus status;
}

/// Shared "My Attendance" screen for employee and admin (self only)
class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({
    super.key,
    required this.roleScope,
  });

  final Role roleScope;

  @override
  Widget build(BuildContext context) {
    final attendanceStore = context.watch<AttendanceStore>();
    final clockStatus = attendanceStore.status;

    // Mock timesheet data
    final timesheetEntries = const [
      TimesheetEntry(
        date: '2024-01-15',
        totalHours: '8.0h',
        status: TimesheetStatus.approved,
      ),
      TimesheetEntry(
        date: '2024-01-14',
        totalHours: '7.5h',
        status: TimesheetStatus.pending,
      ),
      TimesheetEntry(
        date: '2024-01-13',
        totalHours: '8.0h',
        status: TimesheetStatus.approved,
      ),
    ];

    return AppScreenScaffold(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Today Status Card
            _buildStatusCard(context, clockStatus),
            const SizedBox(height: AppSpacing.lg),

            // Primary CTA
            _buildPrimaryCTA(context, clockStatus, attendanceStore),
            const SizedBox(height: AppSpacing.md),

            // Secondary Actions
            if (clockStatus == ClockStatus.clockedIn) ...[
              _buildSecondaryActions(context, attendanceStore),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Timesheet Preview
            _buildTimesheetPreview(context, timesheetEntries),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ClockStatus clockStatus) {
    String statusText;
    String helperText;
    Color statusColor;

    switch (clockStatus) {
      case ClockStatus.notClockedIn:
        statusText = 'Not Clocked In';
        helperText = 'Tap Clock In to start your day';
        statusColor = AppColors.textSecondary;
        break;
      case ClockStatus.clockedIn:
        statusText = 'Clocked In';
        helperText = 'You\'re currently working';
        statusColor = AppColors.success;
        break;
      case ClockStatus.onBreak:
        statusText = 'On Break';
        helperText = 'You\'re currently on break';
        statusColor = AppColors.warning;
        break;
    }

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Status',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusText,
                style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText,
            style: AppTypography.lightTextTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCTA(
    BuildContext context,
    ClockStatus clockStatus,
    AttendanceStore attendanceStore,
  ) {
    String label;
    IconData icon;
    VoidCallback onPressed;

    switch (clockStatus) {
      case ClockStatus.notClockedIn:
        label = 'Clock In';
        icon = Icons.login;
        onPressed = () => _handleClockIn(context, attendanceStore);
        break;
      case ClockStatus.clockedIn:
        label = 'Clock Out';
        icon = Icons.logout;
        onPressed = () => _handleClockOut(context, attendanceStore);
        break;
      case ClockStatus.onBreak:
        label = 'End Break';
        icon = Icons.play_arrow;
        onPressed = () => _handleEndBreak(context, attendanceStore);
        break;
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: AppRadius.mediumAll,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(
    BuildContext context,
    AttendanceStore attendanceStore,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleStartBreak(context, attendanceStore),
            icon: const Icon(Icons.coffee),
            label: const Text('Start Break'),
            style: OutlinedButton.styleFrom(
              padding: AppSpacing.mdAll,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Placeholder for View History
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View History - Coming soon')),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('View History'),
            style: OutlinedButton.styleFrom(
              padding: AppSpacing.mdAll,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimesheetPreview(
    BuildContext context,
    List<TimesheetEntry> timesheetEntries,
  ) {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Timesheet',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ...timesheetEntries.map((entry) => _buildTimesheetRow(context, entry)),
        ],
      ),
    );
  }

  Widget _buildTimesheetRow(BuildContext context, TimesheetEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.date,
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.totalHours,
                  style: AppTypography.lightTextTheme.bodySmall,
                ),
              ],
            ),
          ),
          _buildStatusChip(context, entry.status),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, TimesheetStatus status) {
    final isApproved = status == TimesheetStatus.approved;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isApproved
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        isApproved ? 'Approved' : 'Pending',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: isApproved ? AppColors.success : AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleClockIn(BuildContext context, AttendanceStore attendanceStore) {
    attendanceStore.clockIn();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clocked in successfully')),
    );
  }

  void _handleClockOut(
    BuildContext context,
    AttendanceStore attendanceStore,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clock Out'),
        content: const Text('Are you sure you want to clock out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              attendanceStore.clockOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clocked out successfully')),
              );
            },
            child: const Text('Clock Out'),
          ),
        ],
      ),
    );
  }

  void _handleStartBreak(
    BuildContext context,
    AttendanceStore attendanceStore,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start Break',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Are you sure you want to start your break?'),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                attendanceStore.startBreak();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Break started')),
                );
              },
              child: const Text('Start Break'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEndBreak(
    BuildContext context,
    AttendanceStore attendanceStore,
  ) {
    attendanceStore.endBreak();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Break ended')),
    );
  }
}

