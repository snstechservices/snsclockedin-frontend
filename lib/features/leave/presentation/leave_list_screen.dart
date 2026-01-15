import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/collapsible_filter_section.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Employee leave list screen
class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
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
    final allUserLeaves = store.getLeaveRequestsByUserId(appState.userId ?? 'current_user');
    
    // Filter leaves by selected status
    final filteredLeaves = _selectedFilter == null
        ? allUserLeaves
        : allUserLeaves.where((leave) => leave.status == _selectedFilter).toList();

    return AppScreenScaffold(
      skipScaffold: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/e/leave/apply'),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
      child: Column(
        children: [
          if (store.usingStale) _buildCacheHint(context),
          const SizedBox(height: AppSpacing.md),
          // Filter Chips
          CollapsibleFilterSection(
            title: 'Status Filter',
            initiallyExpanded: true,
            onClear: () {
              setState(() {
                _selectedFilter = null;
              });
            },
            child: SingleChildScrollView(
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
          ),
          const SizedBox(height: AppSpacing.md),
          // Leave List
          Expanded(
            child: store.isLoading && filteredLeaves.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : store.error != null && filteredLeaves.isEmpty
                    ? _buildErrorState(context, store)
                    : filteredLeaves.isEmpty
                        ? _buildEmptyState(_selectedFilter)
                        : RefreshIndicator(
                            onRefresh: () async {
                              final appState = context.read<AppState>();
                              final userId = appState.userId ?? 'current_user';
                              await store.loadLeaves(userId, forceRefresh: true);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: filteredLeaves.length,
                              itemBuilder: (context, index) {
                                return _buildLeaveCard(filteredLeaves[index]);
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

  Widget _buildErrorState(BuildContext context, LeaveStore store) {
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
                        final appState = context.read<AppState>();
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

  Widget _buildEmptyState(LeaveStatus? filter) {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              filter == null
                  ? 'No Leave Requests'
                  : 'No ${filter == LeaveStatus.pending ? "Pending" : filter == LeaveStatus.approved ? "Approved" : "Rejected"} Requests',
              style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              filter == null
                  ? 'Tap the button below to apply for leave'
                  : 'You don\'t have any ${filter == LeaveStatus.pending ? "pending" : filter == LeaveStatus.approved ? "approved" : "rejected"} leave requests',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (filter == null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => context.go('/e/leave/apply'),
                icon: const Icon(Icons.add),
                label: const Text('Apply Leave'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequest leave) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leave.leaveTypeDisplay,
                style: AppTypography.lightTextTheme.headlineMedium,
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
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              leave.reason,
              style: AppTypography.lightTextTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
}

