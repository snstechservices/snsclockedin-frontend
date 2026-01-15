import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/company_calendar/presentation/company_calendar_widget.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';

/// Employee leave calendar screen with upcoming leave list
class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<LeaveStore>();
      final appState = context.read<AppState>();
      final userId = appState.userId ?? 'current_user';
      if (store.leaveRequests.isEmpty) {
        store.loadLeaves(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LeaveStore>();
    final appState = context.watch<AppState>();
    final userId = appState.userId ?? 'current_user';
    final leaves = store.getLeaveRequestsByUserId(userId);
    final upcoming = _getUpcomingLeaves(leaves);

    final pendingCount = leaves.where((r) => r.status == LeaveStatus.pending).length;
    final approvedCount = leaves.where((r) => r.status == LeaveStatus.approved).length;
    final upcomingCount = upcoming.length;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          _buildQuickStatsSection(pendingCount, approvedCount, upcomingCount),
          Expanded(
            child: ListView(
              padding: AppSpacing.lgAll,
              children: [
                const SectionHeader('Calendar'),
                AppCard(
                  padding: AppSpacing.mdAll,
                  child: const CompanyCalendarWidget(),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('Upcoming Leave'),
                if (store.isLoading && leaves.isEmpty)
                  const Padding(
                    padding: AppSpacing.xlAll,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (upcoming.isEmpty)
                  const EmptyState(
                    title: 'No upcoming leave',
                    message: 'Approved or pending leave will show here.',
                    icon: Icons.event_available_outlined,
                  )
                else
                  ...upcoming.map(_buildLeaveCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(int pending, int approved, int upcoming) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Leave Calendar Summary',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(
                  label: 'Pending',
                  value: pending.toString(),
                  color: AppColors.warning,
                  icon: Icons.hourglass_bottom,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildStatCard(
                  label: 'Approved',
                  value: approved.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: AppSpacing.md),
                _buildStatCard(
                  label: 'Upcoming',
                  value: upcoming.toString(),
                  color: AppColors.primary,
                  icon: Icons.event_available_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: 140,
      child: AppCard(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequest leave) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.mdAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${leave.leaveTypeDisplay} Leave',
                  style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildStatusChip(leave.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatDateRange(leave.startDate, leave.endDate),
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            leave.daysDisplay,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  StatusBadge _buildStatusChip(LeaveStatus status) {
    final (label, type) = switch (status) {
      LeaveStatus.pending => ('Pending', StatusBadgeType.pending),
      LeaveStatus.approved => ('Approved', StatusBadgeType.approved),
      LeaveStatus.rejected => ('Rejected', StatusBadgeType.rejected),
    };

    return StatusBadge(label: label, type: type);
  }

  List<LeaveRequest> _getUpcomingLeaves(List<LeaveRequest> leaves) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = leaves.where((leave) {
      final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      return end.isAtSameMomentAs(today) || end.isAfter(today);
    }).toList();
    upcoming.sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final startLocal = start.toLocal();
    final endLocal = end.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day) {
      return '${startLocal.day} ${months[startLocal.month - 1]}';
    } else if (startLocal.year == endLocal.year && startLocal.month == endLocal.month) {
      return '${startLocal.day}–${endLocal.day} ${months[startLocal.month - 1]}';
    } else if (startLocal.year == endLocal.year) {
      return '${startLocal.day} ${months[startLocal.month - 1]} – ${endLocal.day} ${months[endLocal.month - 1]}';
    }
    return '${startLocal.day}/${startLocal.month}/${startLocal.year} – ${endLocal.day}/${endLocal.month}/${endLocal.year}';
  }
}
