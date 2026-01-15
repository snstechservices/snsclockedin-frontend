import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_context_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_balance.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin leave balances screen
class AdminLeaveBalancesScreen extends StatefulWidget {
  const AdminLeaveBalancesScreen({super.key});

  @override
  State<AdminLeaveBalancesScreen> createState() =>
      _AdminLeaveBalancesScreenState();
}

class _AdminLeaveBalancesScreenState extends State<AdminLeaveBalancesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load data on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<AdminLeaveBalancesStore>();
      if (store.employees.isEmpty && !store.isLoading) {
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
    final store = context.watch<AdminLeaveBalancesStore>();
    final filteredEmployees = store.filteredEmployees;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: AppSpacing.lgAll,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        store.setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mediumAll,
              ),
            ),
            onChanged: (value) => store.setSearchQuery(value),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Employee Balances List
        Expanded(
          child: _buildContent(store, filteredEmployees),
        ),
      ],
    );
  }

  Widget _buildContent(
    AdminLeaveBalancesStore store,
    List<EmployeeLeaveBalance> filteredEmployees,
  ) {
    // Loading state (when list empty)
    if (store.isLoading && store.employees.isEmpty) {
      return _buildLoadingState();
    }

    // Error state (when list empty)
    if (store.error != null && store.employees.isEmpty) {
      return _buildErrorState(store);
    }

    // Empty state (no matches after filtering/search)
    if (filteredEmployees.isEmpty) {
      return _buildEmptyState(store);
    }

    // List of employees
    return RefreshIndicator(
      onRefresh: () => store.refresh(),
      child: ListView.builder(
        padding: AppSpacing.lgAll,
        itemCount: filteredEmployees.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildEmployeeBalanceCard(filteredEmployees[index]),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: AppSpacing.lgAll,
      itemCount: 6, // Show 6 skeleton cards
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildSkeletonCard(),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.largeAll,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Skeleton balance chips
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mediumAll,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mediumAll,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mediumAll,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AdminLeaveBalancesStore store) {
    return Center(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: AppCard(
          padding: AppSpacing.lgAll,
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
                'Failed to load leave balances',
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

  Widget _buildEmptyState(AdminLeaveBalancesStore store) {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Employees Found',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try adjusting your search or filters',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (store.searchQuery.isNotEmpty || store.statusFilter != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () {
                  store.clearFilters();
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  padding: AppSpacing.mdAll,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    EmployeeStatus? status,
    AdminLeaveBalancesStore store,
  ) {
    final isSelected = store.statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        store.setStatusFilter(selected ? status : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildEmployeeBalanceCard(EmployeeLeaveBalance employeeBalance) {
    final employee = employeeBalance.employee;
    final balance = employeeBalance.balance;
    final initials = _getInitials(employee.fullName);

    return AppCard(
      padding: AppSpacing.lgAll,
      onTap: () => _showEmployeeBalanceDetail(employeeBalance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Header
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.largeAll,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name and Department
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      employee.department,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Balance Tiles (using Wrap to prevent overflow)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildBalanceTile(
                label: 'Annual',
                value: balance.annual,
                color: AppColors.primary,
                icon: Icons.event_available_outlined,
              ),
              _buildBalanceTile(
                label: 'Sick',
                value: balance.sick,
                color: AppColors.warning,
                icon: Icons.healing_outlined,
              ),
              _buildBalanceTile(
                label: 'Casual',
                value: balance.casual,
                color: AppColors.secondary,
                icon: Icons.beach_access_outlined,
              ),
              _buildBalanceTile(
                label: 'Unpaid',
                value: balance.unpaidUnlimited ? double.infinity : 0.0,
                isUnlimited: balance.unpaidUnlimited,
                color: AppColors.textSecondary,
                icon: Icons.money_off_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTile({
    required String label,
    required double value,
    bool isUnlimited = false,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                isUnlimited ? 'Unlimited' : value.toStringAsFixed(1),
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  void _showEmployeeBalanceDetail(EmployeeLeaveBalance employeeBalance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (context) => _EmployeeBalanceDetailSheet(
        employeeBalance: employeeBalance,
      ),
    );
  }
}

class _EmployeeBalanceDetailSheet extends StatelessWidget {
  const _EmployeeBalanceDetailSheet({
    required this.employeeBalance,
  });

  final EmployeeLeaveBalance employeeBalance;

  @override
  Widget build(BuildContext context) {
    final employee = employeeBalance.employee;
    final balance = employeeBalance.balance;
    final initials = _getInitials(employee.fullName);

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
                // Header with avatar, name, department, status
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.largeAll,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: AppTypography.lightTextTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
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
                            style: AppTypography.lightTextTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            employee.department,
                            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status chip
                    _buildStatusChip(employee.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Balance breakdown
                AppCard(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Balances',
                        style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Balance chips (using Wrap)
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _buildBalanceChip('Annual', balance.annual),
                          _buildBalanceChip('Sick', balance.sick),
                          _buildBalanceChip('Casual', balance.casual),
                          _buildBalanceChip(
                            'Unpaid',
                            balance.unpaidUnlimited ? double.infinity : 0.0,
                            isUnlimited: balance.unpaidUnlimited,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Actions section
                Text(
                  'Actions',
                  style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // View Leave Requests button
                OutlinedButton.icon(
                  onPressed: () {
                    // Set selected employee filter
                    final contextStore = context.read<AdminLeaveContextStore>();
                    contextStore.setSelectedEmployee(
                      id: employee.id,
                      name: employee.fullName,
                      department: employee.department,
                    );
                    Navigator.pop(context);
                    // Navigate to Requests tab
                    context.go('/a/leave/requests');
                  },
                  icon: const Icon(Icons.approval_outlined),
                  label: const Text('View Leave Requests'),
                  style: OutlinedButton.styleFrom(
                    padding: AppSpacing.mdAll,
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // View Accrual Logs button
                OutlinedButton.icon(
                  onPressed: () {
                    // Set selected employee filter
                    final contextStore = context.read<AdminLeaveContextStore>();
                    contextStore.setSelectedEmployee(
                      id: employee.id,
                      name: employee.fullName,
                      department: employee.department,
                    );
                    Navigator.pop(context);
                    // Navigate to Accruals tab
                    context.go('/a/leave/accruals');
                  },
                  icon: const Icon(Icons.timeline_outlined),
                  label: const Text('View Accrual Logs'),
                  style: OutlinedButton.styleFrom(
                    padding: AppSpacing.mdAll,
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Cash Out button
                OutlinedButton.icon(
                  onPressed: () {
                    // Set selected employee filter
                    final contextStore = context.read<AdminLeaveContextStore>();
                    contextStore.setSelectedEmployee(
                      id: employee.id,
                      name: employee.fullName,
                      department: employee.department,
                    );
                    Navigator.pop(context);
                    // Navigate to Cash Out tab
                    context.go('/a/leave/cashout');
                  },
                  icon: const Icon(Icons.monetization_on_outlined),
                  label: const Text('Cash Out'),
                  style: OutlinedButton.styleFrom(
                    padding: AppSpacing.mdAll,
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(EmployeeStatus status) {
    final isActive = status == EmployeeStatus.active;
    final color = isActive ? AppColors.success : AppColors.textSecondary;

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
        isActive ? 'Active' : 'Inactive',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBalanceChip(String label, double value, {bool isUnlimited = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            isUnlimited ? 'Unlimited' : value.toStringAsFixed(1),
            style: AppTypography.lightTextTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

/*
Manual Test Checklist:
=====================

Loading State:
- [ ] Open Balances tab → see 6 skeleton cards while loading
- [ ] Skeleton cards show grey placeholder blocks

Error State:
- [ ] If error occurs (simulate by breaking store), see error card with message
- [ ] "Retry" button works and reloads data

Empty State:
- [ ] Search for non-existent employee → see "No Employees Found"
- [ ] Apply filter that matches nothing → see empty state
- [ ] "Clear Filters" button appears when filters/search active
- [ ] "Clear Filters" button clears search and status filter

Filtering & Search:
- [ ] Search by name → filters list correctly
- [ ] Search by email → filters list correctly
- [ ] Search by department → filters list correctly
- [ ] Select "Active" filter → only active employees shown
- [ ] Select "Inactive" filter → only inactive employees shown
- [ ] Select "All" filter → all employees shown
- [ ] Filter persists when switching tabs and returning

Balance Cards:
- [ ] Cards show employee name, department, avatar with initials
- [ ] Balance chips (Annual, Sick, Casual, Unpaid) display correctly
- [ ] Unpaid shows "Unlimited" when flagged
- [ ] Chips use Wrap and never overflow on small screens
- [ ] Entire card is tappable → opens detail bottom sheet

Detail Bottom Sheet:
- [ ] Shows employee avatar, name, department, status chip
- [ ] Status chip shows "Active" (green) or "Inactive" (grey)
- [ ] Balance breakdown shows all leave types as chips
- [ ] "View Leave Requests" button shows SnackBar (Phase 1 placeholder)
- [ ] "View Accrual Logs" button navigates to Leave Management (placeholder)
- [ ] "Cash Out" button navigates to Leave Management (placeholder)
- [ ] Sheet is scrollable and handles keyboard

Seed Demo:
- [ ] Use Debug Harness to seed demo data
- [ ] Verify at least 8 employees appear
- [ ] Verify mix of active/inactive employees
- [ ] Verify various balance values (some unlimited unpaid, some not)

Clear Demo:
- [ ] Use Debug Harness to clear demo data
- [ ] Verify list becomes empty
- [ ] Verify filters/search are cleared
*/
