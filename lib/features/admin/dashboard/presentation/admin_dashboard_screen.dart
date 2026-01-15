import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';
import 'package:sns_clocked_in/core/ui/error_state.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/pressable_scale.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:intl/intl.dart';

/// Admin dashboard screen (mock data, no backend)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Mocked data placeholders
  final String _adminName = 'Alex Johnson';
  final String _companyName = 'S&S Accounting';

  @override
  void initState() {
    super.initState();
    _seedDebugData();
  }

  void _seedDebugData() {
    if (!kDebugMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Employees
      final employeesStore = context.read<EmployeesStore>();
      employeesStore.seedDebugData();

      // Leave approvals
      final leaveApprovalsStore = context.read<AdminLeaveApprovalsStore>();
      leaveApprovalsStore.seedDebugData();

      // Employee leave store/balances and time tracking (for dashboards using these later)
      try {
        final leaveStore = context.read<LeaveStore>();
        leaveStore.seedDebugData();
      } catch (_) {}

      try {
        final balancesStore = context.read<LeaveBalancesStore>();
        balancesStore.seedDebugData(employeesStore.allEmployees);
      } catch (_) {}

      try {
        final timeStore = context.read<TimeTrackingStore>();
        timeStore.seedDebugData();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayLabel = DateFormat('EEEE, MMM d').format(DateTime.now());

    final isLoading = _isLoading(context);

    if (isLoading) {
      return const AppScreenScaffold(
        skipScaffold: true,
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          child: ListSkeleton(items: 5, itemHeight: 120),
        ),
      );
    }


    return AppScreenScaffold(
      skipScaffold: true,
      floatingActionButton: kDebugMode ? _buildDebugFAB(context) : null,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match pattern)
          _buildQuickStatsSection(context),
          // Main content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.lgAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(child: _buildHeaderCard(todayLabel: todayLabel)),
                  const SizedBox(height: AppSpacing.lg),
                  const SizedBox(height: AppSpacing.xl),
            Entrance(
              delay: const Duration(milliseconds: 100),
              child: _buildQuickActions(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            Entrance(
              delay: const Duration(milliseconds: 150),
              child: _buildAttendanceOverview(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            Entrance(
              delay: const Duration(milliseconds: 200),
              child: _buildDepartmentTable(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            Entrance(
              delay: const Duration(milliseconds: 250),
              child: _buildNotificationsAndReports(context),
            ),
            const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context) {
    final data = _computeStats(context);

    final cards = [
      (
        title: 'Total Users',
        value: data.totalUsers.toString(),
        icon: Icons.people,
        color: AppColors.primary,
        onTap: () => _showStatsSheet(
              context,
              title: 'All Employees',
              type: _StatsListType.totalUsers,
            ),
      ),
      (
        title: 'Present',
        value: data.present.toString(),
        icon: Icons.check_circle,
        color: AppColors.success,
        onTap: () => _showStatsSheet(
              context,
              title: 'Present Employees',
              type: _StatsListType.present,
            ),
      ),
      (
        title: 'On Leave',
        value: data.onLeave.toString(),
        icon: Icons.beach_access,
        color: AppColors.secondary,
        onTap: () => _showStatsSheet(
              context,
              title: 'Employees on Leave',
              type: _StatsListType.onLeave,
            ),
      ),
      (
        title: 'Absent',
        value: data.absent.toString(),
        icon: Icons.person_off,
        color: AppColors.error,
        onTap: () => _showStatsSheet(
              context,
              title: 'Absent Employees',
              type: _StatsListType.absent,
            ),
      ),
      (
        title: 'Pending Approvals',
        value: data.pendingApprovals.toString(),
        icon: Icons.approval,
        color: AppColors.warning,
        onTap: () => _showStatsSheet(
              context,
              title: 'Pending Approvals',
              type: _StatsListType.pendingApprovals,
            ),
      ),
    ];

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
              Icon(Icons.dashboard, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Dashboard Summary',
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
                for (final card in cards) ...[
                  SizedBox(
                    width: 140,
                    child: _buildStatCard(
                      title: card.title,
                      value: card.value,
                      color: card.color,
                      icon: card.icon,
                      onTap: card.onTap,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
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
    );
  }

  void _showStatsSheet(
    BuildContext context, {
    required String title,
    required _StatsListType type,
  }) {
    final employeesStore = context.read<EmployeesStore>();
    final leaveStore = context.read<AdminLeaveApprovalsStore>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final content = _buildStatsSheetContent(
          context,
          type,
          employeesStore,
          leaveStore,
        );

        return SafeArea(
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: content),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSheetContent(
    BuildContext context,
    _StatsListType type,
    EmployeesStore employeesStore,
    AdminLeaveApprovalsStore leaveStore,
  ) {
    switch (type) {
      case _StatsListType.totalUsers:
        return _buildEmployeeList(employeesStore.allEmployees);
      case _StatsListType.present:
        return _buildEmployeeList(
          employeesStore.allEmployees
              .where((employee) => employee.status == EmployeeStatus.active)
              .toList(),
        );
      case _StatsListType.absent:
        return _buildEmployeeList(
          employeesStore.allEmployees
              .where((employee) => employee.status == EmployeeStatus.inactive)
              .toList(),
        );
      case _StatsListType.onLeave:
        final today = DateTime.now();
        final onLeave = leaveStore
            .getLeavesByStatus(LeaveStatus.approved)
            .where((leave) => leave.startDate.isBefore(today) && leave.endDate.isAfter(today))
            .toList();
        return _buildLeaveList(onLeave, emptyMessage: 'No employees on leave today.');
      case _StatsListType.pendingApprovals:
        final pending = leaveStore.getLeavesByStatus(LeaveStatus.pending);
        return _buildLeaveList(pending, emptyMessage: 'No pending approvals.');
    }
  }

  Widget _buildEmployeeList(List<Employee> employees) {
    if (employees.isEmpty) {
      return const EmptyState(
        title: 'No employees found',
        message: 'There are no employees in this category.',
        icon: Icons.people_outline,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final employee = employees[index];
        return AppCard(
          padding: AppSpacing.mdAll,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  employee.fullName.substring(0, 1).toUpperCase(),
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.department,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildEmployeeStatusBadge(employee.status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveList(List<LeaveRequest> leaves, {required String emptyMessage}) {
    if (leaves.isEmpty) {
      return EmptyState(
        title: 'Nothing to show',
        message: emptyMessage,
        icon: Icons.event_available_outlined,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: leaves.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final leave = leaves[index];
        return AppCard(
          padding: AppSpacing.mdAll,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.userName ?? 'Employee',
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leave.leaveTypeDisplay} • ${_formatDateRange(leave.startDate, leave.endDate)}',
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildLeaveStatusBadge(leave.status),
            ],
          ),
        );
      },
    );
  }

  StatusBadge _buildEmployeeStatusBadge(EmployeeStatus status) {
    final (label, type) = status == EmployeeStatus.active
        ? ('Active', StatusBadgeType.approved)
        : ('Inactive', StatusBadgeType.cancelled);
    return StatusBadge(label: label, type: type, compact: true);
  }

  StatusBadge _buildLeaveStatusBadge(LeaveStatus status) {
    final (label, type) = switch (status) {
      LeaveStatus.pending => ('Pending', StatusBadgeType.pending),
      LeaveStatus.approved => ('Approved', StatusBadgeType.approved),
      LeaveStatus.rejected => ('Rejected', StatusBadgeType.rejected),
    };
    return StatusBadge(label: label, type: type, compact: true);
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

  Widget _buildHeaderCard({required String todayLabel}) {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _adminName,
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildChip(
                label: 'Admin',
                color: AppColors.primary.withValues(alpha: 0.12),
                textColor: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(
                label: _companyName,
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                textColor: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                todayLabel,
                style: AppTypography.lightTextTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isLoading(BuildContext context) {
    // Stores do not expose isLoading; keep UI responsive by avoiding false flags.
    return false;
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        label: 'Employees',
        icon: Icons.people_outline,
        onTap: () => context.go('/a/employees'),
      ),
      _QuickAction(
        label: 'Leave',
        icon: Icons.calendar_today,
        onTap: () => context.go('/a/leave/requests'),
      ),
      _QuickAction(
        label: 'Attendance',
        icon: Icons.access_time,
        onTap: () => context.go('/a/attendance'),
      ),
      _QuickAction(
        label: 'Timesheets',
        icon: Icons.schedule,
        onTap: () => context.go('/a/timesheets'),
      ),
      _QuickAction(
        label: 'Reports',
        icon: Icons.bar_chart,
        onTap: () => context.go('/a/reports'),
      ),
      _QuickAction(
        label: 'Settings',
        icon: Icons.settings,
        onTap: () => context.go('/a/settings'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick Actions'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: actions
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _QuickActionCard(action: a),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceOverview(BuildContext context) {
    final data = _computeStats(context);
    if (data.totalUsers == 0) {
      return AppCard(
        padding: AppSpacing.lgAll,
        child: const EmptyState(
          title: 'No attendance data',
          message: 'Add employees or sync attendance to see today\'s breakdown.',
          icon: Icons.insights_outlined,
        ),
      );
    }

    final total = data.totalUsers;
    final segments = [
      _AttendanceSegment('Present', data.present, AppColors.success),
      _AttendanceSegment('On Leave', data.onLeave, AppColors.secondary),
      _AttendanceSegment('Absent', data.absent, AppColors.error),
    ];

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Attendance",
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments
                      .map(
                        (s) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AttendanceRow(
                            label: s.label,
                            count: s.count,
                            percent: ((s.count / total) * 100).round(),
                            color: s.color,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 1,
                child: _AttendanceBar(
                  present: data.present,
                  onLeave: data.onLeave,
                  absent: data.absent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentTable(BuildContext context) {
    // Mock department stats; in future wire to store
    final rows = [
      ('Engineering', 12, 1, 1),
      ('Finance', 8, 0, 1),
      ('HR', 5, 0, 0),
      ('Operations', 10, 1, 0),
    ];

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Department-wise Attendance',
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Present')),
                DataColumn(label: Text('On Leave')),
                DataColumn(label: Text('Absent')),
              ],
              rows: rows
                  .map(
                    (r) => DataRow(
                      cells: [
                        DataCell(Text(r.$1)),
                        DataCell(Text(r.$2.toString())),
                        DataCell(Text(r.$3.toString())),
                        DataCell(Text(r.$4.toString())),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsAndReports(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Updates'),
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: AppSpacing.lgAll,
                child: const EmptyState(
                  title: 'No notifications',
                  message: "You're all caught up. New updates will appear here.",
                  icon: Icons.notifications_none,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppCard(
                padding: AppSpacing.lgAll,
                child: ErrorState(
                  title: 'No reports generated',
                  message: 'Create your first attendance or leave report.',
                  icon: Icons.bar_chart,
                  retryLabel: 'Open Reports',
                  onRetry: () => context.go('/a/reports'),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryActionCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumAll,
      child: Container(
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
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

  Widget _secondaryActionCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: AppSpacing.lgAll,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    );
  }

  Widget _buildOverviewPlaceholder() {
    return AppCard(
      padding: AppSpacing.xlAll,
      child: Column(
          children: [
            Icon(Icons.show_chart, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Overview',
              style: AppTypography.lightTextTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reports and charts will appear here',
              style: AppTypography.lightTextTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
    );
  }

  Widget? _buildDebugFAB(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: FloatingActionButton.small(
        onPressed: () => _showDebugMenu(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
      ),
    );
  }

  void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DebugMenuSheet(),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: action.onTap,
      padding: AppSpacing.mdAll,
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, color: AppColors.primary, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action.label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum _StatsListType {
  totalUsers,
  present,
  onLeave,
  absent,
  pendingApprovals,
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _AttendanceSegment {
  const _AttendanceSegment(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final String label;
  final int count;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium,
          ),
        ),
        Text(
          '$count',
          style: AppTypography.lightTextTheme.bodyMedium,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$percent%',
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.present,
    required this.onLeave,
    required this.absent,
  });

  final int present;
  final int onLeave;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final total = (present + onLeave + absent).clamp(1, 999999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            color: AppColors.textSecondary.withValues(alpha: 0.1),
          ),
          child: Row(
            children: [
              _barSegment(AppColors.success, present, total, left: true),
              _barSegment(AppColors.secondary, onLeave, total),
              _barSegment(AppColors.error, absent, total, right: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Headcount: $total',
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _barSegment(Color color, int value, int total,
      {bool left = false, bool right = false}) {
    final flex = value <= 0 ? 1 : value;
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.horizontal(
            left: left ? Radius.circular(AppRadius.sm) : Radius.zero,
            right: right ? Radius.circular(AppRadius.sm) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.totalUsers,
    required this.present,
    required this.onLeave,
    required this.absent,
    required this.pendingApprovals,
  });

  final int totalUsers;
  final int present;
  final int onLeave;
  final int absent;
  final int pendingApprovals;
}

_DashboardStats _computeStats(BuildContext context) {
  int totalUsers = 42;
  int onLeave = 3;
  int absent = 4;
  int pendingApprovals = 7;

  try {
    final employeesStore = context.read<EmployeesStore>();
    // Don't seed data during build - it causes setState during build error
    // Data should be seeded elsewhere (e.g., in initState or app initialization)
    totalUsers = employeesStore.totalCount;
  } catch (_) {}

  try {
    final leaveStore = context.read<AdminLeaveApprovalsStore>();
    pendingApprovals = leaveStore.pendingCount;
    onLeave = leaveStore.getLeavesByStatus(LeaveStatus.approved)
        .where((l) {
          final now = DateTime.now();
          return l.startDate.isBefore(now) && l.endDate.isAfter(now);
        })
        .length;
  } catch (_) {}

  final present = (totalUsers - onLeave - absent).clamp(0, totalUsers);

  return _DashboardStats(
    totalUsers: totalUsers,
    present: present,
    onLeave: onLeave,
    absent: absent,
    pendingApprovals: pendingApprovals,
  );
}

class _DebugMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debug Menu',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Current Role: ${appState.currentRole.value}',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/debug');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Debug Menu'),
              style: ElevatedButton.styleFrom(
                padding: AppSpacing.lgAll,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Quick Role Switch',
              style: AppTypography.lightTextTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.employee),
                    child: const Text('Employee'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.admin),
                    child: const Text('Admin'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.superAdmin),
                    child: const Text('Super Admin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _switchRole(BuildContext context, Role role) async {
    final appState = context.read<AppState>();
    
    // Ensure user is authenticated when switching roles
    if (!appState.isAuthenticated) {
      await appState.loginMock(role: role);
    } else {
      appState.setRole(role);
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Role switched to ${role.value}')),
    );
    context.go('/home');
  }
}
