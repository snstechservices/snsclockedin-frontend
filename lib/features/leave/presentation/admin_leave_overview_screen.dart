import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_accrual_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_cash_out_store.dart';
import 'package:sns_clocked_in/features/leave/presentation/widgets/selected_employee_filter_chip.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_accrual_log.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_cash_out.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_balances_screen.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_history_screen.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/notifications/domain/app_notification.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin leave overview screen with tabs
class AdminLeaveOverviewScreen extends StatefulWidget {
  const AdminLeaveOverviewScreen({super.key});

  @override
  State<AdminLeaveOverviewScreen> createState() =>
      _AdminLeaveOverviewScreenState();
}

class _AdminLeaveOverviewScreenState extends State<AdminLeaveOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncingFromRoute = false; // Flag to prevent double animation
  String? _lastSyncedRoute; // Track last route we synced from

  @override
  void initState() {
    super.initState();
    // Initialize with default index, will be updated in didChangeDependencies
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get initial route to set correct initial index
    // This must be in didChangeDependencies, not initState, because
    // GoRouterState.of(context) requires inherited widgets to be available
    final location = GoRouterState.of(context).uri.path;
    int targetIndex = 0;
    if (location == '/a/leave/balances') {
      targetIndex = 1;
    } else if (location == '/a/leave/accruals') {
      targetIndex = 2;
    } else if (location == '/a/leave/cashout') {
      targetIndex = 3;
    }
    
    // Only update if index differs and we haven't synced this route yet
    if (_tabController.index != targetIndex && _lastSyncedRoute != location) {
      _isSyncingFromRoute = true;
      _lastSyncedRoute = location;
      // Temporarily remove listener to prevent navigation loop
      _tabController.removeListener(_handleTabChange);
      _tabController.animateTo(targetIndex);
      // Re-add listener after animation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _tabController.addListener(_handleTabChange);
          _isSyncingFromRoute = false;
        }
      });
    } else if (_lastSyncedRoute == null) {
      // First time setup
      _lastSyncedRoute = location;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// Update tab index based on current route
  /// Prevents double animation by checking if route already matches
  void _updateTabFromRoute() {
    if (!mounted || _tabController.indexIsChanging) return;
    final location = GoRouterState.of(context).uri.path;
    
    // Skip if we already synced this route
    if (_lastSyncedRoute == location) return;
    
    int targetIndex = 0; // Default to Requests
    if (location == '/a/leave/balances') {
      targetIndex = 1;
    } else if (location == '/a/leave/accruals') {
      targetIndex = 2;
    } else if (location == '/a/leave/cashout') {
      targetIndex = 3;
    }
    
    // Only update if index differs to prevent loops
    if (_tabController.index != targetIndex) {
      _isSyncingFromRoute = true;
      _lastSyncedRoute = location;
      // Temporarily remove listener to prevent navigation loop
      _tabController.removeListener(_handleTabChange);
      _tabController.animateTo(targetIndex);
      // Re-add listener after animation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _tabController.addListener(_handleTabChange);
          _isSyncingFromRoute = false;
        }
      });
    } else {
      _lastSyncedRoute = location;
    }
  }

  /// Handle tab change - navigate to corresponding route
  void _handleTabChange() {
    // Skip navigation if we're syncing from route to prevent loops
    if (_isSyncingFromRoute) return;
    
    if (!_tabController.indexIsChanging && mounted) {
      final index = _tabController.index;
      String route;
      switch (index) {
        case 0:
          route = '/a/leave/requests';
          break;
        case 1:
          route = '/a/leave/balances';
          break;
        case 2:
          route = '/a/leave/accruals';
          break;
        case 3:
          route = '/a/leave/cashout';
          break;
        default:
          route = '/a/leave/requests';
      }
      final currentRoute = GoRouterState.of(context).uri.path;
      // Only navigate if route is different to prevent loops
      if (currentRoute != route) {
        _lastSyncedRoute = null; // Clear to allow sync on next route change
        context.go(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminLeaveApprovalsStore>();

    // Count pending leaves (use store getter)
    final pendingCount = store.pendingCount;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Tab Bar
          _buildTabBar(pendingCount),
          // Quick Stats at top (always visible, match legacy)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => _buildTabSummary(context, _tabController.index),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Requests Tab
                const _AdminApprovalsTabContent(),
                // Balances Tab
                const AdminLeaveBalancesScreen(),
                // Accrual Logs Tab
                const _AccrualLogsTabContent(),
                // Cash Out Tab
                const _CashOutTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(int pendingCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          Tab(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.approval_outlined),
                if (pendingCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        pendingCount > 99 ? '99+' : '$pendingCount',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            text: 'Requests',
          ),
          const Tab(
            icon: Icon(Icons.account_balance_wallet_outlined),
            text: 'Balances',
          ),
          const Tab(
            icon: Icon(Icons.timeline_outlined),
            text: 'Accruals',
          ),
          const Tab(
            icon: Icon(Icons.monetization_on_outlined),
            text: 'Cash Out',
          ),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTabSummary(BuildContext context, int index) {
    switch (index) {
      case 0:
        return _buildLeaveRequestsSummary(context);
      case 1:
        return _buildBalancesSummary(context);
      case 2:
        return _buildAccrualsSummary(context);
      case 3:
        return _buildCashOutSummary(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLeaveRequestsSummary(BuildContext context) {
    return Consumer<AdminLeaveApprovalsStore>(
      builder: (context, store, _) {
        final pendingCount = store.pendingCount;
        final approvedCount = store.approvedCount;
        final rejectedCount = store.rejectedCount;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Leave Summary',
                    style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go('/a/leave/apply'),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Request leave'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: StatCard(
                        title: 'Pending',
                        value: pendingCount.toString(),
                        color: AppColors.warning,
                        icon: Icons.pending,
                        dense: true,
                        borderColor: store.selectedFilter == LeaveStatus.pending
                            ? AppColors.warning.withValues(alpha: 0.6)
                            : AppColors.textSecondary.withValues(alpha: 0.15),
                        onTap: () => _applySummaryFilter(store, LeaveStatus.pending),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: StatCard(
                        title: 'Approved',
                        value: approvedCount.toString(),
                        color: AppColors.success,
                        icon: Icons.check_circle,
                        dense: true,
                        borderColor: store.selectedFilter == LeaveStatus.approved
                            ? AppColors.success.withValues(alpha: 0.6)
                            : AppColors.textSecondary.withValues(alpha: 0.15),
                        onTap: () => _applySummaryFilter(store, LeaveStatus.approved),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: StatCard(
                        title: 'Rejected',
                        value: rejectedCount.toString(),
                        color: AppColors.error,
                        icon: Icons.cancel,
                        dense: true,
                        borderColor: store.selectedFilter == LeaveStatus.rejected
                            ? AppColors.error.withValues(alpha: 0.6)
                            : AppColors.textSecondary.withValues(alpha: 0.15),
                        onTap: () => _applySummaryFilter(store, LeaveStatus.rejected),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalancesSummary(BuildContext context) {
    final store = context.watch<AdminLeaveBalancesStore>();
    final total = store.employees.length;
    final active = store.employees.where((e) => e.employee.status == EmployeeStatus.active).length;
    final inactive = total - active;
    final selected = store.statusFilter;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Balances Summary',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Employees',
                  value: total.toString(),
                  color: AppColors.primary,
                  icon: Icons.people_outline,
                  dense: true,
                  borderColor: selected == null
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.15),
                  onTap: () {
                    if (selected == null) {
                      store.setStatusFilter(null);
                    } else {
                      store.setStatusFilter(null);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Active',
                  value: active.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  dense: true,
                  borderColor: selected == EmployeeStatus.active
                      ? AppColors.success.withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.15),
                  onTap: () {
                    store.setStatusFilter(
                      selected == EmployeeStatus.active ? null : EmployeeStatus.active,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Inactive',
                  value: inactive.toString(),
                  color: AppColors.warning,
                  icon: Icons.person_off_outlined,
                  dense: true,
                  borderColor: selected == EmployeeStatus.inactive
                      ? AppColors.warning.withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.15),
                  onTap: () {
                    store.setStatusFilter(
                      selected == EmployeeStatus.inactive ? null : EmployeeStatus.inactive,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccrualsSummary(BuildContext context) {
    final store = context.watch<LeaveAccrualStore>();
    final logs = store.logs;
    final uniqueEmployees = logs.map((log) => log.employeeId).toSet().length;
    final totalHours = logs.fold<double>(0, (sum, log) => sum + log.hoursAccrued);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Accruals Summary',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Logs',
                  value: logs.length.toString(),
                  color: AppColors.primary,
                  icon: Icons.receipt_long,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Employees',
                  value: uniqueEmployees.toString(),
                  color: AppColors.secondary,
                  icon: Icons.people_outline,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Hours',
                  value: totalHours.toStringAsFixed(1),
                  color: AppColors.success,
                  icon: Icons.access_time,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashOutSummary(BuildContext context) {
    final store = context.watch<LeaveCashOutStore>();
    final pending = store.items.where((i) => i.status == CashOutStatus.pending).length;
    final approved = store.items.where((i) => i.status == CashOutStatus.approved).length;
    final rejected = store.items.where((i) => i.status == CashOutStatus.rejected).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Cash Out Summary',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Pending',
                  value: pending.toString(),
                  color: AppColors.warning,
                  icon: Icons.pending,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Approved',
                  value: approved.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Rejected',
                  value: rejected.toString(),
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applySummaryFilter(AdminLeaveApprovalsStore store, LeaveStatus status) {
    _tabController.animateTo(0);
    if (store.selectedFilter == status) {
      store.setSelectedFilter(null);
    } else {
      store.setSelectedFilter(status);
    }
  }
}

/// Requests tab content (extracted from AdminLeaveScreen)
class _AdminApprovalsTabContent extends StatefulWidget {
  const _AdminApprovalsTabContent();

  @override
  State<_AdminApprovalsTabContent> createState() =>
      _AdminApprovalsTabContentState();
}

class _AdminApprovalsTabContentState extends State<_AdminApprovalsTabContent> {

  @override
  void initState() {
    super.initState();
    // Only load if we don't have data (avoids API calls when we have seeded/cached data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AdminLeaveApprovalsStore>();
      // Only load if we don't have data
      if (store.pendingLeaves.isEmpty) {
        store.loadPending();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminLeaveApprovalsStore>();
    final contextStore = context.watch<AdminLeaveContextStore>();
    final selectedFilter = store.selectedFilter;
    
    // Apply status filter
    var filteredLeaves = selectedFilter == null
        ? store.pendingLeaves
        : store.pendingLeaves.where((l) => l.status == selectedFilter).toList();
    
    // Apply employee filter if selected
    if (contextStore.selectedEmployeeId != null) {
      filteredLeaves = filteredLeaves
          .where((l) => l.userId == contextStore.selectedEmployeeId)
          .toList();
    }

    // Ensure mutable list
    filteredLeaves = List<LeaveRequest>.from(filteredLeaves);

    return Column(
      children: [
        if (store.usingStale) _buildCacheHint(context),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: store.isLoading && filteredLeaves.isEmpty
              ? const ListSkeleton(items: 4)
              : store.error != null && filteredLeaves.isEmpty
                  ? _buildErrorState(context, store)
                  : filteredLeaves.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => store.loadPending(forceRefresh: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: filteredLeaves.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: _buildLeaveCard(
                                  context,
                                  filteredLeaves[index],
                                  store,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCacheHint(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Showing cached data',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
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
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Leave Requests',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Builder(
              builder: (context) {
                final store = context.watch<AdminLeaveApprovalsStore>();
                final selectedFilter = store.selectedFilter;
                return Text(
                  selectedFilter == null
                      ? 'No leave requests found'
                      : 'No ${selectedFilter == LeaveStatus.pending ? "pending" : selectedFilter == LeaveStatus.approved ? "approved" : "rejected"} requests',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AdminLeaveApprovalsStore store,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load leave requests',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                store.error ?? 'Unknown error',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: store.isLoading
                    ? null
                    : () => store.loadPending(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveCard(
    BuildContext context,
    LeaveRequest leave,
    AdminLeaveApprovalsStore store,
  ) {
    final isLeaveLoading = store.isLeaveLoading(leave.id);
    final isDisabled = store.isLoading || isLeaveLoading;

    // Format date range with days count (e.g., "20–22 Jan • 3 days")
    final dateRangeStr = _formatDateRange(leave.startDate, leave.endDate);
    final daysStr = leave.daysDisplay;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.lgAll,
      onTap: () => _showLeaveDetail(context, leave, store),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee name + department
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.userName ?? 'Employee',
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (leave.department != null) ...[
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        leave.department!,
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusChip(leave.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Leave type chip
          _buildLeaveTypeChip(leave.leaveType),
          const SizedBox(height: AppSpacing.sm),
          // Date range + days count
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '$dateRangeStr • $daysStr',
                  style: AppTypography.lightTextTheme.bodyMedium,
                ),
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
          // Reason preview (max 2 lines)
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              leave.reason,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveTypeChip(LeaveType leaveType) {
    Color color;
    switch (leaveType) {
      case LeaveType.annual:
        color = AppColors.primary;
        break;
      case LeaveType.sick:
        color = AppColors.warning;
        break;
      case LeaveType.unpaid:
        color = AppColors.textSecondary;
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
        leaveType == LeaveType.annual
            ? 'Annual'
            : leaveType == LeaveType.sick
                ? 'Sick'
                : 'Unpaid',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final startLocal = start.toLocal();
    final endLocal = end.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    if (startLocal.year == endLocal.year && startLocal.month == endLocal.month && startLocal.day == endLocal.day) {
      // Same day
      return '${startLocal.day} ${months[startLocal.month - 1]}';
    } else if (startLocal.year == endLocal.year && startLocal.month == endLocal.month) {
      // Same month
      return '${startLocal.day}–${endLocal.day} ${months[startLocal.month - 1]}';
    } else if (startLocal.year == endLocal.year) {
      // Same year, different months
      return '${startLocal.day} ${months[startLocal.month - 1]} – ${endLocal.day} ${months[endLocal.month - 1]}';
    } else {
      // Different years
      return '${startLocal.day}/${startLocal.month}/${startLocal.year} – ${endLocal.day}/${endLocal.month}/${endLocal.year}';
    }
  }

  Widget _buildStatusChip(LeaveStatus status) {
    final (label, type) = switch (status) {
      LeaveStatus.pending => ('Pending', StatusBadgeType.pending),
      LeaveStatus.approved => ('Approved', StatusBadgeType.approved),
      LeaveStatus.rejected => ('Rejected', StatusBadgeType.rejected),
    };

    return StatusBadge(label: label, type: type);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLeaveDetail(
    BuildContext context,
    LeaveRequest leave,
    AdminLeaveApprovalsStore store,
  ) {
    // Import and reuse the detail sheet from AdminLeaveScreen
    // For now, we'll create a simple version here
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) => _LeaveDetailSheet(leave: leave, store: store),
    );
  }
}

/// Leave detail bottom sheet (simplified version)
class _LeaveDetailSheet extends StatelessWidget {
  const _LeaveDetailSheet({
    required this.leave,
    required this.store,
  });

  final LeaveRequest leave;
  final AdminLeaveApprovalsStore store;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: AppRadius.smAll,
            ),
          ),
          Padding(
            padding: AppSpacing.lgAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Leave Request Details',
                  style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Details section
                Container(
                  padding: AppSpacing.mdAll,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Employee', leave.userName ?? 'N/A'),
                      if (leave.department != null) ...[
                        const Divider(height: AppSpacing.md),
                        _buildDetailRow('Department', leave.department!),
                      ],
                      const Divider(height: AppSpacing.md),
                      _buildDetailRow('Leave Type', leave.leaveTypeDisplay),
                      const Divider(height: AppSpacing.md),
                      _buildDetailRow(
                        'Date Range',
                        '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                      ),
                      if (leave.isHalfDay) ...[
                        const Divider(height: AppSpacing.md),
                        _buildDetailRow(
                          'Half Day',
                          leave.halfDayPart == HalfDayPart.am ? 'AM' : 'PM',
                        ),
                      ],
                      const Divider(height: AppSpacing.md),
                      _buildDetailRow('Days', leave.daysDisplay),
                      const Divider(height: AppSpacing.md),
                      _buildDetailRowWithStatus(
                        'Status',
                        leave.statusDisplay,
                        leave.status,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Reason section
                Container(
                  padding: AppSpacing.mdAll,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: AppTypography.lightTextTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        leave.reason.isEmpty ? 'No reason provided' : leave.reason,
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: leave.reason.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontStyle:
                              leave.reason.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rejection reason (if rejected)
                if (leave.status == LeaveStatus.rejected && leave.rejectionReason != null && leave.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.mdAll,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: AppRadius.mediumAll,
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Rejection Reason',
                              style: AppTypography.lightTextTheme.labelLarge?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          leave.rejectionReason!,
                          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Admin comment (if rejected or approved)
                if ((leave.status == LeaveStatus.rejected || leave.status == LeaveStatus.approved) &&
                    leave.adminComment != null &&
                    leave.adminComment!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.mdAll,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.mediumAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Comment',
                          style: AppTypography.lightTextTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          leave.adminComment!,
                          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Attachments placeholder
                if (leave.attachments != null && leave.attachments!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.mdAll,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.mediumAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Attachments',
                              style: AppTypography.lightTextTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...leave.attachments!.map((attachment) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      attachment,
                                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ] else if (leave.status == LeaveStatus.pending) ...[
                  // Show placeholder for pending requests
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.mdAll,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppRadius.mediumAll,
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'No attachments',
                          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Actions: Only show for pending
                if (leave.status == LeaveStatus.pending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: store.isLeaveLoading(leave.id)
                              ? null
                              : () async {
                                  try {
                                    await store.approveOne(context, leave);
                                    // Create notification for employee
                                    final notificationsStore =
                                        context.read<NotificationsStore>();
                                    final now = DateTime.now();
                                    notificationsStore.addNotification(
                                      AppNotification(
                                        id: 'leave_approved_${leave.id}_${now.millisecondsSinceEpoch}',
                                        title: 'Leave Request Approved',
                                        body:
                                            'Your leave request for ${leave.daysDisplay} has been approved.',
                                        createdAt: now,
                                        type: NotificationType.success,
                                        isRead: false,
                                      ),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Leave request approved'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to approve: ${e.toString()}'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: AppSpacing.mdAll,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mediumAll,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: store.isLeaveLoading(leave.id)
                              ? null
                              : () => _showRejectDialog(context, leave, store),
                          style: OutlinedButton.styleFrom(
                            padding: AppSpacing.mdAll,
                            side: BorderSide(
                              color: AppColors.error,
                              width: 1.5,
                            ),
                            foregroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mediumAll,
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (leave.status == LeaveStatus.approved) ...[
                  // Approved state: show approved message
                  Container(
                    padding: AppSpacing.mdAll,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppRadius.mediumAll,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'This leave request has been approved.',
                            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithStatus(
    String label,
    String value,
    LeaveStatus status,
  ) {
    Color statusColor;
    switch (status) {
      case LeaveStatus.pending:
        statusColor = AppColors.warning;
        break;
      case LeaveStatus.approved:
        statusColor = AppColors.success;
        break;
      case LeaveStatus.rejected:
        statusColor = AppColors.error;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                value,
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  void _showRejectDialog(
    BuildContext context,
    LeaveRequest leave,
    AdminLeaveApprovalsStore store,
  ) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rejection reason',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              try {
                await store.rejectOne(context, leave, reason: reasonController.text.trim());
                // Create notification for employee
                final notificationsStore = context.read<NotificationsStore>();
                final now = DateTime.now();
                notificationsStore.addNotification(
                  AppNotification(
                    id: 'leave_rejected_${leave.id}_${now.millisecondsSinceEpoch}',
                    title: 'Leave Request Rejected',
                    body:
                        'Your leave request for ${leave.daysDisplay} has been rejected. Reason: ${reasonController.text.trim()}',
                    createdAt: now,
                    type: NotificationType.error,
                    isRead: false,
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context); // Close bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave request rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reject: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

/// Accrual Logs tab content
class _AccrualLogsTabContent extends StatefulWidget {
  const _AccrualLogsTabContent();

  @override
  State<_AccrualLogsTabContent> createState() =>
      _AccrualLogsTabContentState();
}

class _AccrualLogsTabContentState extends State<_AccrualLogsTabContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Only load if we don't have data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<LeaveAccrualStore>();
      if (store.logs.isEmpty && !store.isLoading) {
        store.load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LeaveAccrualStore>();
    final contextStore = context.watch<AdminLeaveContextStore>();
    
    // Filter by selected employee if set
    var filteredLogs = store.logs;
    if (contextStore.selectedEmployeeId != null) {
      filteredLogs = filteredLogs
          .where((log) => log.employeeId == contextStore.selectedEmployeeId)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredLogs = filteredLogs.where((log) {
        return log.employeeName.toLowerCase().contains(query) ||
            log.leaveType.toLowerCase().contains(query);
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: AppSpacing.lgAll,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employee or leave type...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mediumAll,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // Selected Employee Chip (if filter is active)
        const SelectedEmployeeFilterChip(),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: store.isLoading && store.logs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : store.error != null && store.logs.isEmpty
                  ? _buildErrorState(context, store)
                  : filteredLogs.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => store.load(forceRefresh: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: filteredLogs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: _buildAccrualLogCard(filteredLogs[index]),
                              );
                            },
                          ),
                        ),
        ),
      ],
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
              Icons.timeline_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Accrual Logs',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No accrual logs found',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LeaveAccrualStore store) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load accrual logs',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                store.error ?? 'Unknown error',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: store.isLoading
                    ? null
                    : () => store.load(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccrualLogCard(LeaveAccrualLog log) {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials(log.employeeName),
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.employeeName,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildLeaveTypeChip(log.leaveType),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${log.hoursAccrued.toStringAsFixed(1)}h',
                    style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatDate(log.date),
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildLeaveTypeChip(String leaveType) {
    final lower = leaveType.toLowerCase();
    final color = lower.contains('sick')
        ? AppColors.warning
        : lower.contains('unpaid')
            ? AppColors.textSecondary
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        leaveType,
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

/// Cash Out tab content
class _CashOutTabContent extends StatefulWidget {
  const _CashOutTabContent();

  @override
  State<_CashOutTabContent> createState() => _CashOutTabContentState();
}

class _CashOutTabContentState extends State<_CashOutTabContent> {
  @override
  void initState() {
    super.initState();
    // Only load if we don't have data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<LeaveCashOutStore>();
      if (store.items.isEmpty && !store.isLoading) {
        store.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LeaveCashOutStore>();
    final contextStore = context.watch<AdminLeaveContextStore>();
    
    // Filter by selected employee if set
    var filteredItems = store.items;
    if (contextStore.selectedEmployeeId != null) {
      filteredItems = filteredItems
          .where((item) => item.employeeId == contextStore.selectedEmployeeId)
          .toList();
    }

    return Column(
      children: [
        // Selected Employee Chip (if filter is active)
        const SelectedEmployeeFilterChip(),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: store.isLoading && store.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : store.error != null && store.items.isEmpty
                  ? _buildErrorState(context, store)
                  : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => store.load(forceRefresh: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: _buildCashOutCard(filteredItems[index]),
                              );
                            },
                          ),
                        ),
        ),
      ],
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
              Icons.monetization_on_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Cash Out Agreements',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No cash out agreements found',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LeaveCashOutStore store) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load cash out agreements',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                store.error ?? 'Unknown error',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: store.isLoading
                    ? null
                    : () => store.load(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashOutCard(LeaveCashOut item) {
    Color statusColor;
    switch (item.status) {
      case CashOutStatus.pending:
        statusColor = AppColors.warning;
        break;
      case CashOutStatus.approved:
        statusColor = AppColors.success;
        break;
      case CashOutStatus.rejected:
        statusColor = AppColors.error;
        break;
    }

    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.leaveType,
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(item.status, statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatDate(item.date),
                    style: AppTypography.lightTextTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                '\$${item.amount.toStringAsFixed(2)}',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(CashOutStatus status, Color color) {
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
        status == CashOutStatus.pending
            ? 'Pending'
            : status == CashOutStatus.approved
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
