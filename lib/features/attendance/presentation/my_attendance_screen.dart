import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/attendance/application/attendance_store.dart';
import 'package:sns_clocked_in/features/attendance/application/break_types_store.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';
import 'package:sns_clocked_in/features/attendance/domain/attendance_event.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/time_tracking/domain/time_entry.dart';

/// Shared "My Attendance" screen
class MyAttendanceScreen extends StatelessWidget {
  const MyAttendanceScreen({
    super.key,
    required this.roleScope,
  });

  final Role roleScope;

  @override
  Widget build(BuildContext context) {
    final attendanceStore = context.watch<AttendanceStore>();
    final timeTrackingStore = context.watch<TimeTrackingStore>();
    final history = attendanceStore.history;
    final isLoading = attendanceStore.isLoading;
    final isClockedIn = timeTrackingStore.isClockedIn;
    final currentDuration = timeTrackingStore.currentDuration;

    // Generate today's timeline events (mock data)
    final todayEvents = _generateTodayTimeline(timeTrackingStore.currentEntry);

    return AppScreenScaffold(
      skipScaffold: true,
      child: Stack(
        children: [
          Column(
            children: [
              // Quick Stats at top (always visible, match pattern)
              _buildQuickStatsSection(history),
              // Main content (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      const SizedBox(height: AppSpacing.lg),

                // Today Timeline Section
                const SectionHeader('Today Timeline'),
                if (todayEvents.isEmpty)
                  _buildTimelineEmptyState()
                else
                  _buildTodayTimeline(todayEvents),
                const SizedBox(height: AppSpacing.lg),

                // History Section
                const SectionHeader('History'),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (history.isEmpty)
                  _buildHistoryEmptyState()
                else
                  ...history.map((entry) => _buildAttendanceCard(context, entry)),
                  
                      // Bottom padding for sticky CTA (accounts for 2 buttons + spacing + safe area)
                      // Max height: clocked in text (24) + spacing (8) + Start Break button (56) + spacing (8) + Clock Out button (56) + padding (16*2) + safe area (~34) = ~202px
                      SizedBox(height: 220 + MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sticky bottom CTA
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyCTA(context, timeTrackingStore, isClockedIn, currentDuration),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(List<TimeEntry> history) {
    // Basic calculation
    final totalEntries = history.length;
    final onTime = history.where((e) => e.status == TimeEntryStatus.present).length;

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
              Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
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
                    'Total Days',
                    totalEntries.toString(),
                    AppColors.primary,
                    Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: _buildStatCard(
                    'On Time',
                    onTime.toString(),
                    AppColors.success,
                    Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildAttendanceCard(BuildContext context, TimeEntry entry) {
    // Date formatting (Basic)
    final dateStr = '${entry.date.day}/${entry.date.month}/${entry.date.year}';
    
    // Time formatting
    String formatTime(DateTime? dt) {
      if (dt == null) return '--:--';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final duration = entry.duration;
    final durationStr = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

    return AppCard(
      padding: AppSpacing.mdAll,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: () => _showDetailSheet(context, entry),
      child: Row(
        children: [
          // Date Column
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Column(
              children: [
                Text(
                  entry.date.day.toString(),
                  style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _getMonthName(entry.date.month),
                  style: AppTypography.lightTextTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shift: $durationStr',
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildStatusChip(entry.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.login, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(entry.startTime),
                      style: AppTypography.lightTextTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.logout, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(entry.endTime),
                      style: AppTypography.lightTextTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TimeEntryStatus status) {
    Color color;
    String label;

    switch (status) {
      case TimeEntryStatus.present:
        color = AppColors.success;
        label = 'Present';
        break;
      case TimeEntryStatus.late:
        color = AppColors.warning;
        label = 'Late';
        break;
      case TimeEntryStatus.absent:
        color = AppColors.error;
        label = 'Absent';
        break;
      case TimeEntryStatus.onLeave:
        color = AppColors.secondary;
        label = 'On Leave';
        break;
      case TimeEntryStatus.halfDay:
        color = AppColors.warning;
        label = 'Half Day';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<AttendanceEvent> _generateTodayTimeline(TimeEntry? currentEntry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = <AttendanceEvent>[];

    if (currentEntry != null && currentEntry.startTime != null) {
      // Clock In event
      events.add(AttendanceEvent(
        type: AttendanceEventType.clockIn,
        time: currentEntry.startTime!,
        location: currentEntry.location,
      ));

      // Mock break events (if clocked in for more than 2 hours)
      final hoursSinceClockIn = now.difference(currentEntry.startTime!).inHours;
      if (hoursSinceClockIn >= 2) {
        final breakStartTime = currentEntry.startTime!.add(const Duration(hours: 2));
        final breakEndTime = breakStartTime.add(const Duration(minutes: 30));
        
        events.add(AttendanceEvent(
          type: AttendanceEventType.breakStart,
          time: breakStartTime,
        ));
        events.add(AttendanceEvent(
          type: AttendanceEventType.breakEnd,
          time: breakEndTime,
        ));
      }
    }

    // Sort by time
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  Widget _buildTodayTimeline(List<AttendanceEvent> events) {
    return AppCard(
      padding: AppSpacing.mdAll,
      child: Column(
        children: events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: event.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      event.icon,
                      color: event.color,
                      size: 20,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Event details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.label,
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: event.color,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            event.timeDisplay,
                            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (event.location != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              event.location!,
                              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineEmptyState() {
    return AppCard(
      padding: AppSpacing.xlAll,
      child: Column(
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No activity today',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Clock in to start tracking your attendance',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return AppCard(
      padding: AppSpacing.xlAll,
      child: Column(
        children: [
          Icon(
            Icons.history_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No attendance history',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your attendance records will appear here',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCTA(
    BuildContext context,
    TimeTrackingStore store,
    bool isClockedIn,
    Duration currentDuration,
  ) {
    final isOnBreak = store.isOnBreak;
    
    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    }

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isClockedIn && !isOnBreak) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Clocked in: ${formatDuration(currentDuration)}',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            // When onBreak: show only "End Break" (primary)
            if (isOnBreak) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: store.isLoading
                      ? null
                      : () async {
                          // End Break
                          await store.endBreak();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Break ended'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: AppSpacing.lgAll,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                    elevation: 0,
                  ),
                  child: store.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.coffee_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'End Break',
                              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ]
            // When clockedIn && !onBreak: show "Start Break" (secondary) + "Clock Out" (primary)
            else if (isClockedIn) ...[
              // Secondary: Start Break
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: store.isLoading
                      ? null
                      : () async {
                          // Show break type selector
                          final breakTypesStore = context.read<BreakTypesStore>();
                          
                          // Load break types if not already loaded
                          if (breakTypesStore.breakTypes.isEmpty && !breakTypesStore.isLoading) {
                            await breakTypesStore.load();
                          }

                          if (!context.mounted) return;
                          
                          final selectedBreakType = await _showBreakTypeSelector(
                            context,
                            breakTypesStore,
                          );

                          if (selectedBreakType != null && context.mounted) {
                            // Start break with selected type
                            await store.startBreak(breakType: selectedBreakType.name);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${selectedBreakType.label} started'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: AppSpacing.lgAll,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.coffee,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Start Break',
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Primary: Clock Out
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: store.isLoading
                      ? null
                      : () async {
                          // Clock Out with confirmation
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clock Out'),
                              content: const Text('Are you sure you want to clock out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Clock Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await store.toggleClockStatus();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Clocked out successfully'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: AppSpacing.lgAll,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                    elevation: 0,
                  ),
                  child: store.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Clock Out',
                              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ]
            // When !clockedIn: show only "Clock In" (primary)
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: store.isLoading
                      ? null
                      : () async {
                          // Clock In
                          try {
                            await store.toggleClockStatus();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Clocked in successfully'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: AppSpacing.lgAll,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mediumAll,
                    ),
                    elevation: 0,
                  ),
                  child: store.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.login,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Clock In',
                              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, TimeEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entry Details',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            // TODO: Detailed breakdown
            Text('ID: ${entry.id}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Location: ${entry.location ?? "Unknown"}'),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<BreakType?> _showBreakTypeSelector(
    BuildContext context,
    BreakTypesStore breakTypesStore,
  ) async {
    return showModalBottomSheet<BreakType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Consumer<BreakTypesStore>(
          builder: (context, store, _) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select break type',
                    style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (store.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (store.error != null && store.breakTypes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Failed to load break types',
                            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: () => store.load(forceRefresh: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (store.breakTypes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No break types available',
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: store.breakTypes.length,
                        itemBuilder: (context, index) {
                          final breakType = store.breakTypes[index];
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: EdgeInsets.zero,
                            onTap: () => Navigator.pop(context, breakType),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                breakType.label,
                                style: AppTypography.lightTextTheme.bodyLarge,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
