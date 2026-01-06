import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
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
    // Seed sample data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveStore>().seedSampleData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaveStore = context.watch<LeaveStore>();
    final filteredLeaves = leaveStore.getLeaveRequestsByStatus(_selectedFilter);

    return AppScreenScaffold(
      title: 'Leave Management',
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          // Filter Chips
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
          const SizedBox(height: AppSpacing.md),

          // Leave List
          Expanded(
            child: filteredLeaves.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filteredLeaves.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildLeaveCard(filteredLeaves[index]),
                      );
                    },
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

  Widget _buildLeaveCard(LeaveRequest leave) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.lgAll,
      onTap: () => _showLeaveDetail(leave),
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
                          leave.leaveTypeDisplay,
                          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
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
              Text(
                leave.daysDisplay,
                style: AppTypography.lightTextTheme.bodySmall,
              ),
            ],
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

  void _showLeaveDetail(LeaveRequest leave) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    final leaveStore = context.read<LeaveStore>();

    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Leave Request Details',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildDetailRow('Employee', leave.userName ?? 'N/A'),
            _buildDetailRow('Leave Type', leave.leaveTypeDisplay),
            _buildDetailRow(
              'Date Range',
              '${_formatDate(leave.startDate)} - ${_formatDate(leave.endDate)}',
            ),
            if (leave.isHalfDay)
              _buildDetailRow('Half Day', leave.halfDayPart == HalfDayPart.am ? 'AM' : 'PM'),
            _buildDetailRow('Days', leave.daysDisplay),
            _buildDetailRow('Status', leave.statusDisplay),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reason',
              style: AppTypography.lightTextTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              leave.reason,
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (leave.status == LeaveStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        leaveStore.approveLeave(leave.id);
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Leave request approved')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: AppSpacing.mdAll,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(context, leave.id),
                      style: OutlinedButton.styleFrom(
                        padding: AppSpacing.mdAll,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showRejectDialog(BuildContext context, String leaveId) {
    final reasonController = TextEditingController();
    final leaveStore = context.read<LeaveStore>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              leaveStore.rejectLeave(leaveId);
              // Create notification for employee
              final leave = leaveStore.leaveRequests
                  .firstWhere((LeaveRequest l) => l.id == leaveId);
              final notificationsStore = context.read<NotificationsStore>();
              final now = DateTime.now();
              notificationsStore.addNotification(
                AppNotification(
                  id: 'leave_rejected_${leaveId}_${now.millisecondsSinceEpoch}',
                  title: 'Leave Request Rejected',
                  body:
                      'Your leave request for ${leave.daysDisplay} has been rejected. Reason: ${reasonController.text.trim()}',
                  createdAt: now,
                  type: NotificationType.error,
                  isRead: false,
                ),
              );
              Navigator.pop(dialogContext);
              Navigator.pop(context); // Close bottom sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Leave request rejected')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

