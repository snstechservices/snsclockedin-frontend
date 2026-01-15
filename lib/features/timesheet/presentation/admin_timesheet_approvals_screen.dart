import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/segmented_filter_bar.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/timesheet/application/admin_approvals_store.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

/// Admin timesheet approvals screen for managing pending and approved timesheets
/// v2 implementation with go_router, Provider stores, and design tokens
///
/// LEGACY BEHAVIOR PARITY (from TIMESHEET_LEGACY_AUDIT_REPORT.md):
/// - Pending: Records with approvalStatus="pending" awaiting admin review
/// - Approved: Records with approvalStatus="approved" that have been reviewed
/// - Bulk Auto-Approve Eligibility:
///   * Only records that are completed (checkOutTime != null)
///   * AND have approvalStatus="pending"
///   * Cannot approve incomplete records (must have checkOutTime)
/// - Reject Requirements:
///   * Reject action requires a non-empty reason (adminComment field)
///   * Reason is stored in adminComment and displayed to employee
/// - Constraints:
///   * Cannot approve incomplete records (no checkOutTime)
///   * Cannot edit records after approval (read-only in approved tab)
///   * Records move from pending → approved/rejected after action
/// - Cache Strategy:
///   * Cache-first with 1-minute TTL
///   * Offline fallback to stale cache with isStale flag
///   * Shows "Showing cached data" hint when using stale data
class AdminTimesheetApprovalsScreen extends StatefulWidget {
  const AdminTimesheetApprovalsScreen({super.key});

  @override
  State<AdminTimesheetApprovalsScreen> createState() =>
      _AdminTimesheetApprovalsScreenState();
}

