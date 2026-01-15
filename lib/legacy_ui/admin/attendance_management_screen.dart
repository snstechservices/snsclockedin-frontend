import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../widgets/shared_app_bar.dart';
// Coach features disabled for this company
// import 'attendance_management_with_coach.dart';
import '../../providers/admin_attendance_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/theme_utils.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedEmployeeId;
  bool _isFiltering = false;
  bool _isFiltersMinimized = true; // Default to minimized
  final int _pageSize = 10;

  // Helper for today - using company timezone
  DateTimeRange get _todayRange {
    Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final company = companyProvider.currentCompany?.toJson();
    final now = TimeUtils.convertToEffectiveTimezone(
      DateTime.now(),
      null,
      company,
    );
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  // Helper for yesterday - using company timezone
  DateTimeRange get _yesterdayRange {
    Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final company = companyProvider.currentCompany?.toJson();
    final now = TimeUtils.convertToEffectiveTimezone(
      DateTime.now(),
      null,
      company,
    );
    final yesterday = now.subtract(const Duration(days: 1));
    return DateTimeRange(
      start: DateTime(yesterday.year, yesterday.month, yesterday.day),
      end: DateTime(yesterday.year, yesterday.month, yesterday.day),
    );
  }

  // Helper for this week (Mon-Sun) - using company timezone
  DateTimeRange get _thisWeekRange {
    Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final company = companyProvider.currentCompany?.toJson();
    final now = TimeUtils.convertToEffectiveTimezone(
      DateTime.now(),
      null,
      company,
    );
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = null;
    // Set default to today
    _startDate = _todayRange.start;
    _endDate = _todayRange.end;
    // Fetch all attendance records when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchAttendancePage(1);
      if (!mounted) return;
      Provider.of<EmployeeProvider>(context, listen: false).getEmployees();
    });
  }

  Future<void> _fetchAttendancePage(int page) async {
    setState(() => _isFiltering = true);
    final provider = Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    );

    await provider.fetchAttendanceLegacy(
      start: _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null,
      end: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      userId: _selectedEmployeeId,
      page: page,
      limit: _pageSize,
      role: 'all',
    );

    setState(() => _isFiltering = false);
  }

  void _setQuickRange(DateTimeRange range) {
    setState(() {
      _startDate = range.start;
      _endDate = range.end;
    });
    _fetchAttendancePage(1);
  }

  // Export attendance records with enhanced functionality
  // Export functionality removed - consolidated into Analytics & Reports

  // Export functionality removed - consolidated into Analytics & Reports
  /*
    try {
      final exportService = ExportService();
      
      // Prepare data for export
      final exportData = records.map((record) {
        // Handle different user object structures
        String employeeName = 'Unknown';
        String email = 'Unknown';
        
        if (record.user != null) {
          if (record.user is Map<String, dynamic>) {
            // User is a Map
            final userMap = record.user as Map<String, dynamic>;
            employeeName = userMap['name'] ?? userMap['firstName'] ?? userMap['employeeName'] ?? 'Unknown';
            email = userMap['email'] ?? 'Unknown';
          } else {
            // User is an object with properties
            try {
              employeeName = record.user.name ?? record.user.employeeName ?? 'Unknown';
              email = record.user.email ?? 'Unknown';
            } catch (e) {
              // Fallback to Map access
              try {
                final userMap = record.user as Map<String, dynamic>;
                employeeName = userMap['name'] ?? userMap['firstName'] ?? userMap['employeeName'] ?? 'Unknown';
                email = userMap['email'] ?? 'Unknown';
              } catch (e) {
                employeeName = 'Unknown';
                email = 'Unknown';
              }
            }
          }
        }
        
        return {
          'Employee Name': employeeName,
          'Email': email,
          'Date': _formatDate(record.date),
          'Status': record.statusText ?? 'Unknown',
          'Clock In': _formatTime(record.checkInTime, context),
          'Clock Out': _formatTime(record.checkOutTime, context),
          'Break Duration': _formatMinutesToHourMin(record.totalBreakDuration),
          'Total Hours': _formatMinutesToHourMin(record.totalWorkDuration?.inMinutes),
        };
      }).toList();

      // Generate export content
      String exportContent;
      List<String> headers;
      
      switch (format) {
        case ExportFormat.csv:
          headers = ['Employee Name', 'Email', 'Date', 'Status', 'Clock In', 'Clock Out', 'Break Duration', 'Total Hours'];
          exportContent = exportService.generateCSV(data: exportData, headers: headers);
          break;
        case ExportFormat.json:
          exportContent = exportService.generateJSON(data: exportData);
          break;
        case ExportFormat.txt:
          headers = ['Employee Name', 'Email', 'Date', 'Status', 'Clock In', 'Clock Out', 'Break Duration', 'Total Hours'];
          exportContent = exportService.generateText(data: exportData, headers: headers);
          break;
      }

      // Save file to device
      final filePath = await exportService.saveExportToFile(
        data: exportContent,
        format: format,
        filename: 'attendance_records',
      );

      // Show export success dialog with file details
      await exportService.showExportSuccessDialog(
        context: context,
        title: 'Attendance Records Exported',
        data: exportContent,
        format: format,
        filePath: filePath,
      );
      
    } catch (e) {
      if (context.mounted) {
        GlobalNotificationService().showError('Export failed: $e');
      }
    }
  }
  */

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTime(DateTime? time, BuildContext context) {
    if (time == null) return 'N/A';

    try {
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
    } catch (e) {
      // Fallback to simple time formatting if timezone conversion fails
      // Still try to use TimeUtils with fallback
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final companyProvider = Provider.of<CompanyProvider>(
          context,
          listen: false,
        );
        final user = authProvider.user;
        final company = companyProvider.currentCompany?.toJson();
        return TimeUtils.formatTimeOnly(time, user: user, company: company);
      } catch (_) {
        return DateFormat('HH:mm').format(time);
      }
    }
  }

  String _formatMillisecondsToHourMin(int? milliseconds) {
    if (milliseconds == null) return 'N/A';
    final totalMinutes = milliseconds ~/ (1000 * 60);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${mins}m';
  }

  Widget _statusBadge(String status) {
    final theme = Theme.of(context);
    Color color;
    switch (status.toLowerCase()) {
      case 'present':
        color = ThemeUtils.getStatusChipColor('success', theme);
        break;
      case 'on break':
        color = ThemeUtils.getStatusChipColor('warning', theme);
        break;
      case 'clocked in':
        color = ThemeUtils.getSafeHeaderColor(theme);
        break;
      case 'absent':
        color = ThemeUtils.getStatusChipColor('error', theme);
        break;
      case 'leave (unpaid leave)':
      case 'leave (casual leave)':
      case 'leave (annual leave)':
      case 'leave (sick leave)':
      case 'leave (maternity leave)':
      case 'leave (paternity leave)':
      case 'leave (emergency leave)':
        color = ThemeUtils.getStatusChipColor('warning', theme);
        break;
      case 'holiday':
        {
          final chartColors = ThemeUtils.getSafeChartColors(theme);
          color = chartColors[4]; // Purple from safe chart colors
          break;
        }
      case 'no records':
        color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
        break;
      default:
        color = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCompactQuickDateButton(
    String label,
    VoidCallback onPressed,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? ThemeUtils.getSafeHeaderColor(theme)
            : theme.colorScheme.surface,
        foregroundColor: isSelected
            ? ThemeUtils.getAutoTextColor(ThemeUtils.getSafeHeaderColor(theme))
            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedEmployeeId,
        decoration: InputDecoration(
          labelText: 'Employee',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXs,
            vertical: AppTheme.spacingXs,
          ),
          isDense: true,
          labelStyle: const TextStyle(fontSize: 12),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('All Employees', style: TextStyle(fontSize: 12)),
          ),
          ...employeeProvider.employees.map((employee) {
            return DropdownMenuItem(
              value: employee.userId,
              child: Text(
                '${employee.firstName} ${employee.lastName}'.trim(),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedEmployeeId = value;
          });
          _fetchAttendancePage(1);
        },
        menuMaxHeight: 150,
        icon: const Icon(Icons.arrow_drop_down, size: 16),
        // Coach features disabled for this company
        // key: AttendanceManagementWithCoach.employeeFilterKey,
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: AppTheme.elevationHigh,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.muted,
              ),
            ),
            SizedBox(height: AppTheme.spacingXs),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            'No attendance records found.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(List<dynamic> attendanceRecords) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchAttendancePage(1);
      },
      child: ListView.builder(
        padding: EdgeInsets.all(AppTheme.spacingL),
        itemCount: attendanceRecords.length,
        itemBuilder: (context, index) {
          final record = attendanceRecords[index];
          final user = record.user;

          // Fix: Handle user as Map<String, dynamic> instead of object
          String employeeName = 'Unknown Employee';
          String employeeEmail = 'No email';

          if (user != null) {
            if (user is Map<String, dynamic>) {
              // Handle as Map
              final firstName = user['firstName'] ?? '';
              final lastName = user['lastName'] ?? '';
              employeeName = '$firstName $lastName'.trim();
              employeeEmail = user['email'] ?? 'No email';
            } else {
              // Handle as object (fallback)
              employeeName = '${user.firstName ?? ''} ${user.lastName ?? ''}'
                  .trim();
              employeeEmail = user.email ?? 'No email';
            }
          }

          return Card(
            elevation: AppTheme.elevationMedium,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            margin: EdgeInsets.only(bottom: AppTheme.spacingM),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with employee info and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employeeName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    employeeEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(record.statusText ?? 'Present'),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingL),

                  // Date and times
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.muted,
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Date: ${_formatDate(record.date ?? DateTime.now())}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingS),

                  Row(
                    children: [
                      Icon(Icons.login, size: 16, color: AppTheme.muted),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Check-in: ${_formatTime(record.checkInTime, context)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(width: AppTheme.spacingL),
                      Icon(Icons.logout, size: 16, color: AppTheme.muted),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Check-out: ${_formatTime(record.checkOutTime, context)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingS),

                  // Break time
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppTheme.muted),
                      SizedBox(width: AppTheme.spacingS),
                      const Text(
                        'Total Break Time: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatMillisecondsToHourMin(record.totalBreakDuration),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),

                  // Breaks list if any
                  if (record.breaks != null && record.breaks.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Breaks:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.muted,
                      ),
                    ),
                    ...record.breaks.map<Widget>((breakItem) {
                      final start = breakItem['start'] != null
                          ? DateTime.tryParse(breakItem['start'].toString())
                          : null;
                      final end = breakItem['end'] != null
                          ? DateTime.tryParse(breakItem['end'].toString())
                          : null;

                      // Debug: Print break data to console
                      // 'DEBUG: Break item data: $breakItem');
                      // 'DEBUG: Start: $start, End: $end');

                      String duration = '-';
                      if (start != null && end != null) {
                        final d = end.difference(start);
                        duration = '${d.inHours}h ${d.inMinutes % 60}m';
                        // 'DEBUG: Duration: $duration');
                      }
                      return Padding(
                        padding: EdgeInsets.only(
                          left: AppTheme.spacingL,
                          top: AppTheme.spacingXs,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pause, size: 14, color: AppTheme.muted),
                            SizedBox(width: AppTheme.spacingXs),
                            Text(
                              '${_formatTime(start, context)} - ${_formatTime(end, context)} ($duration)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SharedAppBar(
        title: 'Attendance Records',
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/attendance_management'),
      body: Consumer<AdminAttendanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final attendanceRecords = provider.attendanceRecords;

          // Calculate stats
          final totalRecords = attendanceRecords.length;
          final presentCount = attendanceRecords
              .where((record) => record.statusText.toLowerCase() == 'present')
              .length;
          final onBreakCount = attendanceRecords
              .where(
                (record) => record.breakStatus?.toLowerCase() == 'on break',
              )
              .length;

          return Column(
            children: [
              // Quick Stats Section
              Container(
                padding: EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.muted.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Records',
                        totalRecords.toString(),
                        AppTheme.primary,
                        Icons.assessment,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildStatCard(
                        'Present',
                        presentCount.toString(),
                        AppTheme.success,
                        Icons.check_circle,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: _buildStatCard(
                        'On Break',
                        onBreakCount.toString(),
                        AppTheme.warning,
                        Icons.pause_circle,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Section - Responsive Design
              Container(
                margin: EdgeInsets.all(AppTheme.spacingL),
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.muted.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 18,
                              color: AppTheme.muted,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.muted,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isFiltersMinimized = !_isFiltersMinimized;
                                });
                              },
                              icon: Icon(
                                _isFiltersMinimized
                                    ? Icons.expand_more
                                    : Icons.expand_less,
                                size: 20,
                                color: AppTheme.muted,
                              ),
                              tooltip: _isFiltersMinimized
                                  ? 'Expand Filters'
                                  : 'Minimize Filters',
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spacingM),

                        // Show filters only when not minimized
                        if (!_isFiltersMinimized) ...[
                          // Simple date filter buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactQuickDateButton(
                                  'Today',
                                  () => _setQuickRange(_todayRange),
                                  _startDate != null &&
                                      _endDate != null &&
                                      _startDate!.day ==
                                          _todayRange.start.day &&
                                      _startDate!.month ==
                                          _todayRange.start.month &&
                                      _startDate!.year ==
                                          _todayRange.start.year &&
                                      _endDate!.day == _todayRange.end.day &&
                                      _endDate!.month ==
                                          _todayRange.end.month &&
                                      _endDate!.year == _todayRange.end.year,
                                ),
                              ),
                              SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: _buildCompactQuickDateButton(
                                  'Yesterday',
                                  () => _setQuickRange(_yesterdayRange),
                                  _startDate != null &&
                                      _endDate != null &&
                                      _startDate!.day ==
                                          _yesterdayRange.start.day &&
                                      _startDate!.month ==
                                          _yesterdayRange.start.month &&
                                      _startDate!.year ==
                                          _yesterdayRange.start.year &&
                                      _endDate!.day ==
                                          _yesterdayRange.end.day &&
                                      _endDate!.month ==
                                          _yesterdayRange.end.month &&
                                      _endDate!.year ==
                                          _yesterdayRange.end.year,
                                ),
                              ),
                              SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: _buildCompactQuickDateButton(
                                  'This Week',
                                  () => _setQuickRange(_thisWeekRange),
                                  _startDate != null &&
                                      _endDate != null &&
                                      _startDate!.day ==
                                          _thisWeekRange.start.day &&
                                      _startDate!.month ==
                                          _thisWeekRange.start.month &&
                                      _startDate!.year ==
                                          _thisWeekRange.start.year &&
                                      _endDate!.day == _thisWeekRange.end.day &&
                                      _endDate!.month ==
                                          _thisWeekRange.end.month &&
                                      _endDate!.year == _thisWeekRange.end.year,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: AppTheme.spacingM),

                          // Employee filter
                          _buildEmployeeDropdown(),

                          SizedBox(height: AppTheme.spacingM),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isFiltering
                                      ? null
                                      : () {
                                          setState(() {
                                            _startDate = _todayRange.start;
                                            _endDate = _todayRange.end;
                                            _selectedEmployeeId = null;
                                          });
                                          _fetchAttendancePage(1);
                                        },
                                  icon: const Icon(Icons.clear, size: 18),
                                  label: const Text('Clear'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.muted,
                                    side: BorderSide(
                                      color: AppTheme.muted.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppTheme.spacingM,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              // Content Section
              Expanded(
                child: attendanceRecords.isEmpty
                    ? _buildEmptyState()
                    : _buildAttendanceList(attendanceRecords),
              ),
            ],
          );
        },
      ),
    );
  }
}
