import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';
import 'package:sns_clocked_in/core/ui/error_state.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/pressable_scale.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';

/// Employee dashboard screen with greeting, status, and quick actions
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  Timer? _breakTimer;

  @override
  void initState() {
    super.initState();
    _startBreakTimer();
    _seedDebugData();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    super.dispose();
  }

  void _startBreakTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final timeStore = context.read<TimeTrackingStore>();
        if (timeStore.isOnBreak) {
          setState(() {}); // Trigger rebuild to update break timer
        }
      }
    });
  }

  void _seedDebugData() {
    if (!kDebugMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Seed time tracking demo data
      final timeStore = context.read<TimeTrackingStore>();
      timeStore.seedDebugData();

      // Seed leave data for current user
      final leaveStore = context.read<LeaveStore>();
      leaveStore.seedDebugData();

      // Seed profile (optional override)
      final profileStore = context.read<ProfileStore>();
      profileStore.seedDebugData();

      // Seed leave balances using current employees list if available
      try {
        final employeesStore = context.read<EmployeesStore>();
        final balancesStore = context.read<LeaveBalancesStore>();
        balancesStore.seedDebugData(employeesStore.allEmployees);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading(context);

    if (isLoading) {
      return const AppScreenScaffold(
        skipScaffold: true,
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          child: ListSkeleton(items: 5, itemHeight: 110),
        ),
      );
    }

    return AppScreenScaffold(
      skipScaffold: true,
      floatingActionButton: kDebugMode ? _buildDebugFAB(context) : null,
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Entrance(child: _buildGreetingCard(context)),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              delay: const Duration(milliseconds: 50),
              child: _buildStatCardsRow(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              delay: const Duration(milliseconds: 100),
              child: _buildStatusCard(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              delay: const Duration(milliseconds: 150),
              child: _buildQuickActionsSection(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              delay: const Duration(milliseconds: 200),
              child: _buildQuickStatsSection(context),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  bool _isLoading(BuildContext context) {
    // Stores may not expose isLoading consistently; avoid build failures by not accessing.
    return false;
  }

  Widget _buildGreetingCard(BuildContext context) {
    final profileStore = context.watch<ProfileStore>();
    final profile = profileStore.profile;

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
            profile.fullName.isNotEmpty ? profile.fullName : 'Employee',
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildRoleChip(),
              if (profile.department != null && profile.department!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _buildDepartmentChip(profile.department!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        'Employee',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDepartmentChip(String department) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        department,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    final timeStore = context.watch<TimeTrackingStore>();
    final leaveStore = context.watch<LeaveStore>();
    final leaveBalancesStore = context.watch<LeaveBalancesStore>();
    final appState = context.watch<AppState>();

    // Get hours worked today
    final hoursToday = timeStore.isClockedIn
        ? timeStore.currentDuration.inHours + (timeStore.currentDuration.inMinutes / 60)
        : 0.0;
    final hoursTodayStr = hoursToday > 0 ? hoursToday.toStringAsFixed(1) : '0';

    // Get leave balance (try to get from store, otherwise use mock)
    double leaveBalance = 0.0;
    try {
      final userId = appState.userId;
      if (userId != null) {
        final balance = leaveBalancesStore.getBalanceForEmployee(userId);
        if (balance != null) {
          leaveBalance = balance.annual + balance.sick + balance.casual;
        }
      }
    } catch (_) {
      // Use default
    }
    final leaveBalanceStr = leaveBalance.toStringAsFixed(0);

    // Get pending leave requests count
    int pendingLeaves = 0;
    try {
      pendingLeaves = leaveStore.getLeaveRequestsByStatus(LeaveStatus.pending).length;
    } catch (_) {
      // Use default
    }

    // Calculate attendance rate (mock for now - would come from attendance store)
    int attendanceRate = 95; // Mock value

    final hasData = leaveBalance > 0 || pendingLeaves > 0 || hoursToday > 0;

    if (!hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: EmptyState(
          title: 'No stats yet',
          message: 'Clock in or sync leave data to see your stats.',
          icon: Icons.query_stats,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          PressableScale(
            child: StatCard(
              title: 'Hours Today',
              value: hoursTodayStr,
              icon: Icons.access_time,
              color: AppColors.primary,
              width: 140,
              subtitle: timeStore.isClockedIn ? 'Working' : 'Not started',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressableScale(
            child: StatCard(
              title: 'Leave Balance',
              value: leaveBalanceStr,
              icon: Icons.calendar_today,
              color: AppColors.success,
              width: 140,
              subtitle: 'Days available',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressableScale(
            child: StatCard(
              title: 'Pending Leaves',
              value: pendingLeaves.toString(),
              icon: Icons.pending,
              color: AppColors.warning,
              width: 140,
              subtitle: 'Awaiting approval',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressableScale(
            child: StatCard(
              title: 'Attendance',
              value: '$attendanceRate%',
              icon: Icons.check_circle,
              color: AppColors.success,
              width: 140,
              subtitle: 'This month',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final timeStore = context.watch<TimeTrackingStore>();
    final isClockedIn = timeStore.isClockedIn;
    final isOnBreak = timeStore.isOnBreak;
    
    // Status Logic
    String statusText;
    String helperText;
    String clockInTime;
    Color statusColor;

    if (isClockedIn) {
      statusText = isOnBreak ? 'On Break' : 'Clocked In';
      helperText = isOnBreak
          ? 'You are currently on break'
          : 'You are currently working';
      statusColor = isOnBreak ? AppColors.warning : AppColors.success;
      
      // Get clock in time
      if (timeStore.currentEntry?.startTime != null) {
        final time = timeStore.currentEntry!.startTime!;
        clockInTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        clockInTime = '--:--';
      }
    } else {
      statusText = 'Not Clocked In';
      helperText = 'Tap Clock In to start your day';
      statusColor = AppColors.textSecondary;
      clockInTime = '';
    }

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Status',
                style: AppTypography.lightTextTheme.labelLarge,
              ),
              if (isClockedIn && !isOnBreak)
                _buildLiveTimer(timeStore.currentDuration),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusText,
                style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText,
            style: AppTypography.lightTextTheme.bodySmall,
          ),
          // Show clock in time and working duration when clocked in (but not on break)
          if (isClockedIn && clockInTime.isNotEmpty && !isOnBreak) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Clocked in at $clockInTime',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    'Working for ${_formatDuration(timeStore.currentDuration)}',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Show break start time when on break
          if (isOnBreak && timeStore.breakStartTime != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Break since ${_formatTime(timeStore.breakStartTime!)}',
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          // Show detailed break timer when on break
          if (isOnBreak) ...[
            const SizedBox(height: AppSpacing.md),
            _buildBreakTimerCard(context, timeStore),
          ],
          // Show break status details when breaks have been taken (but not currently on break)
          if (isClockedIn && !isOnBreak && timeStore.completedBreaks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildBreakStatusCard(context, timeStore),
          ],
          // Show break status details when not on break but breaks have been taken
          if (!isOnBreak && isClockedIn && timeStore.completedBreaks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildBreakStatusCard(context, timeStore),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildLiveTimer(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        '$hours:$minutes:$seconds',
        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final timeStore = context.watch<TimeTrackingStore>();
    final isClockedIn = timeStore.isClockedIn;
    final isOnBreak = timeStore.isOnBreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Quick Actions'),
        // When clocked in, show Clock Out and Start Break buttons
        if (isClockedIn) ...[
          Row(
            children: [
              Expanded(
                child: _buildClockOutButton(context, timeStore),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStartBreakButton(context, timeStore, isOnBreak),
              ),
            ],
          ),
        ] else ...[
          // When not clocked in, show Clock In button
          _buildPrimaryActionCard(context),
        ],
        const SizedBox(height: AppSpacing.md),
        // Two medium cards in a row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.calendar_today,
                label: 'Apply Leave',
                onTap: () => context.go('/e/leave'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionCard(
                icon: Icons.access_time,
                label: 'Timesheet',
                onTap: () => context.go('/e/timesheet'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Wide Profile card
        _buildActionCard(
          icon: Icons.person,
          label: 'Profile',
          onTap: () => context.go('/e/profile'),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard(BuildContext context) {
    final timeStore = context.watch<TimeTrackingStore>();
    final isLoading = timeStore.isLoading;

    return InkWell(
      onTap: isLoading ? null : () => timeStore.toggleClockStatus(),
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
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(
                Icons.login,
                color: Colors.white,
                size: 28,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isLoading ? 'Processing...' : 'Clock In',
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockOutButton(BuildContext context, TimeTrackingStore timeStore) {
    final isLoading = timeStore.isLoading;

    return InkWell(
      onTap: isLoading ? null : () => timeStore.toggleClockStatus(),
      borderRadius: AppRadius.mediumAll,
      child: Container(
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              else
                const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 28,
              ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isLoading ? 'Processing...' : 'Clock Out',
                style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartBreakButton(
    BuildContext context,
    TimeTrackingStore timeStore,
    bool isOnBreak,
  ) {
    final isLoading = timeStore.isLoading;

    return InkWell(
      onTap: isLoading
          ? null
          : isOnBreak
              ? () async {
                  // End break
                  await timeStore.endBreak();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Break ended'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              : () async {
                  // Show break type selector
                  final breakTypesStore = context.read<BreakTypesStore>();
                  
                  // Load break types if not already loaded
                  if (breakTypesStore.breakTypes.isEmpty && !breakTypesStore.isLoading) {
                    await breakTypesStore.load();
                  }

                  if (!context.mounted) return;
                  
                  final selectedBreakType = await _showBreakTypeSelector(
                    context,
                    breakTypesStore,
                  );

                  if (selectedBreakType != null && context.mounted) {
                    // Start break with selected type
                    await timeStore.startBreak(breakType: selectedBreakType.name);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${selectedBreakType.label} started'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
      borderRadius: AppRadius.mediumAll,
      child: Container(
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: isOnBreak ? AppColors.breakAction : AppColors.secondary,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: (isOnBreak ? AppColors.breakAction : AppColors.secondary)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                isOnBreak ? Icons.pause_circle : Icons.free_breakfast,
                color: Colors.white,
                size: 28,
              ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isLoading
                    ? 'Processing...'
                    : isOnBreak
                        ? 'End Break'
                        : 'Start Break',
                style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<BreakType?> _showBreakTypeSelector(
    BuildContext context,
    BreakTypesStore breakTypesStore,
  ) async {
    // Only show active break types to employees
    final breakTypes = breakTypesStore.activeBreakTypes;
    
    // If no break types, use default
    if (breakTypes.isEmpty) {
      return const BreakType(name: 'lunch', displayName: 'Lunch');
    }

    // If only one break type, return it directly
    if (breakTypes.length == 1) {
      return breakTypes.first;
    }

    // Show modal bottom sheet to select break type
    return showModalBottomSheet<BreakType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Consumer<BreakTypesStore>(
          builder: (context, store, _) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.coffee,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Select Break Type',
                        style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (store.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (store.activeBreakTypes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No break types available',
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: store.activeBreakTypes.length,
                        itemBuilder: (context, index) {
                          final breakType = store.activeBreakTypes[index];
                          // Parse color
                          Color? color;
                          if (breakType.color != null) {
                            try {
                              color = Color(int.parse(breakType.color!.replaceFirst('#', '0xFF')));
                            } catch (_) {
                              color = AppColors.primary;
                            }
                          } else {
                            color = AppColors.primary;
                          }
                          // Get icon
                          IconData icon = _getBreakTypeIcon(breakType.icon ?? 'coffee');
                          
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: EdgeInsets.zero,
                            onTap: () => Navigator.pop(context, breakType),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  // Icon with colored background
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: AppRadius.mediumAll,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          breakType.label,
                                          style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (breakType.durationRange.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            breakType.durationRange,
                                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (breakType.description != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            breakType.description!,
                                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Arrow
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Cancel button at bottom
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getBreakTypeIcon(String iconName) {
    switch (iconName) {
      case 'coffee':
        return Icons.coffee;
      case 'restaurant':
        return Icons.restaurant;
      case 'person':
        return Icons.person;
      case 'lunch_dining':
        return Icons.lunch_dining;
      default:
        return Icons.coffee;
    }
  }

  Widget _buildBreakTimerCard(BuildContext context, TimeTrackingStore timeStore) {
    final breakStartTime = timeStore.breakStartTime;
    final breakType = timeStore.currentBreakType ?? 'Break';
    final elapsed = timeStore.breakElapsedDuration;
    final breaksToday = timeStore.breaksTodayCount;
    
    // Default break duration: 15 minutes (can be overridden by break type)
    const defaultBreakDuration = Duration(minutes: 15);
    final breakDuration = defaultBreakDuration;
    final remaining = breakDuration - elapsed;
    final progress = elapsed.inSeconds / breakDuration.inSeconds;
    
    // Format time
    final now = DateTime.now();
    final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final startedTimeStr = breakStartTime != null
        ? '${breakStartTime!.hour.toString().padLeft(2, '0')}:${breakStartTime!.minute.toString().padLeft(2, '0')}:${breakStartTime!.second.toString().padLeft(2, '0')}'
        : '--:--:--';
    
    return Container(
      padding: AppSpacing.mdAll,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.mediumAll,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Break Timer',
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Current Time
          _buildBreakTimerRow(
            'Current Time',
            currentTimeStr,
            AppColors.success,
            Icons.access_time,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Started Time
          _buildBreakTimerRow(
            'Started',
            startedTimeStr,
            AppColors.success,
            Icons.play_circle_outline,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Break Type
          _buildBreakTimerRow(
            'Type',
            breakType,
            AppColors.primary,
            Icons.coffee,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Elapsed Time
          _buildBreakTimerRow(
            'Elapsed',
            _formatBreakDuration(elapsed),
            AppColors.warning,
            Icons.timer,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.textSecondary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Remaining Time
          _buildBreakTimerRow(
            'Remaining',
            _formatBreakDuration(remaining.isNegative ? Duration.zero : remaining),
            AppColors.success,
            Icons.hourglass_bottom,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Breaks Today Count
          _buildBreakTimerRow(
            '# Breaks Today',
            breaksToday.toString(),
            AppColors.textSecondary,
            Icons.repeat,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakTimerRow(String label, String value, Color valueColor, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatBreakDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  String _formatBreakDurationWithHours(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBreakStatusCard(BuildContext context, TimeTrackingStore timeStore) {
    final completedBreaks = timeStore.completedBreaks;
    final lastBreak = timeStore.lastBreak;
    final breaksCount = completedBreaks.length;

    if (lastBreak == null) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.mdAll,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: AppRadius.mediumAll,
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.coffee,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Break Status',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Breaks taken count
          _buildBreakStatusRow(
            Icons.check_circle,
            'Breaks taken: $breaksCount',
            AppColors.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Last break type
          _buildBreakStatusRow(
            Icons.play_arrow,
            'Last break: ${lastBreak.breakType}',
            AppColors.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Time range
          _buildBreakStatusRow(
            Icons.access_time,
            'Time: ${_formatTime(lastBreak.startTime)} - ${_formatTime(lastBreak.endTime)}',
            AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Duration
          _buildBreakStatusRow(
            Icons.timer,
            'Duration: ${_formatBreakDurationWithHours(lastBreak.duration)}',
            AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakStatusRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: textColor,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return AppCard(
      width: isWide ? double.infinity : null,
      padding: AppSpacing.lgAll,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakStatisticsSection(BuildContext context) {
    // Mock data for breaks (would come from attendance store)
    // final timeStore = context.watch<TimeTrackingStore>();
    const totalBreaks = 0; // timeStore.breaks.length
    const totalBreakTime = Duration.zero; // Calculate from breaks
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Break Statistics (Today)',
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.coffee,
                        size: 32,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        totalBreaks.toString(),
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Total Breaks',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 32,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${totalBreakTime.inHours}h ${totalBreakTime.inMinutes.remainder(60)}m',
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Total Break Time',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkHoursSummarySection(BuildContext context) {
    // Mock data for past 7 days (would come from attendance store)
    // final timeStore = context.watch<TimeTrackingStore>();
    const totalWorkHours = Duration(hours: 17, minutes: 44);
    const avgDailyHours = 17.7;
    const trendDown = -35; // Percentage change
    const trendUp = 30; // Percentage change
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Work Hours Summary (Past 7 Days)',
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${totalWorkHours.inHours}h ${totalWorkHours.inMinutes.remainder(60)}m',
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Total Work Hours',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '$trendDown% vs prev 7d',
                              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${avgDailyHours}h',
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Avg. Daily Hours',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '+$trendUp% vs prev 7d',
                              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsSection(BuildContext context) {
    // Mock data (would come from attendance store)
    const attendanceStreak = 1;
    const punctuality = 90;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Quick Stats',
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.star,
                        size: 32,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$attendanceStreak days',
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Attendance Streak',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$punctuality%',
                        style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Punctuality',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildDebugFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showDebugMenu(context),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.bug_report, color: Colors.white),
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
    
    if (!appState.isAuthenticated) {
      await appState.loginMock(role: role);
    } else {
      appState.setRole(role);
    }
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role switched to ${role.value}')),
      );
      // Navigation happens automatically via router listener
    }
  }
}
