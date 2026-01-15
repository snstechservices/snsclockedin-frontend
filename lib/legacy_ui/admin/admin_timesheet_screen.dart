import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_attendance_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/shared_app_bar.dart';
import 'edit_attendance_dialog.dart';
import 'package:flutter/scheduler.dart';
import '../../models/employee.dart';
import '../../models/attendance.dart';
import '../../utils/admin_leave_restrictions.dart';
import '../../utils/time_utils.dart';

class AdminTimesheetScreen extends StatefulWidget {
  const AdminTimesheetScreen({super.key});

  @override
  State<AdminTimesheetScreen> createState() => _AdminTimesheetScreenState();
}

class _AdminTimesheetScreenState extends State<AdminTimesheetScreen> {
  DateTimeRange? _dateRange;
  String? _selectedEmployeeId;
  List<Employee> _employeeList = [];
  bool isExporting = false;

  bool _isFiltersCollapsed =
      false; // Track whether filters section is collapsed

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );
      await employeeProvider.getEmployees();
      setState(() {
        _employeeList = List<Employee>.from(employeeProvider.employees);
        // Set date range after context is available to ensure timezone calculation works
        _dateRange = _todayRange;
      });
      if (!mounted) return;

      // Get company timezone for debugging

      // Backend stores dates as UTC midnight for the same calendar day
      // We need to send UTC dates that match the calendar day in company timezone
      // Use the original date range directly to avoid timezone conversion issues
      final utcStartDate = DateTime.utc(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final utcEndDate = DateTime.utc(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
      );

      final startDate = DateFormat('yyyy-MM-dd').format(utcStartDate);
      final endDate = DateFormat('yyyy-MM-dd').format(utcEndDate);

      Provider.of<AdminAttendanceProvider>(
        context,
        listen: false,
      ).fetchAttendanceLegacy(
        start: startDate,
        end: endDate,
        userId: _selectedEmployeeId,
        role: 'all',
      );
    });
  }

  void _onEmployeeChanged(String? employeeId) {
    setState(() => _selectedEmployeeId = employeeId);
    // Backend stores dates as UTC midnight for the same calendar day
    // Use the original date range directly to avoid timezone conversion issues
    final utcStartDate = DateTime.utc(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final utcEndDate = DateTime.utc(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
    );

    final startDate = DateFormat('yyyy-MM-dd').format(utcStartDate);
    final endDate = DateFormat('yyyy-MM-dd').format(utcEndDate);

    Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    ).fetchAttendanceLegacy(
      start: startDate,
      end: endDate,
      userId: employeeId,
      role: 'all',
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;
    final company = companyProvider.currentCompany?.toJson();
    return TimeUtils.formatTimeOnly(dt, user: user, company: company);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';

    // Since the date is already in UTC from the backend, format it directly
    // without timezone conversion to maintain consistency
    final formattedDate = DateFormat('yyyy-MM-dd').format(dt);

    return formattedDate;
  }

  String _formatTotalHours(String? inIso, String? outIso, int? breakMs) {
    if (inIso == null || outIso == null) return '0h 0m';
    final inDt = DateTime.tryParse(inIso);
    final outDt = DateTime.tryParse(outIso);
    if (inDt == null || outDt == null) return '0h 0m';
    int total = outDt.difference(inDt).inMilliseconds - (breakMs ?? 0);
    if (total < 0) total = 0;
    final h = total ~/ (1000 * 60 * 60);
    final m = ((total % (1000 * 60 * 60)) / (1000 * 60)).round();
    return '${h}h ${m}m';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.orange;
      case 'late':
        return Colors.amber;
      case 'halfDay':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _toggleFiltersSection() {
    setState(() {
      _isFiltersCollapsed = !_isFiltersCollapsed;
    });
  }

  void _handleEditAttendance(
    BuildContext context,
    Map<String, dynamic> rec,
  ) async {
    final provider = Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditAttendanceDialog(
        initialData: rec,
        onSave: (data) => Navigator.of(context).pop(data),
      ),
    );

    if (updated != null) {
      if (!mounted) return;
      final success = await provider.editAttendance(
        rec['id'] ?? rec['attendanceId'] ?? rec['_id'] ?? '',
        updated,
      );
      if (success) {
        if (!mounted) return;
        // Automatically reset filters to show all records after edit
        setState(() {
          _selectedEmployeeId = null;
          _dateRange = _todayRange;
        });
        _fetchAttendanceData();
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Attendance updated successfully.')),
        );
      } else {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to update attendance.'),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filteredRecords(List<Attendance> records) {
    return records
        .where((Attendance rec) {
          final user = rec.user;
          if (user == null ||
              (user is Map &&
                  (user['firstName'] == null || user['lastName'] == null))) {
            return false;
          }
          if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
            // Use _id for matching
            final userId = user is Map
                ? user['_id']?.toString()
                : user.toString();
            if (userId != _selectedEmployeeId) return false;
          }
          return true;
        })
        .map<Map<String, dynamic>>((Attendance rec) {
          return rec.toJson();
        })
        .toList();
  }

  void _setQuickRange(DateTimeRange range) {
    setState(() => _dateRange = range);

    // Backend stores dates as UTC midnight for the same calendar day
    // Use the original date range directly to avoid timezone conversion issues
    final utcStartDate = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final utcEndDate = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    );

    final startDate = DateFormat('yyyy-MM-dd').format(utcStartDate);
    final endDate = DateFormat('yyyy-MM-dd').format(utcEndDate);

    Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    ).fetchAttendanceLegacy(
      start: startDate,
      end: endDate,
      userId: _selectedEmployeeId,
      role: 'all',
    );
  }

  Future<void> _refreshData() async {
    // Backend stores dates as UTC midnight for the same calendar day
    // Use the original date range directly to avoid timezone conversion issues
    final utcStartDate = DateTime.utc(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final utcEndDate = DateTime.utc(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
    );

    final startDate = DateFormat('yyyy-MM-dd').format(utcStartDate);
    final endDate = DateFormat('yyyy-MM-dd').format(utcEndDate);

    await Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    ).fetchAttendanceLegacy(
      start: startDate,
      end: endDate,
      userId: _selectedEmployeeId,
      role: 'all',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Check if admin is on leave and restrict timesheet management
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    final isOnLeave = attendanceProvider.leaveInfo != null;

    if (isOnLeave) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Timesheet Management'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
        ),
        drawer: const AdminSideNavigation(currentRoute: '/timesheet'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AdminLeaveRestrictions.getRestrictionIcon(
                  'timesheetManagement',
                ),
                size: 64,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 16),
              Text(
                'Timesheet Management Restricted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  AdminLeaveRestrictions.getRestrictionMessage(
                    'timesheetManagement',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: SharedAppBar(
        title: 'Timesheet Management',
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/timesheet'),
      body: Consumer<AdminAttendanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _filteredRecords(provider.attendanceRecords);

          // Calculate stats
          final totalRecords = filtered.length;
          final presentCount = filtered
              .where(
                (rec) =>
                    (rec['status']?.toString().toLowerCase() ?? 'present') ==
                    'present',
              )
              .length;
          final onBreakCount = filtered
              .where(
                (rec) =>
                    (rec['status']?.toString().toLowerCase() ?? '') ==
                    'on break',
              )
              .length;

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: Column(
              children: [
                // Quick Stats Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Records',
                          totalRecords.toString(),
                          Colors.blue,
                          Icons.assessment,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Present',
                          presentCount.toString(),
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'On Break',
                          onBreakCount.toString(),
                          Colors.orange,
                          Icons.pause_circle,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Section - Responsive Design
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
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
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _isFiltersCollapsed
                                      ? Icons.expand_more
                                      : Icons.expand_less,
                                  color: Colors.grey[700],
                                  size: 20,
                                ),
                                onPressed: _toggleFiltersSection,
                                tooltip: _isFiltersCollapsed
                                    ? 'Expand Filters'
                                    : 'Collapse Filters',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Filters content - collapsible
                          if (!_isFiltersCollapsed) ...[
                            // Simple date filter buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactQuickDateButton(
                                    'Today',
                                    () => _setQuickRange(_todayRange),
                                    _dateRange != null &&
                                        _dateRange!.start ==
                                            _todayRange.start &&
                                        _dateRange!.end == _todayRange.end,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCompactQuickDateButton(
                                    'Yesterday',
                                    () => _setQuickRange(_yesterdayRange),
                                    _dateRange != null &&
                                        _dateRange!.start ==
                                            _yesterdayRange.start &&
                                        _dateRange!.end == _yesterdayRange.end,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildCompactQuickDateButton(
                                    'This Week',
                                    () => _setQuickRange(_thisWeekRange),
                                    _dateRange != null &&
                                        _dateRange!.start ==
                                            _thisWeekRange.start &&
                                        _dateRange!.end == _thisWeekRange.end,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Employee filter
                            _buildEmployeeDropdown(),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Content Section
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildAttendanceList(filtered),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _fetchAttendanceData() {
    final provider = Provider.of<AdminAttendanceProvider>(
      context,
      listen: false,
    );
    provider.fetchAttendanceLegacy(
      start: DateFormat('yyyy-MM-dd').format(_dateRange!.start),
      end: DateFormat('yyyy-MM-dd').format(_dateRange!.end),
      userId: _selectedEmployeeId,
      role: 'all',
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(List<Map<String, dynamic>> filtered) {
    final isWide = MediaQuery.of(context).size.width > 700;

    if (!isWide) {
      // Mobile: Card list
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final rec = filtered[index];
          final user = rec['user'];
          final name =
              user != null &&
                  user['firstName'] != null &&
                  user['lastName'] != null
              ? '${user['firstName']} ${user['lastName']}'
              : user != null
              ? user['email']
              : '(Deleted)';

          return _buildAttendanceCard(rec, name);
        },
      );
    }

    // Desktop/tablet: DataTable
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Employee',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Check In',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Check Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Total Hours',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: List<DataRow>.generate(filtered.length, (index) {
          final rec = filtered[index];
          final user = rec['user'];
          final name =
              user != null &&
                  user['firstName'] != null &&
                  user['lastName'] != null
              ? '${user['firstName']} ${user['lastName']}'
              : user != null
              ? user['email']
              : '(Deleted)';
          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              return index % 2 == 0
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.2);
            }),
            cells: [
              DataCell(
                Text(
                  name,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  _formatDate(rec['date']?.toString()),
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  _formatTime(rec['checkInTime']?.toString()),
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  _formatTime(rec['checkOutTime']?.toString()),
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  _formatTotalHours(
                    rec['checkInTime']?.toString(),
                    rec['checkOutTime']?.toString(),
                    rec['totalBreakDuration'],
                  ),
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                Text(
                  rec['status']?.toString() ?? 'present',
                  style: TextStyle(
                    fontSize: 15,
                    color: _statusColor(rec['status']?.toString()),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _handleEditAttendance(context, rec),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> rec, String name) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          Icons.person,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDate(rec['date']?.toString()),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(rec['status']?.toString() ?? 'present'),
              ],
            ),
            const SizedBox(height: 16),

            // Attendance details with icons
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.login, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Check In: ${_formatTime(rec['checkInTime']?.toString())}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Check Out: ${_formatTime(rec['checkOutTime']?.toString())}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Total Hours: ${_formatTotalHours(rec['checkInTime']?.toString(), rec['checkOutTime']?.toString(), rec['totalBreakDuration'])}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),

            // Action button
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _handleEditAttendance(context, rec),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedEmployeeId,
        decoration: InputDecoration(
          labelText: 'Employee',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          isDense: true,
          labelStyle: const TextStyle(fontSize: 12),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('All Employees', style: TextStyle(fontSize: 12)),
          ),
          ..._employeeList.map(
            (emp) => DropdownMenuItem(
              value: emp.userId,
              child: Text(
                '${emp.firstName} ${emp.lastName}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: _onEmployeeChanged,
        menuMaxHeight: 150,
        icon: const Icon(Icons.arrow_drop_down, size: 16),
      ),
    );
  }

  Widget _buildCompactQuickDateButton(
    String label,
    VoidCallback onTap,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'present':
        color = Colors.green;
        break;
      case 'on break':
        color = Colors.orange;
        break;
      case 'clocked in':
        color = Colors.blue;
        break;
      case 'absent':
        color = Colors.red;
        break;
      case 'leave (unpaid leave)':
      case 'leave (casual leave)':
      case 'leave (annual leave)':
      case 'leave (sick leave)':
      case 'leave (maternity leave)':
      case 'leave (paternity leave)':
      case 'leave (emergency leave)':
        color = Colors.orange;
        break;
      case 'holiday':
        color = Colors.purple;
        break;
      case 'no records':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class TimesheetSummary extends StatelessWidget {
  final double totalHours;
  final int presentCount;
  final int absentCount;
  final double overtimeHours;

  const TimesheetSummary({
    super.key,
    required this.totalHours,
    required this.presentCount,
    required this.absentCount,
    required this.overtimeHours,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              'Total Hours',
              '${totalHours.toStringAsFixed(1)}h',
              Icons.timer,
              Colors.blue,
            ),
            _buildStatItem(
              context,
              'Present',
              '$presentCount',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatItem(
              context,
              'Absent',
              '$absentCount',
              Icons.cancel,
              Colors.red,
            ),
            _buildStatItem(
              context,
              'Overtime',
              '${overtimeHours.toStringAsFixed(1)}h',
              Icons.alarm_add,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _LiveBreakTimer extends StatefulWidget {
  final DateTime start;
  const _LiveBreakTimer({required this.start});

  @override
  State<_LiveBreakTimer> createState() => _LiveBreakTimerState();
}

class _LiveBreakTimerState extends State<_LiveBreakTimer> {
  late Duration _elapsed;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.start);
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    setState(() {
      _elapsed = DateTime.now().difference(widget.start);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    return Text(
      h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s',
      style: TextStyle(
        color: Colors.orange[800],
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}
