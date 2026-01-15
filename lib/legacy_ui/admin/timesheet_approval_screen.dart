import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../utils/time_utils.dart';
import '../../services/global_notification_service.dart';
import '../../core/repository/attendance_repository.dart';
import '../../services/connectivity_service.dart';
import '../../core/services/hive_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/logger.dart';

class TimesheetApprovalScreen extends StatefulWidget {
  const TimesheetApprovalScreen({super.key});

  @override
  State<TimesheetApprovalScreen> createState() =>
      _TimesheetApprovalScreenState();
}

class _TimesheetApprovalScreenState extends State<TimesheetApprovalScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingTimesheets = [];
  List<Map<String, dynamic>> _approvedTimesheets = [];
  bool _isLoadingPending = true;
  bool _isLoadingApproved = true;
  String? _error;
  bool _autoAcceptEnabled = false;
  late TabController _tabController;
  bool _isAutoApproving = false;
  late AttendanceRepository _attendanceRepository;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // Changed from 2 to 3 tabs
    _initializeRepository();
    _fetchPendingTimesheets();
    _fetchApprovedTimesheets();
    _loadAutoAcceptStatus();
  }

  void _initializeRepository() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _attendanceRepository = AttendanceRepository(
      connectivityService: ConnectivityService(),
      hiveService: HiveService(),
      apiService: ApiService(baseUrl: ApiConfig.baseUrl),
      authProvider: authProvider,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to format time with timezone
  String _formatTime(String? timeString) {
    if (timeString == null) return 'N/A';
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();
      final time = DateTime.parse(timeString);
      return TimeUtils.formatTimeOnly(time, user: user, company: company);
    } catch (e) {
      return 'N/A';
    }
  }

  // Helper method to format date with timezone
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final company = companyProvider.currentCompany?.toJson();
      final date = DateTime.parse(dateString);
      final companyDate = TimeUtils.convertToEffectiveTimezone(
        date,
        null,
        company,
      );
      return TimeUtils.formatReadableDate(
        companyDate,
        user: null,
        company: company,
      );
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _fetchPendingTimesheets({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingPending = true;
      _error = null;
    });

    try {
      final pendingTimesheets = await _attendanceRepository
          .getPendingTimesheets(forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _pendingTimesheets = pendingTimesheets;
          _isLoadingPending = false;
        });

        if (_autoAcceptEnabled &&
            pendingTimesheets.isNotEmpty &&
            !_isAutoApproving) {
          _autoApproveAllPending();
        }
      }
    } catch (e) {
      Logger.error(
        'TimesheetApprovalScreen: Failed to fetch pending timesheets: $e',
      );
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingPending = false;
        });
      }
    }
  }

  Future<void> _fetchApprovedTimesheets({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingApproved = true;
      _error = null;
    });

    try {
      final approvedTimesheets = await _attendanceRepository
          .getApprovedTimesheets(forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _approvedTimesheets = approvedTimesheets;
          _isLoadingApproved = false;
        });
      }
    } catch (e) {
      Logger.error(
        'TimesheetApprovalScreen: Failed to fetch approved timesheets: $e',
      );
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingApproved = false;
        });
      }
    }
  }

  Future<void> _loadAutoAcceptStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoAcceptEnabled = prefs.getBool('autoAcceptEnabled') ?? false;

      setState(() {
        _autoAcceptEnabled = autoAcceptEnabled;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleAutoAccept(bool value) async {
    setState(() {
      _autoAcceptEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoAcceptEnabled', value);

      if (value) {
        await _autoApproveAllPending();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _autoApproveAllPending() async {
    if (_isAutoApproving) return;

    setState(() {
      _isAutoApproving = true;
    });

    try {
      final result = await _attendanceRepository.bulkAutoApproveTimesheets();
      final approvedCount = result['approvedCount'] ?? 0;

      if (approvedCount > 0 && mounted) {
        GlobalNotificationService().showSuccess(
          'Auto-approved $approvedCount timesheets',
        );
        // Refresh the lists
        await _fetchPendingTimesheets(forceRefresh: true);
        await _fetchApprovedTimesheets(forceRefresh: true);
      }
    } catch (e) {
      Logger.error(
        'TimesheetApprovalScreen: Failed to auto-approve timesheets: $e',
      );
      if (mounted) {
        GlobalNotificationService().showError(
          'Error auto-approving timesheets: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAutoApproving = false;
        });
      }
    }
  }

  Future<void> _approveTimesheet(String attendanceId) async {
    try {
      await _attendanceRepository.approveTimesheet(attendanceId);

      if (mounted) {
        GlobalNotificationService().showSuccess(
          'Timesheet approved successfully',
        );
        await _fetchPendingTimesheets(forceRefresh: true);
        await _fetchApprovedTimesheets(forceRefresh: true);
      }
    } catch (e) {
      Logger.error('TimesheetApprovalScreen: Failed to approve timesheet: $e');
      if (mounted) {
        GlobalNotificationService().showError('Error approving timesheet: $e');
      }
    }
  }

  Future<void> _rejectTimesheet(String attendanceId, String reason) async {
    try {
      await _attendanceRepository.rejectTimesheet(attendanceId, reason: reason);

      if (mounted) {
        GlobalNotificationService().showSuccess(
          'Timesheet rejected successfully',
        );
        await _fetchPendingTimesheets(forceRefresh: true);
        await _fetchApprovedTimesheets(forceRefresh: true);
      }
    } catch (e) {
      Logger.error('TimesheetApprovalScreen: Failed to reject timesheet: $e');
      if (mounted) {
        GlobalNotificationService().showError('Error rejecting timesheet: $e');
      }
    }
  }

  void _showRejectDialog(String attendanceId, String employeeName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Timesheet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject timesheet for $employeeName?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                GlobalNotificationService().showWarning(
                  'Please provide a reason for rejection',
                );
                return;
              }
              Navigator.of(context).pop();
              _rejectTimesheet(attendanceId, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatBreakDuration(dynamic duration) {
    if (duration == null) return 'N/A';

    // Convert to int and validate
    int? milliseconds;
    if (duration is int) {
      milliseconds = duration;
    } else if (duration is String) {
      milliseconds = int.tryParse(duration);
    }

    if (milliseconds == null || milliseconds <= 0) return 'N/A';

    // If duration is unreasonably large (more than 24 hours), show as invalid
    if (milliseconds > 86400000) {
      // 24 hours * 60 minutes * 60 seconds * 1000 ms
      return 'Invalid Data';
    }

    // Convert milliseconds to minutes
    final minutes = (milliseconds / (1000 * 60)).round();

    // Format as hours and minutes if over 60 minutes
    if (minutes >= 60) {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} $remainingMinutes min';
      }
    }

    return '$minutes minutes';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet Approvals'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/timesheet_approvals'),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchPendingTimesheets(forceRefresh: true);
          await _fetchApprovedTimesheets(forceRefresh: true);
        },
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pending Approvals'),
                  Tab(text: 'Approved Timesheets'),
                  Tab(text: 'All Pending'), // Added new tab
                ],
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                indicatorColor: theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pending Approvals
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Auto-Accept Timesheets',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            Switch(
                              value: _autoAcceptEnabled,
                              onChanged: _toggleAutoAccept,
                              activeThumbColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoadingPending
                            ? const Center(child: CircularProgressIndicator())
                            : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Error: $_error'),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _fetchPendingTimesheets,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _pendingTimesheets.isEmpty
                            ? const Center(child: Text('No pending timesheets'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _pendingTimesheets.length,
                                itemBuilder: (context, index) {
                                  final timesheet = _pendingTimesheets[index];
                                  final user =
                                      timesheet['user']
                                          as Map<String, dynamic>?;
                                  final userName = user != null
                                      ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                            .trim()
                                      : 'Unknown User';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header row with name and status
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    if (timesheet['date'] !=
                                                        null)
                                                      Text(
                                                        'Date: ${_formatDate(timesheet['date'])}',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Pending',
                                                  style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),

                                          // Timesheet details - Show available data
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey[200]!,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Clock in/out times
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.login,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .grey[600],
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  'Clock In',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color: Colors
                                                                            .grey[700],
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            if (timesheet['checkInTime'] !=
                                                                null)
                                                              Text(
                                                                _formatTime(
                                                                  timesheet['checkInTime'],
                                                                ),
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              )
                                                            else
                                                              Text(
                                                                'N/A',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .end,
                                                              children: [
                                                                Text(
                                                                  'Clock Out',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color: Colors
                                                                            .grey[700],
                                                                      ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Icon(
                                                                  Icons.logout,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .grey[600],
                                                                ),
                                                              ],
                                                            ),
                                                            if (timesheet['checkOutTime'] !=
                                                                null)
                                                              Text(
                                                                _formatTime(
                                                                  timesheet['checkOutTime'],
                                                                ),
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              )
                                                            else
                                                              Text(
                                                                'N/A',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Break information (using correct field name)
                                                if (timesheet['totalBreakDuration'] !=
                                                        null &&
                                                    timesheet['totalBreakDuration'] >
                                                        0)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.coffee,
                                                          size: 16,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Total Break Time',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                          .grey[700],
                                                                    ),
                                                              ),
                                                              Text(
                                                                _formatBreakDuration(
                                                                  timesheet['totalBreakDuration'],
                                                                ),
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Break details if available
                                                if (timesheet['breaks'] !=
                                                        null &&
                                                    (timesheet['breaks']
                                                            as List)
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.timer,
                                                              size: 16,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              'Break Details (${(timesheet['breaks'] as List).length} breaks):',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .grey[700],
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        ...(timesheet['breaks']
                                                                as List)
                                                            .asMap()
                                                            .entries
                                                            .map((entry) {
                                                              final index =
                                                                  entry.key;
                                                              final breakItem =
                                                                  entry.value;
                                                              if (breakItem
                                                                  is Map<
                                                                    String,
                                                                    dynamic
                                                                  >) {
                                                                return Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        left:
                                                                            24,
                                                                        top: 2,
                                                                      ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        'Break ${index + 1}:',
                                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color:
                                                                              Colors.grey[700],
                                                                        ),
                                                                      ),
                                                                      if (breakItem['startTime'] !=
                                                                          null)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                16,
                                                                            top:
                                                                                2,
                                                                          ),
                                                                          child: Text(
                                                                            'Start: ${_formatTime(breakItem['startTime'])}',
                                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                                              color: Colors.grey[600],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      if (breakItem['endTime'] !=
                                                                          null)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                16,
                                                                            top:
                                                                                2,
                                                                          ),
                                                                          child: Text(
                                                                            'End: ${_formatTime(breakItem['endTime'])}',
                                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                                              color: Colors.grey[600],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      if (breakItem['duration'] !=
                                                                          null)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                16,
                                                                            top:
                                                                                2,
                                                                          ),
                                                                          child: Text(
                                                                            'Duration: ${_formatBreakDuration(breakItem['duration'])}',
                                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                                              color: Colors.grey[600],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }
                                                              return const SizedBox.shrink();
                                                            }),
                                                      ],
                                                    ),
                                                  ),

                                                // Status information
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.info_outline,
                                                        size: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Status',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .grey[700],
                                                                  ),
                                                            ),
                                                            Text(
                                                              timesheet['status'] ??
                                                                  'Unknown',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        timesheet['status'] ==
                                                                            'pending'
                                                                        ? Colors
                                                                              .orange
                                                                        : Colors
                                                                              .grey[700],
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Location validation
                                                if (timesheet['locationValidation'] !=
                                                    null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.location_on,
                                                          size: 16,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Location Validation',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                          .grey[700],
                                                                    ),
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    timesheet['locationValidation']['isValid'] ==
                                                                            true
                                                                        ? Icons
                                                                              .check_circle
                                                                        : Icons
                                                                              .cancel,
                                                                    size: 16,
                                                                    color:
                                                                        timesheet['locationValidation']['isValid'] ==
                                                                            true
                                                                        ? Colors
                                                                              .green
                                                                        : Colors
                                                                              .red,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    timesheet['locationValidation']['isValid'] ==
                                                                            true
                                                                        ? 'Valid Location'
                                                                        : 'Invalid Location',
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodySmall
                                                                        ?.copyWith(
                                                                          color:
                                                                              timesheet['locationValidation']['isValid'] ==
                                                                                  true
                                                                              ? Colors.green
                                                                              : Colors.red,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // Action buttons
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _approveTimesheet(
                                                        timesheet['_id'],
                                                      ),
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                  ),
                                                  label: const Text(
                                                    'Approve',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _showRejectDialog(
                                                        timesheet['_id'],
                                                        userName,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                  ),
                                                  label: const Text(
                                                    'Reject',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  // Tab 2: Approved Timesheets
                  _isLoadingApproved
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text('Error: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  _fetchPendingTimesheets();
                                  _fetchApprovedTimesheets();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _approvedTimesheets.isEmpty
                      ? const Center(child: Text('No approved timesheets'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _approvedTimesheets.length,
                          itemBuilder: (context, index) {
                            final timesheet = _approvedTimesheets[index];
                            final user =
                                timesheet['user'] as Map<String, dynamic>?;
                            final userName = user != null
                                ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                      .trim()
                                : 'Unknown User';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row with name and status
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              if (timesheet['date'] != null)
                                                Text(
                                                  'Date: ${_formatDate(timesheet['date'])}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.green,
                                            ),
                                          ),
                                          child: Text(
                                            'Approved',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Timesheet details
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          // Clock in/out times
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.login,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'Clock In',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (timesheet['checkInTime'] !=
                                                          null)
                                                        Text(
                                                          _formatTime(
                                                            timesheet['checkInTime'],
                                                          ),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      else
                                                        Text(
                                                          'N/A',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            'Clock Out',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Icon(
                                                            Icons.logout,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ],
                                                      ),
                                                      if (timesheet['checkOutTime'] !=
                                                          null)
                                                        Text(
                                                          _formatTime(
                                                            timesheet['checkOutTime'],
                                                          ),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      else
                                                        Text(
                                                          'N/A',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Break information (using correct field name)
                                          if (timesheet['totalBreakDuration'] !=
                                                  null &&
                                              timesheet['totalBreakDuration'] >
                                                  0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.coffee,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Total Break Time',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                        ),
                                                        Text(
                                                          _formatBreakDuration(
                                                            timesheet['totalBreakDuration'],
                                                          ),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Break details if available
                                          if (timesheet['breaks'] != null &&
                                              (timesheet['breaks'] as List)
                                                  .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.timer,
                                                        size: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Break Details (${(timesheet['breaks'] as List).length} breaks):',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .grey[700],
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ...(timesheet['breaks'] as List).asMap().entries.map((
                                                    entry,
                                                  ) {
                                                    final index = entry.key;
                                                    final breakItem =
                                                        entry.value;
                                                    if (breakItem
                                                        is Map<
                                                          String,
                                                          dynamic
                                                        >) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 24,
                                                              top: 2,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Break ${index + 1}:',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .grey[700],
                                                                  ),
                                                            ),
                                                            if (breakItem['startTime'] !=
                                                                null)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 16,
                                                                      top: 2,
                                                                    ),
                                                                child: Text(
                                                                  'Start: ${_formatTime(breakItem['startTime'])}',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600],
                                                                      ),
                                                                ),
                                                              ),
                                                            if (breakItem['endTime'] !=
                                                                null)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 16,
                                                                      top: 2,
                                                                    ),
                                                                child: Text(
                                                                  'End: ${_formatTime(breakItem['endTime'])}',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600],
                                                                      ),
                                                                ),
                                                              ),
                                                            if (breakItem['duration'] !=
                                                                null)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 16,
                                                                      top: 2,
                                                                    ),
                                                                child: Text(
                                                                  'Duration: ${_formatBreakDuration(breakItem['duration'])}',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600],
                                                                      ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  }),
                                                ],
                                              ),
                                            ),

                                          // Status information
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Status',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .grey[700],
                                                            ),
                                                      ),
                                                      Text(
                                                        timesheet['status'] ??
                                                            'Unknown',
                                                        style: theme
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  timesheet['status'] ==
                                                                      'approved'
                                                                  ? Colors.green
                                                                  : Colors
                                                                        .grey[700],
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Location validation
                                          if (timesheet['locationValidation'] !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Location Validation',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              timesheet['locationValidation']['isValid'] ==
                                                                      true
                                                                  ? Icons
                                                                        .check_circle
                                                                  : Icons
                                                                        .cancel,
                                                              size: 16,
                                                              color:
                                                                  timesheet['locationValidation']['isValid'] ==
                                                                      true
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              timesheet['locationValidation']['isValid'] ==
                                                                      true
                                                                  ? 'Valid Location'
                                                                  : 'Invalid Location',
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: Colors
                                                                        .grey[700],
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  // Tab 3: All Pending Timesheets (for monitoring)
                  _isLoadingPending
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text('Error: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  _fetchPendingTimesheets();
                                  _fetchApprovedTimesheets();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _pendingTimesheets.isEmpty
                      ? const Center(child: Text('No pending timesheets'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pendingTimesheets.length,
                          itemBuilder: (context, index) {
                            final timesheet = _pendingTimesheets[index];
                            final user =
                                timesheet['user'] as Map<String, dynamic>?;
                            final userName = user != null
                                ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                      .trim()
                                : 'Unknown User';
                            final hasClockOut =
                                timesheet['checkOutTime'] != null;
                            final isReadyForApproval = hasClockOut;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row with name and status
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              if (timesheet['date'] != null)
                                                Text(
                                                  'Date: ${_formatDate(timesheet['date'])}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isReadyForApproval
                                                ? Colors.orange.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: isReadyForApproval
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                          ),
                                          child: Text(
                                            isReadyForApproval
                                                ? 'Ready for Approval'
                                                : 'Waiting for Clock Out',
                                            style: TextStyle(
                                              color: isReadyForApproval
                                                  ? Colors.orange[700]
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Clock in/out status
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Clock in/out times
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.login,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'Clock In',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (timesheet['checkInTime'] !=
                                                          null)
                                                        Text(
                                                          _formatTime(
                                                            timesheet['checkInTime'],
                                                          ),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      else
                                                        Text(
                                                          'N/A',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            'Clock Out',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Icon(
                                                            Icons.logout,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ],
                                                      ),
                                                      if (timesheet['checkOutTime'] !=
                                                          null)
                                                        Text(
                                                          _formatTime(
                                                            timesheet['checkOutTime'],
                                                          ),
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      else
                                                        Text(
                                                          'N/A',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Status message
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 12,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isReadyForApproval
                                                    ? Colors.green.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.blue.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isReadyForApproval
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isReadyForApproval
                                                        ? Icons.check_circle
                                                        : Icons.info,
                                                    size: 16,
                                                    color: isReadyForApproval
                                                        ? Colors.green
                                                        : Colors.blue,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      isReadyForApproval
                                                          ? 'Timesheet is ready for approval - employee has completed their day'
                                                          : 'Waiting for employee to clock out before approval',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                isReadyForApproval
                                                                ? Colors
                                                                      .green[700]
                                                                : Colors
                                                                      .blue[700],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Action buttons (only show for ready timesheets)
                                    if (isReadyForApproval)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _approveTimesheet(
                                                    timesheet['_id'],
                                                  ),
                                              icon: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Approve',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _showRejectDialog(
                                                    timesheet['_id'],
                                                    userName,
                                                  ),
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Reject',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          'Approval actions will be available once employee clocks out',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
