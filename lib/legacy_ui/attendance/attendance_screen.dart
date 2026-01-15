import 'package:flutter/material.dart';
import 'package:sns_rooster/widgets/responsive_row.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/providers/attendance_provider.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/providers/company_provider.dart';
import 'package:sns_rooster/widgets/app_drawer.dart';
import 'package:sns_rooster/widgets/admin_side_navigation.dart';
import 'package:sns_rooster/widgets/modern_card_widget.dart';
import 'package:sns_rooster/theme/app_theme.dart';
import 'package:sns_rooster/utils/time_utils.dart';
import 'package:sns_rooster/utils/theme_utils.dart';
import 'package:sns_rooster/widgets/shared_app_bar.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String filterStatus = 'All';
  bool _isSummaryMinimized = true; // Track if attendance summary is minimized

  @override
  void initState() {
    super.initState();
    // Use offline-first load method that loads from cache first, then refreshes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceData();
    });
  }

  Future<void> _loadAttendanceData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    if (authProvider.user != null && mounted) {
      await attendanceProvider.fetchUserAttendance(authProvider.user!['_id']);
    }
  }

  // Keep for backward compatibility (refresh button)
  Future<void> fetchAttendanceData() async {
    await _loadAttendanceData();
  }

  String _calculateStatus(Map<String, dynamic> attendance) {
    if (attendance['checkOutTime'] != null) {
      return 'completed';
    } else if (attendance['checkInTime'] != null) {
      final breaks = attendance['breaks'] as List<dynamic>?;
      if (breaks != null && breaks.isNotEmpty) {
        final lastBreak = breaks.last;
        if (lastBreak['end'] == null) {
          return 'on_break';
        }
      }
      return 'clocked_in';
    }
    return 'not_clocked_in';
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    final date = TimeUtils.parseToLocal(dateField.toString());
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return TimeUtils.formatDate(date, user: user);
  }

  String _formatTime(dynamic timeField) {
    if (timeField == null) return 'N/A';
    if (timeField is String &&
        timeField.contains(':') &&
        !timeField.contains('T')) {
      return timeField;
    }
    final time = TimeUtils.parseToLocal(timeField.toString());
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;
    final company = companyProvider.currentCompany?.toJson();
    return TimeUtils.formatTimeWithSmartTimezone(
      time,
      user: user,
      company: company,
    );
  }

  Widget _buildSummaryCard(
    String title,
    dynamic count,
    Color color,
    String statusKey,
    IconData icon,
  ) {
    final isSelected = filterStatus == statusKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          filterStatus = statusKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [color, color.withValues(alpha: 0.8)]
                : [color.withValues(alpha: 0.7), color.withValues(alpha: 0.5)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.0)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                '$count',
                style: AppTheme.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOvertimeSummaryCard(
    double totalOvertimeHours,
    int daysWithOvertime,
  ) {
    final theme = Theme.of(context);
    final warningColor = ThemeUtils.getStatusChipColor('warning', theme);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            warningColor.withValues(alpha: 0.8),
            warningColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: warningColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(Icons.timer, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overtime Summary',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalOvertimeHours.toStringAsFixed(1)} hours across $daysWithOvertime days',
                    style: AppTheme.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppTheme.success;
        label = 'Completed';
        break;
      case 'on_break':
        color = AppTheme.warning;
        label = 'On Break';
        break;
      case 'clocked_in':
        color = AppTheme.primary;
        label = 'Clocked In';
        break;
      default:
        color = AppTheme.error;
        label = 'Not Clocked In';
    }
    return Container(
      padding: AppTheme.inputPadding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Text(
        label,
        style: AppTheme.smallCaption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in. Please log in.')),
      );
    }
    final isAdmin = user['role'] == 'admin';
    if (isAdmin) {
      return Scaffold(
        appBar: SharedAppBar(title: 'Attendance'),
        body: const Center(child: Text('Access denied')),
        drawer: const AdminSideNavigation(currentRoute: '/attendance'),
      );
    }
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final attendanceRecords = attendanceProvider.attendanceRecords;

    // Filtered data
    List<dynamic> filteredData = attendanceRecords;
    if (filterStatus != 'All') {
      filteredData = attendanceRecords
          .where((item) => _calculateStatus(item) == filterStatus)
          .toList();
    }

    // Stats
    final total = attendanceRecords.length;
    final completed = attendanceRecords
        .where((item) => _calculateStatus(item) == 'completed')
        .length;

    // Calculate overtime statistics
    double totalOvertimeHours = 0;
    int daysWithOvertime = 0;

    // Calculate total hours worked
    double totalHoursWorked = 0;

    for (var item in attendanceRecords) {
      if (item['isOvertime'] == true && item['overtimeHours'] != null) {
        totalOvertimeHours += (item['overtimeHours'] as num).toDouble();
        daysWithOvertime++;
      }

      // Calculate total hours for the period
      if (item['totalWorkHours'] != null) {
        totalHoursWorked += (item['totalWorkHours'] as num).toDouble();
      }
    }

    return Scaffold(
      appBar: SharedAppBar(
        title: 'Attendance',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchAttendanceData();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            ModernCard(
              accentColor: Theme.of(context).colorScheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with minimize button (responsive)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Attendance Summary',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSummaryMinimized = !_isSummaryMinimized;
                          });
                        },
                        icon: Icon(
                          _isSummaryMinimized
                              ? Icons.expand_more
                              : Icons.expand_less,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: _isSummaryMinimized
                            ? 'Expand Summary'
                            : 'Minimize Summary',
                      ),
                    ],
                  ),
                  // Show content only if not minimized
                  if (!_isSummaryMinimized) ...[
                    const SizedBox(height: 16),
                    // Enhanced Summary Cards - Removed "Not Clocked In" card
                    // Use ResponsiveRow to avoid overflow on narrow screens
                    ResponsiveRow(
                      children: [
                        _buildSummaryCard(
                          'Total',
                          total,
                          AppTheme.primary,
                          'All',
                          Icons.all_inclusive,
                        ),
                        _buildSummaryCard(
                          'Completed',
                          completed,
                          AppTheme.success,
                          'completed',
                          Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    ResponsiveRow(
                      children: [
                        _buildSummaryCard(
                          'Total Hours',
                          totalHoursWorked.toStringAsFixed(1),
                          AppTheme.primary,
                          'All',
                          Icons.timer,
                        ),
                        Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final warningColor = ThemeUtils.getStatusChipColor(
                              'warning',
                              theme,
                            );
                            return _buildSummaryCard(
                              'OT Days',
                              daysWithOvertime,
                              warningColor,
                              'All',
                              Icons.timer_outlined,
                            );
                          },
                        ),
                      ],
                    ),
                    if (daysWithOvertime > 0) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      _buildOvertimeSummaryCard(
                        totalOvertimeHours,
                        daysWithOvertime,
                      ),
                    ],
                  ], // Close the conditional content block
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Range and Actions Card
            ModernCard(
              accentColor: Theme.of(context).colorScheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter & Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Range Display
                  Text(
                    _startDate != null && _endDate != null
                        ? '${TimeUtils.formatReadableDate(_startDate!)} – ${TimeUtils.formatReadableDate(_endDate!)}'
                        : 'All records',
                    style: AppTheme.titleLarge.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Range Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDateRange:
                              _startDate != null && _endDate != null
                              ? DateTimeRange(
                                  start: _startDate!,
                                  end: _endDate!,
                                )
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked.start;
                            _endDate = picked.end;
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Change Date Range'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.success,
                                AppTheme.success.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.success.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingL,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                              ),
                            ),
                            onPressed: () => _exportAttendanceData(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primary,
                                AppTheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.view_list_rounded, size: 20),
                            label: const Text('View Timesheet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingL,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/timesheet');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Records Section
            if (filteredData.isEmpty)
              ModernCard(
                accentColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 48,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          'No attendance records available.',
                          style: AppTheme.titleLarge.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Your attendance records will appear here.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ModernCard(
                accentColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Records',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...filteredData.map((item) {
                      final status = _calculateStatus(item);
                      final date = _formatDate(item['date']);
                      final checkIn = _formatTime(item['checkInTime']);
                      final checkOut = _formatTime(item['checkOutTime']);
                      String totalHoursWorked = '';
                      String overtimeHours = '';
                      final overtimeH = item['overtimeHours'] ?? 0;
                      final isOvertime = item['isOvertime'] ?? false;

                      if (item['checkInTime'] != null &&
                          item['checkOutTime'] != null) {
                        // Backend sends time strings (HH:mm) that need to be combined with the date
                        final dateString = item['date'] as String?;
                        final checkInDt = TimeUtils.parseTimeWithDate(
                          item['checkInTime'],
                          dateString,
                        );
                        final checkOutDt = TimeUtils.parseTimeWithDate(
                          item['checkOutTime'],
                          dateString,
                        );
                        if (checkInDt == null || checkOutDt == null) {
                          return Container(); // Return empty container if data is invalid
                        }
                        final breakMs = item['totalBreakDuration'] ?? 0;
                        final workMs =
                            checkOutDt.difference(checkInDt).inMilliseconds -
                            breakMs;
                        final workH = workMs ~/ (1000 * 60 * 60);
                        final workM =
                            ((workMs % (1000 * 60 * 60)) / (1000 * 60)).round();
                        totalHoursWorked = '${workH}h ${workM}m';

                        // Calculate overtime hours if present
                        if (isOvertime && overtimeH > 0) {
                          final otH = overtimeH as num;
                          final otHours = otH.toInt();
                          final otMinutes = ((otH - otHours) * 60).round();
                          overtimeHours = '${otHours}h ${otMinutes}m';
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: AppTheme.spacingM,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              _getStatusColor(status).withValues(alpha: 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date: $date',
                                          style: AppTheme.titleLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingM),

                              // Time Information (simplified for ModernCard)
                              // Use a responsive Row with Expanded children so texts wrap
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Check In: $checkIn',
                                      softWrap: true,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  Expanded(
                                    child: Text(
                                      'Check Out: $checkOut',
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                              if (totalHoursWorked.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                // Use Wrap to avoid overflow on narrow screens
                                Wrap(
                                  spacing: AppTheme.spacingM,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Hours Worked: $totalHoursWorked',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isOvertime && overtimeHours.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacingS,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ThemeUtils.getStatusChipColor(
                                            'warning',
                                            Theme.of(context),
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSmall,
                                          ),
                                          border: Border.all(
                                            color:
                                                ThemeUtils.getStatusChipColor(
                                                  'warning',
                                                  Theme.of(context),
                                                ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final warningColor =
                                                ThemeUtils.getStatusChipColor(
                                                  'warning',
                                                  Theme.of(context),
                                                );
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.timer,
                                                  size: 14,
                                                  color: warningColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'OT: $overtimeHours',
                                                  style: AppTheme.bodyMedium
                                                      .copyWith(
                                                        color: warningColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'not_clocked_in':
        return Icons.cancel_outlined;
      case 'on_break':
        return Icons.coffee_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'on_break':
        return AppTheme.warning;
      case 'clocked_in':
        return AppTheme.primary;
      default:
        return AppTheme.error;
    }
  }

  // Export attendance data as CSV using share intent (Google Play compliant)
  Future<void> _exportAttendanceData() async {
    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(
        context,
        listen: false,
      );
      final attendanceData = attendanceProvider.attendanceRecords;

      if (attendanceData.isEmpty) {
        GlobalNotificationService().showWarning('No attendance data to export');
        return;
      }

      // Create CSV data
      final csvData = <List<dynamic>>[
        [
          'Date',
          'Check In',
          'Check Out',
          'Status',
          'Hours Worked',
          'Location',
          'Notes',
        ],
      ];

      // Get user and company for timezone conversion
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();

      for (final record in attendanceData) {
        // Use checkInTime/checkOutTime (backend fields) with fallback to checkIn/checkOut
        final checkInRaw = record['checkInTime'] ?? record['checkIn'];
        final checkOutRaw = record['checkOutTime'] ?? record['checkOut'];
        final dateString = record['date'] as String?;

        // Backend sends time strings (HH:mm) that need to be combined with the date
        final checkIn = checkInRaw != null
            ? TimeUtils.formatTimeWithSmartTimezone(
                TimeUtils.parseTimeWithDate(
                      checkInRaw.toString(),
                      dateString,
                    ) ??
                    DateTime.now(),
                user: user,
                company: company,
              )
            : 'N/A';
        final checkOut = checkOutRaw != null
            ? TimeUtils.formatTimeWithSmartTimezone(
                TimeUtils.parseTimeWithDate(
                      checkOutRaw.toString(),
                      dateString,
                    ) ??
                    DateTime.now(),
                user: user,
                company: company,
              )
            : 'N/A';
        final date = record['date'] != null
            ? TimeUtils.formatDate(DateTime.parse(record['date']))
            : 'N/A';
        final status = record['status'] ?? 'Unknown';
        final hoursWorked = record['hoursWorked']?.toString() ?? 'N/A';
        final location = record['location'] ?? 'N/A';
        final notes = record['notes'] ?? '';

        csvData.add([
          date,
          checkIn,
          checkOut,
          status,
          hoursWorked,
          location,
          notes,
        ]);
      }

      // Convert to CSV string
      final csvText = const ListToCsvConverter().convert(csvData);

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/attendance_export.csv');
      await file.writeAsString(csvText);

      // Use share intent to let user choose where to save
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Export - ${TimeUtils.formatDate(DateTime.now())}',
        subject: 'SNS Attendance Export',
      );

      GlobalNotificationService().showSuccess(
        'Share dialog opened for attendance export',
      );
    } catch (e) {
      GlobalNotificationService().showError(
        'Error exporting attendance data: $e',
      );
    }
  }
}
