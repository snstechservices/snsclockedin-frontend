import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/clickable_stat_card.dart';
import 'package:sns_clocked_in/core/ui/primary_action_button.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/notifications/domain/app_notification.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin leave management screen
class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen> {
  LeaveStatus? _selectedFilter;

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
    final filteredLeaves = _selectedFilter == null
        ? store.pendingLeaves
        : store.pendingLeaves.where((l) => l.status == _selectedFilter).toList();

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          if (store.usingStale) _buildCacheHint(context),
          const SizedBox(height: AppSpacing.md),
          // Summary Stat Cards Section (horizontal scrollable)
          Container(
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
                      'Leave Summary',
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
                        child: ClickableStatCard(
                          title: 'Pending',
                          value: store.pendingCount.toString(),
                          icon: Icons.pending,
                          color: AppColors.warning,
                          isSelected: _selectedFilter == LeaveStatus.pending,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _selectedFilter == LeaveStatus.pending
                                  ? null
                                  : LeaveStatus.pending;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 140,
                        child: ClickableStatCard(
                          title: 'Approved',
                          value: store.approvedCount.toString(),
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          isSelected: _selectedFilter == LeaveStatus.approved,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _selectedFilter == LeaveStatus.approved
                                  ? null
                                  : LeaveStatus.approved;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 140,
                        child: ClickableStatCard(
                          title: 'Rejected',
                          value: store.rejectedCount.toString(),
                          icon: Icons.cancel,
                          color: AppColors.error,
                          isSelected: _selectedFilter == LeaveStatus.rejected,
                          onTap: () {
                            setState(() {
                              _selectedFilter = _selectedFilter == LeaveStatus.rejected
                                  ? null
                                  : LeaveStatus.rejected;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Primary Action Button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PrimaryActionButton(
              label: 'Submit Admin Leave Request',
              icon: Icons.add_circle_outline,
              onPressed: () {
                // Navigate to admin leave request screen or apply leave screen
                context.go('/a/leave/apply');
              },
            ),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),

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
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _buildLeaveCard(context, filteredLeaves[index], store),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
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

  Widget _buildLeaveCard(
    BuildContext context,
    LeaveRequest leave,
    AdminLeaveApprovalsStore store,
  ) {
    final isLeaveLoading = store.isLeaveLoading(leave.id);
    final isDisabled = store.isLoading || isLeaveLoading;

    // Determine border color based on status
    Color borderColor;
    switch (leave.status) {
      case LeaveStatus.pending:
        borderColor = AppColors.warning;
        break;
      case LeaveStatus.approved:
        borderColor = AppColors.success;
        break;
      case LeaveStatus.rejected:
        borderColor = AppColors.error;
        break;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.lgAll,
      onTap: () => _showLeaveDetail(context, leave, store),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 4,
            ),
          ),
        ),
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
                        style: AppTypography.lightTextTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Employee',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(leave.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Date range with calendar icon
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
            // Duration with clock icon
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  leave.daysDisplay,
                  style: AppTypography.lightTextTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Leave type
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  leave.leaveTypeDisplay,
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            // Reason (if available)
            if (leave.reason.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reason: ${leave.reason}',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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

  void _showLeaveDetail(
    BuildContext context,
    LeaveRequest leave,
    AdminLeaveApprovalsStore store,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (context) => _LeaveDetailSheet(leave: leave, store: store),
    );
  }
}

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
                // Details section with subtle background
                Container(
                  padding: AppSpacing.mdAll,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Column(
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
                        _buildDetailRow('Half Day', leave.halfDayPart == HalfDayPart.am ? 'AM' : 'PM'),
                      ],
                      const Divider(height: AppSpacing.md),
                      _buildDetailRow('Days', leave.daysDisplay),
                      const Divider(height: AppSpacing.md),
                      _buildDetailRowWithStatus('Status', leave.statusDisplay, leave.status),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Reason section with subtle background
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
                          fontStyle: leave.reason.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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

  Widget _buildDetailRowWithStatus(String label, String value, LeaveStatus status) {
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
    return '${date.day}/${date.month}/${date.year}';
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

