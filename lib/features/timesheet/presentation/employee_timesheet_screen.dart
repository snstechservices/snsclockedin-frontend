import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/timesheet/application/timesheet_store.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

/// Employee timesheet screen showing attendance history with date range filtering
class EmployeeTimesheetScreen extends StatefulWidget {
  const EmployeeTimesheetScreen({super.key});

  @override
  State<EmployeeTimesheetScreen> createState() => _EmployeeTimesheetScreenState();
}

class _EmployeeTimesheetScreenState extends State<EmployeeTimesheetScreen> {

  @override
  void initState() {
    super.initState();
    // Seed demo data in debug mode to avoid empty UI during development
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<TimesheetStore>();
      if (kDebugMode) {
        // Seed debug data first if no records exist
        store.seedDebugData();
      }
      // Load initial data only if store has no records AND has not loaded before
      // (This won't run if seedDebugData populated records)
      if (store.records.isEmpty && !store.hasLoadedOnce) {
        store.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TimesheetStore>();

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match admin pattern)
          _buildQuickStatsSection(context),
          // Date Range Selector
          _buildDateRangeSelector(context),
          const SizedBox(height: AppSpacing.sm),
          // Cache Hint
          _buildCacheHint(context),
          const SizedBox(height: AppSpacing.md),
          // Records List (scrollable)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.refresh(),
              child: _buildRecordsList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    return Consumer<TimesheetStore>(
      builder: (context, store, _) {
        final currentPreset = store.currentPreset;
        final pills = [
          ('Today', TimesheetRangePreset.today),
          ('This Week', TimesheetRangePreset.thisWeek),
          ('This Month', TimesheetRangePreset.thisMonth),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  for (final pill in pills) ...[
                    _buildRangePill(
                      context,
                      label: pill.$1,
                      isSelected: currentPreset == pill.$2,
                      onTap: () => store.setRangePreset(pill.$2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  _buildRangePill(
                    context,
                    label: 'Custom',
                    isSelected: currentPreset == TimesheetRangePreset.custom,
                    onTap: () => _showCustomDateRangePicker(context, store),
                    isOutlined: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRangePill(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isOutlined
              ? Colors.transparent
              : (isSelected ? AppColors.primary : AppColors.surface),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          label,
          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
            color: isOutlined
                ? (isSelected ? AppColors.primary : AppColors.textPrimary)
                : (isSelected ? Colors.white : AppColors.textPrimary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _buildRangePill(
      context,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildCacheHint(BuildContext context) {
    return Consumer<TimesheetStore>(
      builder: (context, store, _) {
        if (!store.isStale && !store.isFromCache) {
          return const SizedBox.shrink();
        }

        return Container(
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
              Text(
                'Showing cached data',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStatsSection(BuildContext context) {
    return Consumer<TimesheetStore>(
      builder: (context, store, _) {
        final summary = store.computedSummary;
        
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
                        summary.totalRecords.toString(),
                        AppColors.textPrimary,
                        Icons.list_alt,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Approved',
                        summary.approved.toString(),
                        AppColors.success,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Completed',
                        summary.completed.toString(),
                        AppColors.secondary,
                        Icons.done_all,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Clocked In',
                        summary.clockedIn.toString(),
                        AppColors.secondary,
                        Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Pending',
                        summary.pending.toString(),
                        AppColors.warning,
                        Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 140,
                      child: _buildStatCard(
                        'Rejected',
                        summary.rejected.toString(),
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

  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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

  Widget _buildRecordsList(BuildContext context) {
    return Consumer<TimesheetStore>(
      builder: (context, store, _) {
        if (store.isLoading && store.records.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (store.errorMessage != null && store.records.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load timesheet',
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => store.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (store.records.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No records found for selected date range',
                  style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }

        // Group records by date
        final groupedRecords = store.groupedRecords;
        final sortedDates = groupedRecords.keys.toList()..sort((a, b) => b.compareTo(a));

        // Build a flat list of widgets
        final List<Widget> items = [];
        for (final date in sortedDates) {
          final recordsForDate = groupedRecords[date];
          if (recordsForDate == null || recordsForDate.isEmpty) {
            continue;
          }
          items.add(SectionHeader(_formatDateHeader(date)));
          items.add(const SizedBox(height: AppSpacing.md));
          for (final record in recordsForDate) {
            items.add(Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildRecordCard(record),
            ));
          }
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: items,
        );
      },
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final checkInTime = record.checkInTime;
    final checkOutTime = record.checkOutTime;
    final duration = record.workDuration;
    final isInProgress = checkOutTime == null;

    // Format times in local timezone
    String formatTime(DateTime? dt) {
      if (dt == null) return '—';
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final checkInStr = formatTime(checkInTime);
    final checkOutStr = isInProgress ? 'N/A' : formatTime(checkOutTime);

    // Format duration (clamp to >= 0 to prevent negative durations)
    // Use a large but finite number instead of infinity to avoid toInt() errors
    final rawMinutes = duration.inMinutes;
    final durationMinutes = rawMinutes.isFinite 
        ? rawMinutes.clamp(0, 999999) 
        : 0;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    final durationStr = isInProgress ? 'So far: ${hours}h ${minutes}m' : '${hours}h ${minutes}m';

    // Get status color and icon
    final (color, icon) = _getStatusColorAndIcon(record.approvalStatus);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showRecordDetailSheet(context, record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                    _buildApprovalBadge(record.approvalStatus),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isInProgress ? 'N/A' : durationStr,
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

  Widget _buildApprovalBadge(ApprovalStatus status) {
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

  Widget _buildWorkStateChip(bool isInProgress) {
    final (color, label) = isInProgress
        ? (AppColors.secondary, 'In progress')
        : (AppColors.success, 'Completed');

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

  void _showRecordDetailSheet(BuildContext context, AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordDetailSheet(record: record),
    );
  }

  (Color, IconData) _getStatusColorAndIcon(ApprovalStatus status) {
    return switch (status) {
      ApprovalStatus.approved => (AppColors.success, Icons.check_circle),
      ApprovalStatus.pending => (AppColors.warning, Icons.schedule),
      ApprovalStatus.rejected => (AppColors.error, Icons.cancel),
    };
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    final local = date.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (dateOnly == today) {
      return 'Attendance Records for Today (${months[local.month - 1]} ${local.day}, ${local.year})';
    } else if (dateOnly == yesterday) {
      return 'Attendance Records for Yesterday (${months[local.month - 1]} ${local.day}, ${local.year})';
    } else {
      // Format as "Attendance Records for Monday, Jan 15, 2026"
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return 'Attendance Records for ${weekdays[local.weekday - 1]} (${months[local.month - 1]} ${local.day}, ${local.year})';
    }
  }

  Future<void> _showCustomDateRangePicker(
    BuildContext context,
    TimesheetStore store,
  ) async {
    final now = DateTime.now();
    final initialRange = store.currentPreset == TimesheetRangePreset.custom &&
            store.customStartDate != null &&
            store.customEndDate != null
        ? DateTimeRange(
            start: store.customStartDate!,
            end: store.customEndDate!,
          )
        : DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
    );

    if (picked != null) {
      // Normalize dates to start of day
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      final end = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      store.setCustomRange(start, end);
    }
  }
}

/// Bottom sheet showing detailed record information
class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({required this.record});

  final AttendanceRecord record;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatDuration(Duration duration) {
    // Clamp to >= 0 to prevent negative durations
    // Use a large but finite number instead of infinity to avoid toInt() errors
    final rawMinutes = duration.inMinutes;
    final durationMinutes = rawMinutes.isFinite 
        ? rawMinutes.clamp(0, 999999) 
        : 0;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final duration = record.workDuration;
    final isInProgress = record.checkOutTime == null;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Record Details',
                    style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Details
                  _buildDetailRow('Date', _formatDate(record.date)),
                  const Divider(height: AppSpacing.md),
                  _buildDetailRow('Check In', _formatTime(record.checkInTime)),
                  const Divider(height: AppSpacing.md),
                  _buildDetailRow(
                    'Check Out',
                    isInProgress ? 'In progress' : _formatTime(record.checkOutTime),
                  ),
                  const Divider(height: AppSpacing.md),
                  _buildDetailRow(
                    'Duration',
                    isInProgress ? 'So far: ${_formatDuration(duration)}' : _formatDuration(duration),
                  ),
                  if (record.totalBreakTimeMinutes > 0) ...[
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Total Breaks', '${record.totalBreakTimeMinutes}m'),
                  ],
                  const Divider(height: AppSpacing.md),
                  _buildDetailRowWithStatus(
                    'Approval Status',
                    record.approvalStatusLabel,
                    record.approvalStatus,
                  ),
                  if (record.approvalStatus == ApprovalStatus.rejected &&
                      (record.rejectionReason != null && record.rejectionReason!.isNotEmpty)) ...[
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Rejection Reason', record.rejectionReason!),
                  ],
                  if (record.adminComment != null && record.adminComment!.isNotEmpty) ...[
                    const Divider(height: AppSpacing.md),
                    _buildDetailRow('Admin Comment', record.adminComment!),
                  ],
                  // Show breaks section only if breaks exist AND totalBreakTimeMinutes > 0
                  if (record.breaks.isNotEmpty && record.totalBreakTimeMinutes > 0) ...[
                    const Divider(height: AppSpacing.md),
                    _buildBreaksSection(record.breaks),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithStatus(String label, String value, ApprovalStatus status) {
    final (color, _) = switch (status) {
      ApprovalStatus.approved => (AppColors.success, 'Approved'),
      ApprovalStatus.pending => (AppColors.warning, 'Pending'),
      ApprovalStatus.rejected => (AppColors.error, 'Rejected'),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
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
              value,
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreaksSection(List<AttendanceBreak> breaks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Breaks',
          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...breaks.map((breakItem) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${breakItem.breakType}: ${breakItem.durationMinutes}m',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )),
      ],
    );
  }
}

// Manual Test Checklist:
// 1. Date Range Selector:
//    - [ ] Today button selects today's range
//    - [ ] This Week button selects current week
//    - [ ] This Month button selects current month
//    - [ ] Custom opens date range picker and applies selection
//    - [ ] Selected button is highlighted with primary color
//
// 2. Summary Card:
//    - [ ] Expands/collapses when clicking header icon
//    - [ ] Shows 6 metrics: Total Records, Approved, Completed, Clocked In, Pending, Rejected
//    - [ ] Status legend shows colored dots for Approved/Pending/Rejected
//    - [ ] Numbers match the records list
//
// 3. Records List:
//    - [ ] Each record shows date, time range (check-in → check-out), duration
//    - [ ] Status icon circle matches approval status (green=approved, orange=pending, red=rejected)
//    - [ ] Approval badge shows correct status label
//    - [ ] Empty state shows friendly message when no records
//    - [ ] Error state shows retry button
//
// 4. Caching & Offline:
//    - [ ] "Showing cached data" hint appears when using stale cache
//    - [ ] Pull-to-refresh forces network refresh
//    - [ ] Offline mode shows cached data even if expired
//    - [ ] No cache shows empty list with friendly message
//
// 5. Navigation:
//    - [ ] Route /e/timesheet accessible from drawer
//    - [ ] Drawer item "Timesheet" is highlighted when on this screen
//    - [ ] Deep links work correctly
//
// 6. Summary Endpoint:
//    - [ ] Summary loads from GET /attendance/summary/{userId} (5min cache)
//    - [ ] Falls back to computed summary from records if endpoint fails

