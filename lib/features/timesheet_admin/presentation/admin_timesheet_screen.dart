import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/timesheet_admin/application/admin_timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet_admin/data/admin_timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/collapsible_filter_section.dart';

/// Admin timesheet screen for managing pending and approved timesheets
class AdminTimesheetScreen extends StatefulWidget {
  const AdminTimesheetScreen({super.key});

  @override
  State<AdminTimesheetScreen> createState() => _AdminTimesheetScreenState();
}

class _AdminTimesheetScreenState extends State<AdminTimesheetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AdminTimesheetStore _store;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _store.setSelectedTab(_tabController.index);
      }
    });
    _store = AdminTimesheetStore(
      repository: AdminTimesheetRepository(),
    );

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        // Seed data first, before setting filters
        _store.seedDebugData();
      }
      // Initialize date range to today (after seeding so seed data is visible)
      final now = DateTime.now();
      _store.setDateRange(DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day),
      ));
      // Load from API (will preserve seed data in debug mode)
      _store.loadPending();
      _store.loadApproved();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _store,
      child: AppScreenScaffold(
        skipScaffold: true,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All Records'),
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
            ),
            // Quick Stats at top (always visible, match legacy)
            _buildQuickStatsSection(context),
            _buildFiltersSection(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllRecordsTab(context),
                  _buildPendingTab(context),
                  _buildApprovedTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context) {
    return Consumer<AdminTimesheetStore>(
      builder: (context, store, _) {
        final allRecords = store.filteredAllRecords;
        final totalRecords = allRecords.length;
        final presentCount = allRecords.where((r) => r.isCompleted).length;
        final onBreakCount = allRecords.where((r) => r.breaks.any((b) => b.endTime == null)).length;
        final completedCount = allRecords.where((r) => r.isCompleted).length;
        final pendingCount = store.filteredPendingRecords.length;
        final rejectedCount = allRecords.where((r) => r.approvalStatus == ApprovalStatus.rejected).length;

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
                  Icon(Icons.assessment, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Attendance Summary',
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
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Total Records',
                        totalRecords.toString(),
                        AppColors.textPrimary,
                        Icons.assessment,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Present',
                        presentCount.toString(),
                        AppColors.success,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'On Break',
                        onBreakCount.toString(),
                        AppColors.warning,
                        Icons.pause_circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Completed',
                        completedCount.toString(),
                        AppColors.secondary,
                        Icons.done_all,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Pending',
                        pendingCount.toString(),
                        AppColors.warning,
                        Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Rejected',
                        rejectedCount.toString(),
                        AppColors.error,
                        Icons.cancel,
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

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            count,
            style: AppTypography.lightTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    return Consumer2<AdminTimesheetStore, EmployeesStore>(
      builder: (context, store, employeesStore, _) {
        return CollapsibleFilterSection(
          title: 'Filters',
          initiallyExpanded: true,
          onClear: () {
            final now = DateTime.now();
            store.setDateRange(DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day),
            ));
            store.setEmployeeFilter(null);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date range quick buttons
              Row(
                children: [
                  Expanded(
                    child: _buildQuickDateButton(
                      'Today',
                      () {
                        final now = DateTime.now();
                        store.setDateRange(DateTimeRange(
                          start: DateTime(now.year, now.month, now.day),
                          end: DateTime(now.year, now.month, now.day),
                        ));
                      },
                      store.dateRange != null &&
                          store.dateRange!.start.year == DateTime.now().year &&
                          store.dateRange!.start.month == DateTime.now().month &&
                          store.dateRange!.start.day == DateTime.now().day &&
                          store.dateRange!.end.year == DateTime.now().year &&
                          store.dateRange!.end.month == DateTime.now().month &&
                          store.dateRange!.end.day == DateTime.now().day,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickDateButton(
                      'Yesterday',
                      () {
                        final yesterday = DateTime.now().subtract(const Duration(days: 1));
                        store.setDateRange(DateTimeRange(
                          start: DateTime(yesterday.year, yesterday.month, yesterday.day),
                          end: DateTime(yesterday.year, yesterday.month, yesterday.day),
                        ));
                      },
                      store.dateRange != null &&
                          store.dateRange!.start.year == DateTime.now().subtract(const Duration(days: 1)).year &&
                          store.dateRange!.start.month == DateTime.now().subtract(const Duration(days: 1)).month &&
                          store.dateRange!.start.day == DateTime.now().subtract(const Duration(days: 1)).day,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickDateButton(
                      'This Week',
                      () {
                        final now = DateTime.now();
                        final start = now.subtract(Duration(days: now.weekday - 1));
                        final end = start.add(const Duration(days: 6));
                        store.setDateRange(DateTimeRange(
                          start: DateTime(start.year, start.month, start.day),
                          end: DateTime(end.year, end.month, end.day),
                        ));
                      },
                      false, // TODO: Check if current range is this week
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickDateButton(
                      'Custom',
                      () => _showCustomDateRangePicker(context, store),
                      store.dateRange != null &&
                          !_isQuickRange(store.dateRange!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Employee filter
              DropdownButtonFormField<String>(
                value: store.selectedEmployeeId,
                decoration: InputDecoration(
                  labelText: 'Employee',
                  border: OutlineInputBorder(borderRadius: AppRadius.mediumAll),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Employees'),
                  ),
                  ...employeesStore.allEmployees.map(
                    (emp) => DropdownMenuItem(
                      value: emp.id,
                      child: Text(emp.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => store.setEmployeeFilter(value),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isQuickRange(DateTimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    final rangeStart = DateTime(range.start.year, range.start.month, range.start.day);
    final rangeEnd = DateTime(range.end.year, range.end.month, range.end.day);
    
    return (rangeStart == today && rangeEnd == today) ||
           (rangeStart == yesterday && rangeEnd == yesterday) ||
           (rangeStart == DateTime(weekStart.year, weekStart.month, weekStart.day) &&
            rangeEnd == DateTime(weekEnd.year, weekEnd.month, weekEnd.day));
  }

  Widget _buildQuickDateButton(String label, VoidCallback onTap, bool isSelected) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: AppRadius.mediumAll,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomDateRangePicker(
    BuildContext context,
    AdminTimesheetStore store,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Normalize initial range to remove time components
    DateTimeRange? initialRange;
    if (store.dateRange != null) {
      final range = store.dateRange!;
      initialRange = DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(range.end.year, range.end.month, range.end.day),
      );
    } else {
      final weekAgo = today.subtract(const Duration(days: 7));
      initialRange = DateTimeRange(
        start: weekAgo,
        end: today,
      );
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: today, // Use today (midnight) instead of now (with time)
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Normalize picked range to remove time components
      final normalizedRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      store.setDateRange(normalizedRange);
    }
  }

  Widget _buildSummaryCard(BuildContext context, {required int tabIndex}) {
    return Consumer<AdminTimesheetStore>(
      builder: (context, store, _) {
        // Context-aware summary based on tab
        if (tabIndex == 0) {
          // All Records tab - show attendance-focused stats (like legacy)
          final filtered = store.filteredAllRecords;
          final totalRecords = filtered.length;
          final presentCount = filtered.where((r) => r.isCompleted).length;
          final onBreakCount = filtered.where((r) => r.breaks.any((b) => b.endTime == null)).length;

          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance Summary',
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildAllRecordsSummaryGrid(
                  totalRecords: totalRecords,
                  presentCount: presentCount,
                  onBreakCount: onBreakCount,
                ),
              ],
            ),
          );
        } else {
          // Pending/Approved tabs - show approval-focused stats
          final totalRecords = tabIndex == 1 
              ? store.filteredPendingRecords.length 
              : store.filteredApprovedRecords.length;
          final pending = store.filteredPendingRecords.length;
          final approved = store.filteredApprovedRecords.length;
          final completed = store.filteredAllRecords.where((r) => r.isCompleted).length;
          final clockedIn = store.filteredAllRecords.where((r) => r.isClockedIn).length;
          final rejected = 0;

          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance Summary',
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSummaryGrid(
                  totalRecords: totalRecords,
                  approved: approved,
                  completed: completed,
                  clockedIn: clockedIn,
                  pending: pending,
                  rejected: rejected,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStatusLegend(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildAllRecordsSummaryGrid({
    required int totalRecords,
    required int presentCount,
    required int onBreakCount,
  }) {
    final items = [
      ('Total Records', totalRecords.toString(), AppColors.textPrimary, Icons.list_alt),
      ('Present', presentCount.toString(), AppColors.success, Icons.check_circle),
      ('On Break', onBreakCount.toString(), AppColors.warning, Icons.pause_circle),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[
            Expanded(
              child: _buildSummaryMetricCard(item.$1, item.$2, color: item.$3, icon: item.$4),
            ),
            if (item != items.last) const SizedBox(width: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required int totalRecords,
    required int approved,
    required int completed,
    required int clockedIn,
    required int pending,
    required int rejected,
    bool showAllMetrics = true,
  }) {
    final items = <(String, String, Color, IconData)>[
      ('Total Records', totalRecords.toString(), AppColors.textPrimary, Icons.list_alt),
    ];
    
    // Add context-specific metrics
    if (showAllMetrics || approved > 0) {
      items.add(('Approved', approved.toString(), AppColors.success, Icons.check_circle));
    }
    if (showAllMetrics || completed > 0) {
      items.add(('Completed', completed.toString(), AppColors.secondary, Icons.done_all));
    }
    if (showAllMetrics || clockedIn > 0) {
      items.add(('Clocked In', clockedIn.toString(), AppColors.secondary, Icons.access_time));
    }
    if (showAllMetrics || pending > 0) {
      items.add(('Pending', pending.toString(), AppColors.warning, Icons.schedule));
    }
    if (showAllMetrics || rejected > 0) {
      items.add(('Rejected', rejected.toString(), AppColors.error, Icons.cancel));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        final (label, value, color, icon) = items[index];
        return _buildSummaryMetricCard(label, value, color: color, icon: icon);
      },
    );
  }

  Widget _buildSummaryMetricCard(String label, String value, {required Color color, required IconData icon}) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.lightTextTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.start,
      children: [
        _buildLegendItem('Approved', AppColors.success),
        _buildLegendItem('Completed', AppColors.secondary),
        _buildLegendItem('Clocked In', AppColors.warning),
        _buildLegendItem('Pending', AppColors.warning),
        _buildLegendItem('Rejected', AppColors.error),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: -0.1,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildAllRecordsTab(BuildContext context) {
    return Consumer2<AdminTimesheetStore, EmployeesStore>(
      builder: (context, store, employeesStore, _) {
        final filtered = store.filteredAllRecords;

        if (store.isLoading && filtered.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.error != null && filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load timesheets',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => store.refreshAll(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No timesheet records found',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        // Responsive layout: DataTable for desktop, Cards for mobile
        final isWide = MediaQuery.of(context).size.width > 700;
        
        return RefreshIndicator(
          onRefresh: () => store.refreshAll(),
          child: isWide
              ? _buildDataTableView(context, filtered, employeesStore)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      ...filtered.map((record) => Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                            ),
                            child: _buildRecordCard(
                              context,
                              record,
                              isPending: record.approvalStatus == ApprovalStatus.pending,
                              employeesStore: employeesStore,
                            ),
                          )),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPendingTab(BuildContext context) {
    return Consumer2<AdminTimesheetStore, EmployeesStore>(
      builder: (context, store, employeesStore, _) {
        final filtered = store.filteredPendingRecords;

        if (store.isLoadingPending && filtered.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.errorPending != null && filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load pending timesheets',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => store.loadPending(forceRefresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No pending timesheets',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        // Responsive layout: DataTable for desktop, Cards for mobile
        final isWide = MediaQuery.of(context).size.width > 700;
        
        return RefreshIndicator(
          onRefresh: () => store.loadPending(forceRefresh: true),
          child: isWide
              ? _buildDataTableView(context, filtered, employeesStore)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      ...filtered.map((record) => Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                            ),
                            child: _buildRecordCard(
                              context,
                              record,
                              isPending: true,
                              employeesStore: employeesStore,
                            ),
                          )),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildApprovedTab(BuildContext context) {
    return Consumer2<AdminTimesheetStore, EmployeesStore>(
      builder: (context, store, employeesStore, _) {
        final filtered = store.filteredApprovedRecords;

        if (store.isLoadingApproved && filtered.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (store.errorApproved != null && filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load approved timesheets',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => store.loadApproved(forceRefresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No approved timesheets',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        // Responsive layout: DataTable for desktop, Cards for mobile
        final isWide = MediaQuery.of(context).size.width > 700;
        
        return RefreshIndicator(
          onRefresh: () => store.loadApproved(forceRefresh: true),
          child: isWide
              ? _buildDataTableView(context, filtered, employeesStore)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      ...filtered.map((record) => Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                            ),
                            child: _buildRecordCard(
                              context,
                              record,
                              isPending: false,
                              employeesStore: employeesStore,
                            ),
                          )),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDataTableView(
    BuildContext context,
    List<AttendanceRecord> records,
    EmployeesStore? employeesStore,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.surface,
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Employee',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Check In',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Check Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Total Hours',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: records.map((record) {
          // Get employee name
          String employeeName = 'Employee ${record.userId.length > 8 ? record.userId.substring(0, 8) : record.userId}...';
          if (employeesStore != null) {
            final employee = employeesStore.allEmployees.firstWhere(
              (emp) => emp.id == record.userId,
              orElse: () => Employee(
                id: '',
                fullName: '',
                email: '',
                department: '',
                status: EmployeeStatus.active,
                role: Role.employee,
              ),
            );
            if (employee.id.isNotEmpty) {
              employeeName = employee.fullName;
            }
          }

          // Format times
          String formatTime(DateTime? dt) {
            if (dt == null) return '—';
            final local = dt.toLocal();
            return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
          }

          final checkInStr = formatTime(record.checkInTime);
          final checkOutStr = formatTime(record.checkOutTime);

          // Format duration
          final duration = record.workDuration;
          final hours = duration.inHours;
          final minutes = duration.inMinutes.remainder(60);
          final durationStr = '${hours}h ${minutes}m';

          // Format date
          final date = record.date.toLocal();
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          // Get attendance status
          final attendanceStatus = _getAttendanceStatus(record);
          final statusColor = _getAttendanceStatusColor(attendanceStatus);

          return DataRow(
            cells: [
              DataCell(
                Text(
                  employeeName,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              DataCell(
                Text(
                  checkInStr,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              DataCell(
                Text(
                  checkOutStr,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              DataCell(
                Text(
                  durationStr,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              DataCell(
                _buildAttendanceStatusChip(attendanceStatus, statusColor),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () {
                    // TODO: Implement edit dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit functionality coming soon')),
                    );
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _getAttendanceStatus(AttendanceRecord record) {
    if (record.isCompleted) {
      return 'present';
    } else if (record.isClockedIn) {
      if (record.breaks.any((b) => b.endTime == null)) {
        return 'on break';
      }
      return 'clocked in';
    } else {
      return 'no records';
    }
  }

  Color _getAttendanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.success;
      case 'on break':
        return AppColors.warning;
      case 'clocked in':
        return AppColors.secondary;
      case 'absent':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildAttendanceStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    AttendanceRecord record, {
    required bool isPending,
    EmployeesStore? employeesStore,
  }) {
    final checkInTime = record.checkInTime;
    final checkOutTime = record.checkOutTime;
    final duration = record.workDuration;

    // Format times
    String formatTime(DateTime? dt) {
      if (dt == null) return '—';
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final checkInStr = formatTime(checkInTime);
    final checkOutStr = formatTime(checkOutTime);

    // Format duration
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = '${hours}h ${minutes}m';

    // Format date (match legacy: yyyy-MM-dd)
    final date = record.date.toLocal();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Get employee name from EmployeesStore
    String employeeName = 'Employee ${record.userId.length > 8 ? record.userId.substring(0, 8) : record.userId}...';
    if (employeesStore != null) {
      final employee = employeesStore.allEmployees.firstWhere(
        (emp) => emp.id == record.userId,
        orElse: () => Employee(
          id: '',
          fullName: '',
          email: '',
          department: '',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
      );
      if (employee.id.isNotEmpty) {
        employeeName = employee.fullName;
      }
    }

    // Get status color and icon
    final (color, icon) = _getStatusColorAndIcon(record.approvalStatus);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: isPending
          ? () => _showDetailBottomSheet(context, record, isPending: true)
          : () => _showDetailBottomSheet(context, record, isPending: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              // Time range, status badge, and duration in a single row
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$checkInStr - $checkOutStr',
                        style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatusBadge(record.approvalStatus),
                    const SizedBox(width: AppSpacing.xs),
                    _buildAttendanceStatusChip(
                      _getAttendanceStatus(record),
                      _getAttendanceStatusColor(_getAttendanceStatus(record)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      durationStr,
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                employeeName,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                dateStr,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (record.totalBreakTimeMinutes > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Breaks: ${record.totalBreakTimeMinutes}m',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ApprovalStatus status) {
    final (color, label) = switch (status) {
      ApprovalStatus.approved => (AppColors.success, 'Approved'),
      ApprovalStatus.pending => (AppColors.warning, 'Pending'),
      ApprovalStatus.rejected => (AppColors.error, 'Rejected'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  (Color, IconData) _getStatusColorAndIcon(ApprovalStatus status) {
    return switch (status) {
      ApprovalStatus.approved => (AppColors.success, Icons.check_circle),
      ApprovalStatus.pending => (AppColors.warning, Icons.schedule),
      ApprovalStatus.rejected => (AppColors.error, Icons.cancel),
    };
  }

  void _showDetailBottomSheet(
    BuildContext context,
    AttendanceRecord record, {
    required bool isPending,
  }) {
    final store = context.read<AdminTimesheetStore>();
    final checkInTime = record.checkInTime;
    final checkOutTime = record.checkOutTime;
    final duration = record.workDuration;

    // Format times
    String formatTime(DateTime? dt) {
      if (dt == null) return '—';
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final checkInStr = formatTime(checkInTime);
    final checkOutStr = formatTime(checkOutTime);

    // Format duration
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = '${hours}h ${minutes}m';

    // Format date (match legacy: yyyy-MM-dd)
    final date = record.date.toLocal();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Timesheet Details',
                style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildDetailRow('Date', dateStr),
              _buildDetailRow('Check In', checkInStr),
              _buildDetailRow('Check Out', checkOutStr),
              _buildDetailRow('Duration', durationStr),
              if (record.adminComment != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildDetailRow('Comment', record.adminComment!),
              ],
              if (isPending) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRejectDialog(context, record, store),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveRecord(context, record, store),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRecord(
    BuildContext context,
    AttendanceRecord record,
    AdminTimesheetStore store,
  ) async {
    Navigator.pop(context); // Close bottom sheet

    try {
      await store.approve(record.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timesheet approved successfully'),
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
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    AttendanceRecord record,
    AdminTimesheetStore store,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Timesheet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
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

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      Navigator.pop(context); // Close bottom sheet

      try {
        await store.reject(record.id, reason: reasonController.text.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timesheet rejected'),
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
    }
  }
}