class _AdminTimesheetApprovalsScreenState
    extends State<AdminTimesheetApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _pendingFilter = 'all'; // all | complete | incomplete

  @override
  void initState() {
    super.initState();
    // Initialize tab controller - will restore selected tab after first build
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load initial data and restore tab selection after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AdminApprovalsStore>();
      // Restore selected tab if different from current
      if (_tabController.index != store.selectedTab) {
        _tabController.animateTo(store.selectedTab);
      }
      // Only load if we don't have data AND we haven't loaded before
      // This prevents API calls on first screen open when offline
      // The load methods have additional guards, but this is an extra safety check
      print('[AdminTimesheetApprovalsScreen] initState callback: pending=${store.pendingRecords.length}, approved=${store.approvedRecords.length}, isLoading=${store.isLoading}');
      if (store.pendingRecords.isEmpty && store.approvedRecords.isEmpty) {
        // Only attempt load if we're not already loading (prevents duplicate calls)
        if (!store.isLoading) {
          print('[AdminTimesheetApprovalsScreen] CALLING store.loadPending() and loadApproved()');
          store.loadPending();
          store.loadApproved();
        } else {
          print('[AdminTimesheetApprovalsScreen] SKIPPING load - store is already loading');
        }
      } else {
        print('[AdminTimesheetApprovalsScreen] SKIPPING load - store already has data');
      }
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging && mounted) {
      final store = context.read<AdminApprovalsStore>();
      store.setSelectedTab(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(context),
                _buildApprovedTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab(BuildContext context) {
    return Consumer<AdminApprovalsStore>(
      builder: (context, store, _) {
        final filtered = store.pendingRecords.where((r) {
          if (_pendingFilter == 'complete') {
            return r.checkOutTime != null;
          }
          if (_pendingFilter == 'incomplete') {
            return r.checkOutTime == null;
          }
          return true;
        }).toList();

        return Column(
          children: [
            if (store.usingStalePending) _buildCacheHint(context),
            const SizedBox(height: AppSpacing.sm),
            SegmentedFilterBar<String>(
              selected: _pendingFilter,
              onChanged: (value) {
                setState(() => _pendingFilter = value);
              },
              options: const [
                FilterOption(label: 'All', value: 'all'),
                FilterOption(label: 'Completed', value: 'complete'),
                FilterOption(label: 'Incomplete', value: 'incomplete'),
              ],
            ),
            // Bulk auto-approve button
            if (store.eligibleForBulkApprove.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (store.isLoading || store.isBulkApproving)
                        ? null
                        : () => _showBulkApproveDialog(context, store),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Auto-approve completed (${store.eligibleForBulkApprove.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: AppSpacing.lgAll,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _buildPendingList(context, store, filtered),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCacheHint(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 14,
            color: AppColors.warning.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Showing cached data',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.warning.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList(
    BuildContext context,
    AdminApprovalsStore store,
    List<AttendanceRecord> filtered,
  ) {
    if (store.isLoadingPending && store.pendingRecords.isEmpty) {
      return const ListSkeleton(items: 4);
    }

    if (store.errorPending != null && store.pendingRecords.isEmpty) {
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
                  'Failed to load pending timesheets',
                  style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  store.errorPending ?? 'Unknown error',
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: store.isLoadingPending
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

    return RefreshIndicator(
      onRefresh: () async {
        await store.loadPending(forceRefresh: true);
        // Also refresh approved list to clear stale flags
        await store.loadApproved(forceRefresh: true);
      },
      child: filtered.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No pending timesheets',
                          style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          store.usingStalePending
                              ? 'No cached data available'
                              : 'All timesheets have been reviewed',
                          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: store.isLoadingPending
                              ? null
                              : () => store.loadPending(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final record = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildRecordCard(context, record, store, isPending: true),
                );
              },
            ),
    );
  }

  Widget _buildApprovedTab(BuildContext context) {
    return Consumer<AdminApprovalsStore>(
      builder: (context, store, _) {
        return Column(
          children: [
            if (store.usingStaleApproved) _buildCacheHint(context),
            Expanded(
              child: _buildApprovedList(context, store),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovedList(BuildContext context, AdminApprovalsStore store) {
    if (store.isLoadingApproved && store.approvedRecords.isEmpty) {
      return const ListSkeleton(items: 3);
    }

    if (store.errorApproved != null && store.approvedRecords.isEmpty) {
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
                  'Failed to load approved timesheets',
                  style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  store.errorApproved ?? 'Unknown error',
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: store.isLoadingApproved
                      ? null
                      : () => store.loadApproved(forceRefresh: true),
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

    return RefreshIndicator(
      onRefresh: () async {
        await store.loadApproved(forceRefresh: true);
        // Also refresh pending list to clear stale flags
        await store.loadPending(forceRefresh: true);
      },
      child: store.approvedRecords.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No approved timesheets',
                          style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          store.usingStaleApproved
                              ? 'No cached data available'
                              : 'Approved timesheets will appear here',
                          style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: store.isLoadingApproved
                              ? null
                              : () => store.loadApproved(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: store.approvedRecords.length,
              itemBuilder: (context, index) {
                final record = store.approvedRecords[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildRecordCard(context, record, store, isPending: false),
                );
              },
            ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    AttendanceRecord record,
    AdminApprovalsStore store, {
    required bool isPending,
  }) {
    final isRecordLoading = store.isRecordLoading(record.id);
    final isDisabled = store.isLoading || isRecordLoading;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Status icon (smaller for better density)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPending ? AppColors.warning : AppColors.success,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isPending ? Icons.schedule : Icons.check_circle,
                  color: isPending ? AppColors.warning : AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName,
                      style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.dateLabel,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Time range and duration (more compact)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.timeRangeLabel,
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                record.durationLabel,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Status badge
          Align(
            alignment: Alignment.centerLeft,
            child: _buildStatusBadge(record),
          ),
          // Actions for pending records
          if (isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isDisabled
                        ? null
                        : () => _showRejectDialog(context, record, store),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    ),
                    child: isRecordLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isDisabled
                        ? null
                        : () => _approveRecord(context, record, store),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    ),
                    child: isRecordLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceRecord record) {
    final (color, label) = switch (record.approvalStatus) {
      ApprovalStatus.approved => (AppColors.success, 'Approved'),
      ApprovalStatus.pending => (AppColors.warning, 'Pending'),
      ApprovalStatus.rejected => (AppColors.error, 'Rejected'),
    };

    final type = switch (record.approvalStatus) {
      ApprovalStatus.approved => StatusBadgeType.approved,
      ApprovalStatus.pending => StatusBadgeType.pending,
      ApprovalStatus.rejected => StatusBadgeType.rejected,
    };

    return StatusBadge(label: label, type: type);
  }

  Future<void> _approveRecord(
    BuildContext context,
    AttendanceRecord record,
    AdminApprovalsStore store,
  ) async {
    if (!context.mounted) return;
    try {
      await store.approveOne(context, record);
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
    AdminApprovalsStore store,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Timesheet'),
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
                decoration: const InputDecoration(
                  hintText: 'Rejection reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
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
      if (!context.mounted) return;
      try {
        await store.rejectOne(
          context,
          record,
          reason: reasonController.text.trim(),
        );
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

  Future<void> _showBulkApproveDialog(
    BuildContext context,
    AdminApprovalsStore store,
  ) async {
    final eligibleCount = store.eligibleForBulkApprove.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Auto-Approve'),
        content: Text(
          'This will approve $eligibleCount eligible timesheet(s) (completed/checked out only). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      try {
        final approvedCount = await store.bulkAutoApproveEligible(context);
        if (context.mounted) {
          if (approvedCount == eligibleCount) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully approved $approvedCount timesheet(s)'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            // Partial success
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Approved $approvedCount of $eligibleCount timesheet(s). Some records may still be pending.',
                ),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to bulk approve: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}


