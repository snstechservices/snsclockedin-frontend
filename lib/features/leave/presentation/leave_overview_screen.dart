import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_balance.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/company_calendar/presentation/company_calendar_widget.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Leave overview screen with tabs and leave balance
class LeaveOverviewScreen extends StatefulWidget {
  const LeaveOverviewScreen({super.key});

  @override
  State<LeaveOverviewScreen> createState() => _LeaveOverviewScreenState();
}

class _LeaveOverviewScreenState extends State<LeaveOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LeaveStore>();
    final balance = store.leaveBalance;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match admin pattern)
          _buildQuickStatsSection(context),
          // Tab Navigation
          _buildTabBar(),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Application Tab
                _buildApplicationTab(balance),
                // Calendar Tab
                _buildCalendarTab(),
                // History Tab
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context) {
    return Consumer<LeaveStore>(
      builder: (context, store, _) {
        final requests = store.leaveRequests;
        final pendingCount = requests.where((r) => r.status == LeaveStatus.pending).length;
        final approvedCount = requests.where((r) => r.status == LeaveStatus.approved).length;
        final rejectedCount = requests.where((r) => r.status == LeaveStatus.rejected).length;

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
                  Icon(Icons.event_note, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Leave Summary',
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
                      value: pendingCount.toString(),
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
                      value: approvedCount.toString(),
                      color: AppColors.success,
                      icon: Icons.check_circle,
                      dense: true,
                      borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatCard(
                      title: 'Rejected',
                      value: rejectedCount.toString(),
                      color: AppColors.error,
                      icon: Icons.cancel,
                      dense: true,
                      borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
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
        tabs: const [
          Tab(
            icon: Icon(Icons.edit_outlined),
            text: 'Application',
          ),
          Tab(
            icon: Icon(Icons.calendar_today_outlined),
            text: 'Calendar',
          ),
          Tab(
            icon: Icon(Icons.history_outlined),
            text: 'History',
          ),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: AppTypography.lightTextTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.lightTextTheme.bodySmall,
      ),
    );
  }

  Widget _buildApplicationTab(LeaveBalance balance) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Leave Balance Card
              _buildLeaveBalanceCard(balance),
              const SizedBox(height: AppSpacing.lg),

              // Monthly Accrual Preview Card
              _buildAccrualPreviewCard(),
              const SizedBox(height: AppSpacing.lg),

              // Current Leave Policy Section
              _buildLeavePolicySection(),
              // Add bottom padding for FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Floating Action Button to apply for leave
        Positioned(
          bottom: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () => context.go('/e/leave/apply'),
            icon: const Icon(Icons.add),
            label: const Text('Apply for Leave'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const CompanyCalendarWidget(),
    );
  }

  Widget _buildHistoryTab() {
    return _LeaveHistoryTabContent();
  }

  Widget _buildLeaveBalanceCard(LeaveBalance balance) {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Leave Balance'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Available leave days',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 2-column grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            children: [
              _buildBalanceItem('Annual Leave', balance.annual, 'days'),
              _buildBalanceItem('Sick Leave', balance.sick, 'days'),
              _buildBalanceItem('Casual Leave', balance.casual, 'days'),
              _buildBalanceItem('Maternity Leave', balance.maternity, 'days'),
              _buildBalanceItem('Paternity Leave', balance.paternity, 'days'),
              _buildBalanceItem(
                'Unpaid Leave',
                null,
                balance.unpaidUnlimited ? 'Unlimited' : 'N/A',
                isUnlimited: balance.unpaidUnlimited,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    double? value,
    String subtext, {
    bool isUnlimited = false,
  }) {
    return AppCard(
      padding: AppSpacing.mdAll,
      borderColor: AppColors.textSecondary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            value != null
                                ? value.toStringAsFixed(1)
                                : isUnlimited
                                    ? '∞'
                                    : 'N/A',
                            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtext,
                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccrualPreviewCard() {
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
                    SectionHeader('Monthly Accrual Preview'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Estimated accrual for next month',
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preview refreshed (demo)'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_outlined),
                tooltip: 'Refresh preview',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Text(
              'Accrual preview will be available once backend integration is complete.',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeavePolicySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Current Leave Policy'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Company leave policy summary',
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Policy Summary',
                style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '• Annual Leave: 20 days per year\n'
                '• Sick Leave: 10 days per year\n'
                '• Casual Leave: 5 days per year\n'
                '• Maternity Leave: As per company policy\n'
                '• Paternity Leave: As per company policy\n'
                '• Unpaid Leave: Available upon approval',
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// History tab content widget (reused from LeaveHistoryScreen)
class _LeaveHistoryTabContent extends StatefulWidget {
  const _LeaveHistoryTabContent();

  @override
  State<_LeaveHistoryTabContent> createState() => _LeaveHistoryTabContentState();
}

class _LeaveHistoryTabContentState extends State<_LeaveHistoryTabContent> {
  LeaveStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    // Only load if we don't have data (avoids API calls when we have seeded/cached data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<LeaveStore>();
      final appState = context.read<AppState>();
      final userId = appState.userId ?? 'current_user';
      // Only load if we don't have data
      if (store.leaveRequests.isEmpty) {
        store.loadLeaves(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final store = context.watch<LeaveStore>();
    final allUserLeaves = store.getLeaveRequestsByUserId(
      appState.userId ?? 'current_user',
    );

    // Filter leaves by selected status
    var filteredLeaves = _selectedFilter == null
        ? allUserLeaves
        : allUserLeaves.where((leave) => leave.status == _selectedFilter).toList();

    // Ensure mutable list before sorting
    filteredLeaves = List<LeaveRequest>.from(filteredLeaves);
    // Sort by date (newest first)
    filteredLeaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _buildFilterChip('All', null),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Pending', LeaveStatus.pending),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Approved', LeaveStatus.approved),
              const SizedBox(width: AppSpacing.sm),
              _buildFilterChip('Rejected', LeaveStatus.rejected),
            ],
          ),
        ),

        // Leave List
        Expanded(
          child: store.isLoading && filteredLeaves.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : store.error != null && filteredLeaves.isEmpty
                  ? _buildErrorState(context, store, appState)
                  : filteredLeaves.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            final userId = appState.userId ?? 'current_user';
                            await store.loadLeaves(userId, forceRefresh: true);
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: filteredLeaves.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: _buildLeaveCard(filteredLeaves[index]),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, LeaveStatus? status) {
    final isSelected = _selectedFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? status : null;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
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
            Text(
              _selectedFilter == null
                  ? 'No leave requests found'
                  : 'No ${_selectedFilter == LeaveStatus.pending ? "pending" : _selectedFilter == LeaveStatus.approved ? "approved" : "rejected"} requests',
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

  Widget _buildErrorState(
    BuildContext context,
    LeaveStore store,
    AppState appState,
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
                    : () {
                        final userId = appState.userId ?? 'current_user';
                        store.loadLeaves(userId, forceRefresh: true);
                      },
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

  Widget _buildLeaveCard(LeaveRequest leave) {
    Color statusColor;
    switch (leave.status) {
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
                      leave.leaveTypeDisplay,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  leave.statusDisplay,
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (leave.isHalfDay) ...[
            const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
