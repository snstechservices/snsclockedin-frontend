import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/employees/application/employees_store.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin leave history screen
class AdminLeaveHistoryScreen extends StatefulWidget {
  const AdminLeaveHistoryScreen({super.key});

  @override
  State<AdminLeaveHistoryScreen> createState() =>
      _AdminLeaveHistoryScreenState();
}

class _AdminLeaveHistoryScreenState extends State<AdminLeaveHistoryScreen> {
  LeaveStatus? _selectedStatusFilter;
  String? _filteredEmployeeId;
  String? _filteredEmployeeName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for employeeId query parameter
    final router = GoRouterState.of(context);
    final employeeId = router.uri.queryParameters['employeeId'];
    final statusParam = router.uri.queryParameters['status'];
    if (employeeId != null &&
        employeeId.isNotEmpty &&
        _filteredEmployeeId != employeeId) {
      _filteredEmployeeId = employeeId;
      // Try to get employee name from store
      final employeesStore = context.read<EmployeesStore>();
      if (employeesStore.allEmployees.isEmpty) {
        employeesStore.seedSampleData();
      }
      final employee = employeesStore.allEmployees.firstWhere(
        (e) => e.id == employeeId,
        orElse: () => const Employee(
          id: '',
          fullName: 'Unknown',
          email: '',
          department: '',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
      );
      _filteredEmployeeName = employee.fullName;
    }

    if (statusParam != null) {
      final nextStatus = switch (statusParam) {
        'pending' => LeaveStatus.pending,
        'approved' => LeaveStatus.approved,
        'rejected' => LeaveStatus.rejected,
        _ => null,
      };
      if (_selectedStatusFilter != nextStatus) {
        setState(() => _selectedStatusFilter = nextStatus);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Load leave data if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AdminLeaveApprovalsStore>();
      if (store.pendingLeaves.isEmpty) {
        store.loadPending();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminLeaveApprovalsStore>();
    // Create a mutable copy of the list
    var allLeaves = List<LeaveRequest>.from(store.pendingLeaves);

    // Filter by employee if specified
    if (_filteredEmployeeId != null) {
      allLeaves = allLeaves
          .where((leave) => leave.userId == _filteredEmployeeId)
          .toList();
    }

    // Filter by status
    var filteredLeaves = _selectedStatusFilter == null
        ? allLeaves
        : allLeaves.where((l) => l.status == _selectedStatusFilter).toList();

    // Ensure we have a mutable list before sorting
    filteredLeaves = List<LeaveRequest>.from(filteredLeaves);
    // Sort by date (newest first)
    filteredLeaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Employee Filter Chip (if present)
                if (_filteredEmployeeId != null) ...[
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.person, size: 16),
                        label: Text(
                          'Filtered: $_filteredEmployeeName',
                          style: AppTypography.lightTextTheme.bodySmall,
                        ),
                        onDeleted: () {
                          setState(() {
                            _filteredEmployeeId = null;
                            _filteredEmployeeName = null;
                          });
                          // Remove query parameter
                          context.go('/a/leave/history');
                        },
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
              ],
            ),
          ),

          // Leave List
          Expanded(
            child: store.isLoading && filteredLeaves.isEmpty
                ? const Center(child: CircularProgressIndicator())
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
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
    );
  }

  Widget _buildFilterChip(String label, LeaveStatus? status) {
    final isSelected = _selectedStatusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = selected ? status : null;
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
              Icons.history_outlined,
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
              _selectedStatusFilter == null
                  ? 'No leave requests found'
                  : 'No ${_selectedStatusFilter == LeaveStatus.pending ? "pending" : _selectedStatusFilter == LeaveStatus.approved ? "approved" : "rejected"} requests',
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

  Widget _buildErrorState(BuildContext context, AdminLeaveApprovalsStore store) {
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

  Widget _buildLeaveCard(BuildContext context, LeaveRequest leave) {
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
      onTap: () => _showLeaveDetail(context, leave),
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
                      leave.userName ?? 'Employee',
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      leave.leaveTypeDisplay,
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
                style: AppTypography.lightTextTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                leave.daysDisplay,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              leave.reason,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLeaveDetail(BuildContext context, LeaveRequest leave) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) => _LeaveDetailSheet(leave: leave),
    );
  }
}

class _LeaveDetailSheet extends StatelessWidget {
  const _LeaveDetailSheet({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: AppRadius.smAll,
              ),
            ),
            Text(
              'Leave Request Details',
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Details
            AppCard(
              padding: AppSpacing.lgAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Employee', leave.userName ?? 'N/A'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status',
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
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
                  if (leave.reason.isNotEmpty) ...[
                    const Divider(height: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason',
                          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          leave.reason,
                          style: AppTypography.lightTextTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Wrapper to use AdminLeaveHistoryScreen as standalone (with AppScreenScaffold)
class AdminLeaveHistoryScreenWrapper extends StatelessWidget {
  const AdminLeaveHistoryScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      skipScaffold: true,
      child: const AdminLeaveHistoryScreen(),
    );
  }
}
