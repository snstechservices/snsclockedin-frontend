import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/collapsible_filter_section.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/timesheet_admin/application/admin_timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet_admin/data/admin_timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

/// Admin timesheet approvals screen for managing pending and approved timesheets
class AdminTimesheetApprovalsScreen extends StatefulWidget {
  const AdminTimesheetApprovalsScreen({super.key});

  @override
  State<AdminTimesheetApprovalsScreen> createState() => _AdminTimesheetApprovalsScreenState();
}

class _AdminTimesheetApprovalsScreenState extends State<AdminTimesheetApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminTimesheetStore? _store;
  bool _storeCreatedByScreen = false; // Track if we created the store (should dispose it)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final store = _getOrCreateStore(context);
        store.setSelectedTab(_tabController.index);
      }
    });

    // Load initial data after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = _getOrCreateStore(context);
      store.loadPending();
      store.loadApproved();
    });
  }

  AdminTimesheetStore _getOrCreateStore(BuildContext context) {
    if (_store != null) return _store!;

    // Check if a store is already provided via Provider (useful for testing)
    try {
      final providedStore = context.read<AdminTimesheetStore>();
      _store = providedStore;
      _storeCreatedByScreen = false; // Don't dispose Provider-provided stores
      return _store!;
    } catch (_) {
      // No store in Provider, create a new one
      _store = AdminTimesheetStore(
        repository: AdminTimesheetRepository(),
      );
      _storeCreatedByScreen = true; // We created it, so we should dispose it
      return _store!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Only dispose the store if we created it (not if it was provided via Provider)
    if (_storeCreatedByScreen) {
      _store?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _getOrCreateStore(context);

    return ChangeNotifierProvider.value(
      value: store,
      child: AppScreenScaffold(
        skipScaffold: true,
        child: Column(
          children: [
            // Summary Stat Cards Section
            Consumer<AdminTimesheetStore>(
              builder: (context, store, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Total Records',
                          value: store.totalCount.toString(),
                          icon: Icons.assessment,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatCard(
                          title: 'Present',
                          value: store.presentCount.toString(),
                          icon: Icons.check_circle,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatCard(
                          title: 'On Break',
                          value: store.onBreakCount.toString(),
                          icon: Icons.pause_circle,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Collapsible Filter Section
            Consumer<AdminTimesheetStore>(
              builder: (context, store, _) {
                return CollapsibleFilterSection(
                  title: 'Filters',
                  initiallyExpanded: false,
                  onClear: () {
                    // Clear filters logic (if needed)
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date range quick buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Today filter
                              },
                              child: const Text('Today'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Yesterday filter
                              },
                              child: const Text('Yesterday'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // This Week filter
                              },
                              child: const Text('This Week'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Employee dropdown (placeholder)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Employee',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Employees')),
                        ],
                        onChanged: (value) {
                          // Employee filter logic
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
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
                  _buildPendingTab(context, store),
                  _buildApprovedTab(context, store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab(BuildContext context, AdminTimesheetStore store) {
    return Consumer<AdminTimesheetStore>(
      builder: (context, store, _) {
        // Show cache hint if needed
        final hasStaleData = store.errorPending != null && store.pendingRecords.isNotEmpty;

        return Column(
          children: [
            if (hasStaleData) _buildCacheHint(context),
            // Bulk auto-approve button
            if (store.eligibleForBulkApprove.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: store.isLoading
                        ? null
                        : () => _showBulkApproveDialog(context, store),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Bulk Approve (${store.eligibleForBulkApprove.length} eligible)',
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
              child: _buildPendingList(context, store),
            ),
          ],
        );
      },
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

  Widget _buildPendingList(BuildContext context, AdminTimesheetStore store) {
    if (store.isLoadingPending && store.pendingRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.errorPending != null && store.pendingRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
        ),
      );
    }

    if (store.pendingRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 80,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No attendance records found',
                style: AppTypography.lightTextTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No pending timesheets to approve',
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

    return RefreshIndicator(
      onRefresh: () => store.loadPending(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: store.pendingRecords.length,
        itemBuilder: (context, index) {
          final record = store.pendingRecords[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildRecordCard(context, record, store, isPending: true),
          );
        },
      ),
    );
  }

  Widget _buildApprovedTab(BuildContext context, AdminTimesheetStore store) {
    return Consumer<AdminTimesheetStore>(
      builder: (context, store, _) {
        return _buildApprovedList(context, store);
      },
    );
  }

  Widget _buildApprovedList(BuildContext context, AdminTimesheetStore store) {
    if (store.isLoadingApproved && store.approvedRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.errorApproved != null && store.approvedRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
        ),
      );
    }

    if (store.approvedRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No approved timesheets',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => store.loadApproved(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: store.approvedRecords.length,
        itemBuilder: (context, index) {
          final record = store.approvedRecords[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildRecordCard(context, record, store, isPending: false),
          );
        },
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    AttendanceRecord record,
    AdminTimesheetStore store, {
    required bool isPending,
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

    // Format date
    final date = record.date.toLocal();
    final dateStr = '${date.day}/${date.month}/${date.year}';

    // Get employee name (TODO: get from API when available)
    final userIdPrefix = record.userId.length > 8 
        ? record.userId.substring(0, 8) 
        : record.userId;
    final employeeName = 'Employee $userIdPrefix${record.userId.length > 8 ? '...' : ''}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPending ? AppColors.warning : AppColors.success,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isPending ? Icons.schedule : Icons.check_circle,
                  color: isPending ? AppColors.warning : AppColors.success,
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
                      employeeName,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dateStr,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Time range and duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$checkInStr → $checkOutStr',
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                durationStr,
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Status badge
          _buildStatusBadge(record.approvalStatus),
          // Actions for pending records
          if (isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: store.isLoading
                        ? null
                        : () => _showRejectDialog(context, record, store),
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
                    onPressed: store.isLoading
                        ? null
                        : () => _approveRecord(context, record, store),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _approveRecord(
    BuildContext context,
    AttendanceRecord record,
    AdminTimesheetStore store,
  ) async {
    try {
      await store.approveOne(record.id);
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
        // Handle 401 unauthorized
        if (e is ApiException && e.statusCode == 401) {
          context.read<AppState>().logout();
          context.go('/login');
          return;
        }
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
      try {
        await store.rejectOne(record.id, reason: reasonController.text.trim());
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
          // Handle 401 unauthorized
          if (e is ApiException && e.statusCode == 401) {
            context.read<AppState>().logout();
            context.go('/login');
            return;
          }
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
    AdminTimesheetStore store,
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
      try {
        final result = await store.bulkAutoApprove();
        final approvedCount = result['approvedCount'] as int? ?? eligibleCount;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully approved $approvedCount timesheet(s)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          // Handle 401 unauthorized
          if (e is ApiException && e.statusCode == 401) {
            context.read<AppState>().logout();
            context.go('/login');
            return;
          }
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

// Manual Test Checklist:
// 1. Navigation:
//    - [ ] Route /a/reports accessible from drawer
//    - [ ] Drawer item "Reports" is highlighted when on this screen
//    - [ ] Deep links work correctly
//
// 2. Tabs:
//    - [ ] Pending tab shows pending records
//    - [ ] Approved tab shows approved records
//    - [ ] Tab switching works smoothly
//
// 3. Pending Tab:
//    - [ ] Each record shows employee name, date, time range, duration, status badge
//    - [ ] Approve button approves record (optimistic update)
//    - [ ] Reject button opens dialog requiring reason
//    - [ ] Reject dialog validates non-empty reason
//    - [ ] After approve/reject, record moves/removes correctly
//    - [ ] Bulk auto-approve button shows count of eligible records
//    - [ ] Bulk auto-approve button disabled when no eligible records
//    - [ ] Bulk auto-approve shows confirmation dialog
//    - [ ] Bulk auto-approve only approves completed records
//
// 4. Approved Tab:
//    - [ ] Shows approved records (read-only, no actions)
//    - [ ] Records display correctly with all details
//
// 5. Caching & Offline:
//    - [ ] "Showing cached data" hint appears when using stale cache
//    - [ ] Pull-to-refresh forces network refresh
//    - [ ] Offline mode shows cached data even if expired
//    - [ ] No cache shows empty state with friendly message
//
// 6. Error Handling:
//    - [ ] Error states show retry button
//    - [ ] Optimistic updates rollback on error
//    - [ ] SnackBar shows success/failure messages
//    - [ ] 401 errors trigger logout (via AppState)
//
// 7. Loading States:
//    - [ ] Loading indicators show during fetch
//    - [ ] Actions disabled during loading
//    - [ ] Separate loading states for pending/approved tabs

