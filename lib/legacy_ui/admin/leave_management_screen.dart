import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/utils/logger.dart';
import '../../models/leave_balance_record.dart';
import '../../models/leave_accrual_log.dart';
import '../../models/leave_cash_out.dart';
import '../../models/leave_request.dart';
import '../../models/employee.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../providers/leave_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../utils/theme_utils.dart';
import '../../widgets/shared_app_bar.dart';
import '../../services/global_notification_service.dart';
import 'dart:async';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiService _apiService;

  bool _isLoading = false;
  List<LeaveBalanceRecord> _leaveBalanceRecords = [];
  List<LeaveAccrualLog> _accrualLogs = [];
  List<LeaveCashOut> _cashOutAgreements = [];
  List<Employee> _employees = [];
  Map<String, Employee> _employeeMap = {};

  // Filter states
  String _selectedLeaveType = 'all';
  String _selectedEmployee = 'all';
  String _selectedStatus = 'all';
  String _requestStatusFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  // Auto-refresh timer
  Timer? _refreshTimer;

  // Accrual processing state
  bool _isProcessingAccrual = false;

  // Cash-out balance state
  Map<String, dynamic>? _selectedEmployeeBalance;
  bool _isLoadingBalance = false;

  // Track if initial load is complete to prevent reload loop
  bool _initialLoadComplete = false;

  // Company accrual settings for dashboard display
  String? _accrualDailyTime; // HH:mm (24h)
  String? _accrualWeeklyDay; // Sunday..Saturday
  String? _accrualWeeklyTime; // HH:mm (24h)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _apiService = ApiService(baseUrl: ApiConfig.baseUrl);
    _loadData().then((_) {
      // Mark initial load as complete after data is loaded
      if (mounted) {
        setState(() {
          _initialLoadComplete = true;
        });
      }
    });
    _startAutoRefresh();

    // Add listener to load data when tab changes (but not on initial load)
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Only load tab data if initial load is complete and tab change is finished
    if (_initialLoadComplete && !_tabController.indexIsChanging) {
      _loadTabData();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _apiService.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Start auto-refresh timer to update leave requests every 30 seconds
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _initialLoadComplete) {
        // Only refresh if we're on the Leave Requests tab (index 0)
        if (_tabController.index == 0) {
          _refreshLeaveRequests();
        }
      }
    });
  }

  /// Refresh leave requests data (silent background refresh)
  Future<void> _refreshLeaveRequests() async {
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      // Only refresh if not already loading to prevent loops
      if (!leaveProvider.isLoading) {
        await leaveProvider.fetchLeaveRequests(
          includeAdmins: true,
          role: 'all',
        );
      }
    } catch (e) {
      // Silent fail for auto-refresh
      // Error logged silently for background refresh
    }
  }

  // Manual accrual processing
  Future<void> _processAccrualManually() async {
    if (_isProcessingAccrual) return;

    setState(() {
      _isProcessingAccrual = true;
    });

    try {
      // Get today's date for processing
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _apiService.post('/leave/accruals/process-all', {
        'date': dateStr,
        'leaveType': 'Annual Leave',
      });

      if (response.success && response.data != null) {
        final data = response.data;
        final processedEmployees = data['processedEmployees'] ?? 0;
        final totalEmployees = data['totalEmployees'] ?? 0;
        final totalHoursAccrued = data['totalHoursAccrued'] ?? 0.0;

        // Show success message
        if (mounted) {
          GlobalNotificationService().showSuccess(
            'Accrual processed successfully!\n'
            'Processed: $processedEmployees/$totalEmployees employees\n'
            'Total hours accrued: ${totalHoursAccrued.toStringAsFixed(2)}h',
          );
        }

        // Refresh the accrual logs
        await _loadAccrualLogs();
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError('Error processing accrual: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAccrual = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employeesData = await _apiService.getEmployees();
      final balancesData = await _apiService.getLeaveBalances();

      // Load leave requests for admin
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      await leaveProvider.fetchLeaveRequests(includeAdmins: true, role: 'all');

      setState(() {
        _employees = employeesData
            .map((emp) => Employee.fromJson(emp))
            .toList();

        // Parse with error handling to skip invalid records
        _leaveBalanceRecords = balancesData
            .map((bal) {
              try {
                return LeaveBalanceRecord.fromJson(bal);
              } catch (e) {
                if (kDebugMode) {
                  Logger.error('❌ Error parsing balance record: $e');
                  Logger.debug('❌ Record data: $bal');
                }
                return null;
              }
            })
            .whereType<LeaveBalanceRecord>()
            .toList();

        _employeeMap = {for (var emp in _employees) emp.id: emp};
      });
    } catch (e) {
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final notificationService = GlobalNotificationService();
    if (isError) {
      notificationService.showError(message);
    } else {
      notificationService.showSuccess(message);
    }
  }

  Future<void> _loadTabData() async {
    if (_tabController.index == 0) {
      await _loadLeaveRequests();
    } else if (_tabController.index == 2) {
      await _loadAccrualLogs();
    } else if (_tabController.index == 3) {
      await _loadCashOutAgreements();
    }
  }

  Future<void> _loadAccrualLogs() async {
    try {
      // Ensure employees are loaded if not already loaded
      if (_employees.isEmpty) {
        final employeesData = await _apiService.getEmployees();
        setState(() {
          _employees = employeesData
              .map((emp) => Employee.fromJson(emp))
              .toList();
          _employeeMap = {for (var emp in _employees) emp.id: emp};
        });
      }

      // Fetch company accrual settings to display accurate schedule
      try {
        final settings = await _apiService.getCompanyAccrualSettings();
        final Map<String, dynamic> root = settings != null
            ? Map<String, dynamic>.from(settings)
            : {};
        final Map<String, dynamic> leave = root.containsKey('leaveAccrual')
            ? Map<String, dynamic>.from(root['leaveAccrual'] ?? {})
            : root;
        final Map<String, dynamic> daily = Map<String, dynamic>.from(
          leave['daily'] ?? {},
        );
        final Map<String, dynamic> weekly = Map<String, dynamic>.from(
          leave['weeklyReconciliation'] ?? {},
        );
        setState(() {
          _accrualDailyTime = (daily['time'] ?? '03:00') as String;
          _accrualWeeklyDay = (weekly['dayOfWeek'] ?? 'Sunday') as String;
          _accrualWeeklyTime = (weekly['time'] ?? '04:00') as String;
        });
      } catch (_) {
        // ignore settings fetch errors; defaults will be shown
      }

      final logsData = await _apiService.getCompanyAccrualLogs(
        employeeId: _selectedEmployee == 'all' ? null : _selectedEmployee,
        leaveType: _selectedLeaveType == 'all' ? null : _selectedLeaveType,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        // Parse with error handling
        _accrualLogs = logsData
            .map((log) {
              try {
                return LeaveAccrualLog.fromJson(log);
              } catch (e) {
                // Only log errors in debug mode
                if (kDebugMode) {
                  Logger.error('❌ Error parsing accrual log: $e');
                }
                return null;
              }
            })
            .whereType<LeaveAccrualLog>()
            .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        Logger.error('Error loading accrual logs: $e');
      }
    }
  }

  Future<void> _loadCashOutAgreements() async {
    try {
      final agreementsData = await _apiService.getCompanyCashOutAgreements(
        employeeId: _selectedEmployee == 'all' ? null : _selectedEmployee,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      setState(() {
        _cashOutAgreements = agreementsData.map((agreement) {
          try {
            return LeaveCashOut.fromJson(agreement);
          } catch (e) {
            if (kDebugMode) {
              Logger.error('Error parsing cash-out agreement: $e');
              Logger.debug('Problematic agreement data: $agreement');
            }
            // Return a default agreement to prevent crashes
            return LeaveCashOut(
              id: agreement['id']?.toString() ?? 'unknown',
              companyId: agreement['companyId']?.toString() ?? '',
              employeeId: agreement['employeeId']?.toString() ?? '',
              date: DateTime.now(),
              hoursCashedOut: 0.0,
              preBalanceHours: 0.0,
              postBalanceHours: 0.0,
              grossPaid: 0.0,
              loadingPaid: 0.0,
              status: 'error',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        Logger.error('Error loading cash-out agreements: $e');
      }
      setState(() {
        _cashOutAgreements = [];
      });
    }
  }

  Future<void> _loadEmployeeBalance(String employeeId) async {
    try {
      setState(() {
        _isLoadingBalance = true;
      });

      final balance = await _apiService.getLeaveBalance(employeeId);

      // Debug logging to understand the API response structure
      if (kDebugMode) {
        Logger.debug('🔍 Cash-out balance API response: $balance');
        if (balance != null) {
          Logger.debug('🔍 Balance keys: ${balance.keys.toList()}');
          if (balance['balance'] != null) {
            Logger.debug(
              '🔍 Balance.balance keys: ${(balance['balance'] as Map).keys.toList()}',
            );
          }
          if (balance['data'] != null) {
            Logger.debug(
              '🔍 Balance.data keys: ${(balance['data'] as Map).keys.toList()}',
            );
          }
        }
      }

      setState(() {
        _selectedEmployeeBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (e) {
      if (kDebugMode) {
        Logger.error('Error loading employee balance: $e');
      }
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _loadLeaveRequests() async {
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    try {
      await leaveProvider.fetchLeaveRequests(includeAdmins: true, role: 'all');
    } catch (e) {
      if (kDebugMode) {
        Logger.error('Error loading leave requests: $e');
      }
      _showSnackBar('Error loading leave requests: $e', isError: true);
    }
  }

  PreferredSizeWidget _buildTabBar() {
    final theme = Theme.of(context);
    final headerColor = ThemeUtils.getSafeHeaderColor(theme);
    final textColor = ThemeUtils.getAutoTextColor(headerColor);
    return TabBar(
      controller: _tabController,
      indicatorColor: textColor,
      labelColor: textColor,
      unselectedLabelColor: textColor.withValues(alpha: 0.7),
      tabs: const [
        Tab(text: 'Leave Requests', icon: Icon(Icons.approval)),
        Tab(text: 'Balances', icon: Icon(Icons.account_balance_wallet)),
        Tab(text: 'Accrual Logs', icon: Icon(Icons.timeline)),
        Tab(text: 'Cash Out', icon: Icon(Icons.monetization_on)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = ThemeUtils.getSafeHeaderColor(theme);
    final textColor = ThemeUtils.getAutoTextColor(headerColor);

    return Scaffold(
      appBar: SharedAppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        foregroundColor: textColor,
        bottom: _buildTabBar(),
      ),
      drawer: const AdminSideNavigation(currentRoute: '/leave_management'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaveRequestsTab(),
                _buildBalancesTab(),
                _buildAccrualLogsTab(),
                _buildCashOutTab(),
              ],
            ),
    );
  }

  Widget _buildBalancesTab() {
    if (_leaveBalanceRecords.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text('No leave balances found'),
          ],
        ),
      );
    }

    // Group balance records by employee
    final Map<String, List<LeaveBalanceRecord>> groupedBalances = {};
    for (final record in _leaveBalanceRecords) {
      if (!groupedBalances.containsKey(record.employeeId)) {
        groupedBalances[record.employeeId] = [];
      }
      groupedBalances[record.employeeId]!.add(record);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedBalances.length,
        itemBuilder: (context, index) {
          final employeeId = groupedBalances.keys.elementAt(index);
          final employee = _employeeMap[employeeId];
          final records = groupedBalances[employeeId]!;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(
                employee?.firstName != null && employee?.lastName != null
                    ? '${employee!.firstName} ${employee.lastName}'
                    : records.first.employeeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                records.first.employeeEmail,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              children: records
                  .map((record) => _buildLeaveTypeRow(record))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaveTypeRow(LeaveBalanceRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getLeaveTypeColor(
          record.leaveType,
          context,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getLeaveTypeColor(
            record.leaveType,
            context,
          ).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Leave Type Icon and Name
          Builder(
            builder: (context) {
              final leaveTypeColor = _getLeaveTypeColor(
                record.leaveType,
                context,
              );
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: leaveTypeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getLeaveTypeIcon(record.leaveType),
                  size: 20,
                  color: ThemeUtils.getAutoTextColor(leaveTypeColor),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Leave Type Details
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getLeaveTypeColor(
                      record.leaveType,
                      context,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getLeaveTypeDisplayName(record.leaveType),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _getLeaveTypeColor(record.leaveType, context),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.leaveType == 'Unpaid Leave'
                      ? 'Unlimited'
                      : '${record.balanceHours.toStringAsFixed(1)} hours',
                  style: TextStyle(
                    color: record.leaveType == 'Unpaid Leave'
                        ? ThemeUtils.getStatusChipColor(
                            'success',
                            Theme.of(context),
                          )
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Days and Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final successColor = ThemeUtils.getStatusChipColor(
                      'success',
                      theme,
                    );
                    final isAvailable =
                        record.leaveType == 'Unpaid Leave' ||
                        record.balanceHours > 0;
                    final textColor = isAvailable
                        ? successColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
                    final bgColor = isAvailable
                        ? successColor.withValues(alpha: 0.1)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1);

                    return Column(
                      children: [
                        Text(
                          record.leaveType == 'Unpaid Leave'
                              ? 'Unlimited'
                              : '${_hoursToDays(record.balanceHours, record.weeklyOrdinaryHours).toStringAsFixed(1)} days',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            record.leaveType == 'Unpaid Leave'
                                ? 'Available'
                                : (record.balanceHours > 0
                                      ? 'Available'
                                      : 'No balance'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Info Button
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.info_outline,
              size: 22,
              color: ThemeUtils.getSafeHeaderColor(Theme.of(context)),
            ),
            onPressed: () =>
                _showBalanceDetails(record, _employeeMap[record.employeeId]),
            tooltip: 'View detailed breakdown',
          ),
        ],
      ),
    );
  }

  IconData _getLeaveTypeIcon(String leaveType) {
    switch (leaveType) {
      case 'annualLeave':
        return Icons.beach_access;
      case 'personalCarersLeave':
        return Icons.health_and_safety;
      case 'compassionateLeave':
        return Icons.favorite;
      case 'longServiceLeave':
        return Icons.work_history;
      default:
        return Icons.event_available;
    }
  }

  Color _getLeaveTypeColor(String leaveType, BuildContext context) {
    final theme = Theme.of(context);
    final chartColors = ThemeUtils.getSafeChartColors(theme);

    switch (leaveType) {
      case 'annualLeave':
        return chartColors[0]; // Blue
      case 'personalCarersLeave':
        return chartColors[2]; // Orange
      case 'compassionateLeave':
        return chartColors[5]; // Red-like (deep orange)
      case 'longServiceLeave':
        return chartColors[4]; // Purple
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  /// Build accrual status dashboard
  Widget _buildAccrualStatusDashboard() {
    String formatAmPm(String hhmm) {
      try {
        final parts = hhmm.split(':');
        int h = int.parse(parts[0]);
        final m = int.parse(parts[1]).toString().padLeft(2, '0');
        final suffix = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        if (h == 0) h = 12;
        return '$h:$m $suffix';
      } catch (_) {
        return hhmm;
      }
    }

    DateTime? nextDailyRun() {
      try {
        if (_accrualDailyTime == null) return null;
        final parts = _accrualDailyTime!.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        var next = DateTime(now.year, now.month, now.day, hour, minute);
        if (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      } catch (_) {
        return null;
      }
    }

    DateTime? nextWeeklyRun() {
      try {
        if (_accrualWeeklyDay == null || _accrualWeeklyTime == null) {
          return null;
        }
        final dayMap = {
          'Sunday': 7,
          'Monday': 1,
          'Tuesday': 2,
          'Wednesday': 3,
          'Thursday': 4,
          'Friday': 5,
          'Saturday': 6,
        };
        final targetDay = dayMap[_accrualWeeklyDay] ?? 7;
        final parts = _accrualWeeklyTime!.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        var next = DateTime(now.year, now.month, now.day, hour, minute);
        final daysToAdd = (targetDay - now.weekday) % 7;
        next = next.add(Duration(days: daysToAdd));
        if (next.isBefore(now)) {
          next = next.add(const Duration(days: 7));
        }
        return next;
      } catch (_) {
        return null;
      }
    }

    String formatNextRun(DateTime? dt) {
      if (dt == null) return '—';
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.inMinutes < 0) return 'Just passed';
      if (diff.inMinutes == 0) return 'Now';
      if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'in ${diff.inHours}h';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final dailyTime = formatAmPm((_accrualDailyTime ?? '03:00'));
    final weeklyDay = _accrualWeeklyDay ?? 'Sunday';
    final weeklyTime = formatAmPm((_accrualWeeklyTime ?? '04:00'));
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Accrual System Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Daily Processing',
                  dailyTime,
                  'Processes yesterday\'s attendance',
                  Icons.schedule,
                  Colors.blue,
                  nextRunSubtitle: 'Next run: ${formatNextRun(nextDailyRun())}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  'Weekly Reconciliation',
                  '$weeklyDay $weeklyTime',
                  'Catches missed accruals',
                  Icons.update,
                  Colors.orange,
                  nextRunSubtitle:
                      'Next run: ${formatNextRun(nextWeeklyRun())}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Accrual Rate',
                  '4-5 weeks/year',
                  'Based on employee type',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  'Last Processed',
                  'Today',
                  'System running normally',
                  Icons.check_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status card for dashboard
  Widget _buildStatusCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    String? nextRunSubtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          if (nextRunSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              nextRunSubtitle,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccrualLogsTab() {
    return RefreshIndicator(
      onRefresh: _loadAccrualLogs,
      child: CustomScrollView(
        slivers: [
          // Accrual Status Dashboard
          SliverToBoxAdapter(child: _buildAccrualStatusDashboard()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          // Filter controls
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Employee filter - full width
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployee,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Employees'),
                      ),
                      ..._employees.map(
                        (emp) => DropdownMenuItem(
                          value: emp.id,
                          child: Text('${emp.firstName} ${emp.lastName}'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployee = value ?? 'all';
                      });
                      _loadAccrualLogs();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Leave type filter - full width
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLeaveType,
                    decoration: const InputDecoration(
                      labelText: 'Leave Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(
                        value: 'annualLeave',
                        child: Text('Annual Leave'),
                      ),
                      DropdownMenuItem(
                        value: 'personalCarersLeave',
                        child: Text('Personal/Carer\'s Leave'),
                      ),
                      DropdownMenuItem(
                        value: 'compassionateLeave',
                        child: Text('Compassionate Leave'),
                      ),
                      DropdownMenuItem(
                        value: 'longServiceLeave',
                        child: Text('Long Service Leave'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLeaveType = value ?? 'all';
                      });
                      _loadAccrualLogs();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Process Accrual Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingAccrual
                          ? null
                          : _processAccrualManually,
                      icon: _isProcessingAccrual
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _isProcessingAccrual
                            ? 'Processing...'
                            : 'Process Accrual Now',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: ThemeUtils.getAutoTextColor(
                          Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                // Set to start of day (00:00:00) in UTC
                                _startDate = DateTime.utc(
                                  date.year,
                                  date.month,
                                  date.day,
                                  0,
                                  0,
                                  0,
                                );
                              });
                              _loadAccrualLogs();
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _startDate == null
                                ? 'Start Date'
                                : 'From: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                // Set to end of day (23:59:59) in UTC for inclusive date range
                                _endDate = DateTime.utc(
                                  date.year,
                                  date.month,
                                  date.day,
                                  23,
                                  59,
                                  59,
                                );
                              });
                              _loadAccrualLogs();
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _endDate == null
                                ? 'End Date'
                                : 'To: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _selectedEmployee = 'all';
                            _selectedLeaveType = 'all';
                          });
                          _loadAccrualLogs();
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Filters',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Accrual logs header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.timeline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Accrual Logs (${_accrualLogs.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accrual logs list
          _accrualLogs.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No accrual logs found',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accrual logs will appear here as employees work and accrue leave.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final log = _accrualLogs[index];
                      final employee = _employeeMap[log.employeeId];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: log.isAccrual
                                ? ThemeUtils.getStatusChipColor(
                                    'approved',
                                    Theme.of(context),
                                  ).withValues(alpha: 0.2)
                                : ThemeUtils.getStatusChipColor(
                                    'rejected',
                                    Theme.of(context),
                                  ).withValues(alpha: 0.2),
                            child: Icon(
                              log.isAccrual ? Icons.add : Icons.remove,
                              color: log.isAccrual
                                  ? ThemeUtils.getStatusChipColor(
                                      'approved',
                                      Theme.of(context),
                                    )
                                  : ThemeUtils.getStatusChipColor(
                                      'rejected',
                                      Theme.of(context),
                                    ),
                            ),
                          ),
                          title: Text(
                            employee != null
                                ? '${employee.firstName} ${employee.lastName}'
                                : 'Unknown Employee',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${log.leaveTypeDisplayName} • ${log.reasonDisplayName}',
                              ),
                              Text(
                                'Date: ${log.accrualDate.day}/${log.accrualDate.month}/${log.accrualDate.year}',
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log.isAccrual
                                    ? '+${log.hoursAccrued.toStringAsFixed(2)}h'
                                    : '-${log.hoursDeducted.toStringAsFixed(2)}h',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: log.isAccrual
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Balance: ${log.balanceAfter.toStringAsFixed(2)}h',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }, childCount: _accrualLogs.length),
                  ),
                ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildCashOutTab() {
    return Column(
      children: [
        // Filter controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Employee filter - full width
              DropdownButtonFormField<String>(
                initialValue: _selectedEmployee,
                decoration: const InputDecoration(
                  labelText: 'Employee',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Employees'),
                  ),
                  ..._employees.map(
                    (emp) => DropdownMenuItem(
                      value: emp.id,
                      child: Text('${emp.firstName} ${emp.lastName}'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedEmployee = value ?? 'all';
                  });
                  _loadCashOutAgreements();
                  if (value != 'all') {
                    _loadEmployeeBalance(value!);
                  } else {
                    _selectedEmployeeBalance = null;
                  }
                },
              ),
              const SizedBox(height: 12),
              // Status filter - full width
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value ?? 'all';
                  });
                  _loadCashOutAgreements();
                },
              ),
              const SizedBox(height: 12),
              // Available Cash-Out Balance Display
              if (_selectedEmployee != 'all') ...[
                _buildAvailableCashOutBalance(),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showCashOutRequestDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New Cash-Out Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: ThemeUtils.getAutoTextColor(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedEmployee = 'all';
                        _selectedStatus = 'all';
                      });
                      _loadCashOutAgreements();
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear Filters',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cash-out agreements list
        Expanded(
          child: _cashOutAgreements.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cash-out agreements found',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cash-out requests will appear here when employees submit them.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCashOutAgreements,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cashOutAgreements.length,
                    itemBuilder: (context, index) {
                      final agreement = _cashOutAgreements[index];
                      final employee = _employeeMap[agreement.employeeId];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(agreement.status),
                            child: Icon(
                              _getStatusIcon(agreement.status),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            employee != null
                                ? '${employee.firstName} ${employee.lastName}'
                                : 'Unknown Employee',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${agreement.hoursCashedOut.toStringAsFixed(1)} hours • ${agreement.statusDisplayName}',
                              ),
                              Text(
                                'Date: ${agreement.date.day}/${agreement.date.month}/${agreement.date.year}',
                              ),
                              if (agreement.rejectionReason != null)
                                Text(
                                  'Reason: ${agreement.rejectionReason}',
                                  style: TextStyle(color: Colors.red[600]),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${agreement.totalPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${agreement.loadingPercentage.toStringAsFixed(1)}% loading',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _showCashOutDetails(agreement, employee),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAvailableCashOutBalance() {
    if (_isLoadingBalance) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading available cash-out balance...',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedEmployeeBalance == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Text(
              'Unable to load balance information',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Extract annual leave balance from the API response
    // Based on the leave_request_provider.dart, the API response structure uses 'balanceHours'
    double annualLeaveBalance = 0.0;
    String employeeName = 'Selected Employee';

    // Debug: Print the entire response structure
    if (kDebugMode) {
      Logger.debug(
        '🔍 Full balance response structure: $_selectedEmployeeBalance',
      );
    }

    // Try different possible response structures based on the actual API
    if (_selectedEmployeeBalance!['balanceHours'] != null) {
      // Direct balanceHours field
      annualLeaveBalance = (_selectedEmployeeBalance!['balanceHours'] as num)
          .toDouble();
      if (kDebugMode) {
        Logger.debug('🔍 Found balanceHours: $annualLeaveBalance');
      }
    } else if (_selectedEmployeeBalance!['data'] != null &&
        _selectedEmployeeBalance!['data']['balance'] != null) {
      // New policy-driven format: data.balance.annualLeave
      final balance =
          _selectedEmployeeBalance!['data']['balance'] as Map<String, dynamic>;
      if (balance['annualLeave'] != null) {
        final annualLeaveData = balance['annualLeave'] as Map<String, dynamic>;
        annualLeaveBalance =
            (annualLeaveData['available'] ?? annualLeaveData['total'] ?? 0.0)
                as double;
        if (kDebugMode) {
          Logger.debug(
            '🔍 Found data.balance.annualLeave: $annualLeaveBalance',
          );
        }
      }
    } else if (_selectedEmployeeBalance!['balance'] != null) {
      // Old format: balance.annualLeave
      final balance =
          _selectedEmployeeBalance!['balance'] as Map<String, dynamic>;
      if (balance['annualLeave'] != null) {
        final annualLeaveData = balance['annualLeave'] as Map<String, dynamic>;
        annualLeaveBalance =
            (annualLeaveData['available'] ?? annualLeaveData['total'] ?? 0.0)
                as double;
        if (kDebugMode) {
          Logger.debug('🔍 Found balance.annualLeave: $annualLeaveBalance');
        }
      }
    } else {
      // Try to find any annual leave related data in the response
      if (kDebugMode) {
        Logger.debug('🔍 Searching for annual leave data in response...');
      }
      _searchForAnnualLeaveData(_selectedEmployeeBalance!, (balance) {
        annualLeaveBalance = balance;
        if (kDebugMode) {
          Logger.debug('🔍 Found annual leave via search: $annualLeaveBalance');
        }
      });
    }

    // Get employee name
    employeeName =
        _selectedEmployeeBalance!['employeeName'] ??
        _selectedEmployeeBalance!['name'] ??
        'Selected Employee';

    if (kDebugMode) {
      Logger.debug('🔍 Final annual leave balance: $annualLeaveBalance hours');
    }

    // Calculate available cash-out (minimum 4 weeks = 20 days = 160 hours must remain)
    const minRequiredBalance = 160.0; // 4 weeks * 40 hours
    final availableForCashOut = (annualLeaveBalance - minRequiredBalance).clamp(
      0.0,
      double.infinity,
    );
    final availableDays = availableForCashOut / 8; // Assuming 8 hours per day

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: availableForCashOut > 0 ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: availableForCashOut > 0
              ? Colors.green[200]!
              : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                availableForCashOut > 0 ? Icons.check_circle : Icons.warning,
                color: availableForCashOut > 0
                    ? Colors.green[600]
                    : Colors.orange[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Available Cash-Out for $employeeName',
                style: TextStyle(
                  color: availableForCashOut > 0
                      ? Colors.green[700]
                      : Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Annual Leave Balance',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    Text(
                      '${annualLeaveBalance.toStringAsFixed(1)} hours (${(annualLeaveBalance / 8).toStringAsFixed(1)} days)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available for Cash-Out',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    Text(
                      availableForCashOut > 0
                          ? '${availableForCashOut.toStringAsFixed(1)} hours (${availableDays.toStringAsFixed(1)} days)'
                          : '0 hours (0 days)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: availableForCashOut > 0
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (availableForCashOut <= 0) ...[
            const SizedBox(height: 8),
            Text(
              'Note: Minimum 4 weeks (160 hours) must remain after cash-out',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to recursively search for annual leave data in the response
  void _searchForAnnualLeaveData(
    Map<String, dynamic> data,
    Function(double) onFound,
  ) {
    data.forEach((key, value) {
      if (key.toLowerCase().contains('annual') && value is num) {
        onFound(value.toDouble());
        return;
      } else if (value is Map<String, dynamic>) {
        _searchForAnnualLeaveData(value, onFound);
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            _searchForAnnualLeaveData(item, onFound);
          }
        }
      }
    });
  }

  Color _getStatusColor(String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'pending':
        return ThemeUtils.getStatusChipColor('pending', theme);
      case 'approved':
        return ThemeUtils.getStatusChipColor('approved', theme);
      case 'rejected':
        return ThemeUtils.getStatusChipColor('rejected', theme);
      case 'paid':
        return ThemeUtils.getStatusChipColor('info', theme);
      default:
        return ThemeUtils.getStatusChipColor('info', theme);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check;
      case 'rejected':
        return Icons.close;
      case 'paid':
        return Icons.payment;
      default:
        return Icons.help;
    }
  }

  void _showCashOutRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => CashOutRequestDialog(
        employees: _employees,
        onRequestSubmitted: (employeeId, hours, agreementText) {
          _submitCashOutRequest(employeeId, hours, agreementText);
        },
      ),
    );
  }

  Future<void> _submitCashOutRequest(
    String employeeId,
    double hours,
    String agreementText,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _apiService.requestLeaveCashOut(
        employeeId: employeeId,
        hoursToCashOut: hours,
        agreementText: agreementText,
      );

      if (success['success']) {
        _showSnackBar('Cash-out request submitted successfully');
        _loadCashOutAgreements();
      } else {
        _showSnackBar(
          'Failed to submit cash-out request: ${success['message']}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error submitting cash-out request: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCashOutDetails(LeaveCashOut agreement, Employee? employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cash-Out Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employee: ${employee?.firstName} ${employee?.lastName}'),
              Text('Hours: ${agreement.hoursCashedOut.toStringAsFixed(1)}'),
              Text('Status: ${agreement.statusDisplayName}'),
              Text(
                'Date: ${agreement.date.day}/${agreement.date.month}/${agreement.date.year}',
              ),
              Text('Base Pay: \$${agreement.grossPaid.toStringAsFixed(2)}'),
              Text(
                'Loading: \$${agreement.loadingPaid.toStringAsFixed(2)} (${agreement.loadingPercentage.toStringAsFixed(1)}%)',
              ),
              Text('Total: \$${agreement.totalPaid.toStringAsFixed(2)}'),
              if (agreement.rejectionReason != null)
                Text('Rejection Reason: ${agreement.rejectionReason}'),
            ],
          ),
        ),
        actions: [
          if (agreement.isPending) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _approveCashOut(agreement.id);
              },
              child: const Text('Approve'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectCashOut(agreement.id);
              },
              child: const Text('Reject'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveCashOut(String agreementId) async {
    try {
      final success = await _apiService.approveCashOutRequest(agreementId);
      if (success) {
        _showSnackBar('Cash-out request approved successfully');
        _loadCashOutAgreements();
      } else {
        _showSnackBar('Failed to approve cash-out request', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error approving cash-out request: $e', isError: true);
    }
  }

  Future<void> _rejectCashOut(String agreementId) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Cash-Out Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Please provide a reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                try {
                  final success = await _apiService.rejectCashOutRequest(
                    agreementId,
                    reason: reasonController.text.trim(),
                  );
                  if (success) {
                    _showSnackBar('Cash-out request rejected');
                    _loadCashOutAgreements();
                  } else {
                    _showSnackBar(
                      'Failed to reject cash-out request',
                      isError: true,
                    );
                  }
                } catch (e) {
                  _showSnackBar(
                    'Error rejecting cash-out request: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _getLeaveTypeDisplayName(String leaveType) {
    switch (leaveType) {
      case 'annualLeave':
        return 'Annual Leave';
      case 'personalCarersLeave':
        return 'Personal/Carer\'s Leave';
      case 'compassionateLeave':
        return 'Compassionate Leave';
      case 'longServiceLeave':
        return 'Long Service Leave';
      default:
        // Return as-is for unknown types, no need to log
        return leaveType;
    }
  }

  double _hoursToDays(double hours, double weeklyHours) {
    return hours / (weeklyHours / 5);
  }

  void _showBalanceDetails(LeaveBalanceRecord record, Employee? employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Balance Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (employee != null) ...[
                Text('Employee: ${employee.firstName} ${employee.lastName}'),
                Text('ID: ${employee.employeeId}'),
                const SizedBox(height: 16),
              ],
              Text('Leave Type: ${_getLeaveTypeDisplayName(record.leaveType)}'),
              Text(
                'Balance: ${record.leaveType == 'Unpaid Leave' ? 'Unlimited' : '${record.balanceHours.toStringAsFixed(1)} hours (${_hoursToDays(record.balanceHours, record.weeklyOrdinaryHours).toStringAsFixed(1)} days)'}',
              ),
              Text(
                'Accrued This Year: ${record.accruedThisYear.toStringAsFixed(1)} hours',
              ),
              Text(
                'Used This Year: ${record.usedThisYear.toStringAsFixed(1)} hours',
              ),
              Text(
                'Carry Over: ${record.carryOverFromLastYear.toStringAsFixed(1)} hours',
              ),
              Text(
                'Weekly Hours: ${record.weeklyOrdinaryHours.toStringAsFixed(1)}',
              ),
              Text('Is Shiftworker: ${record.isShiftworker ? 'Yes' : 'No'}'),
              Text('Weeks Entitlement: ${record.weeksEntitlement}'),
              const SizedBox(height: 16),
              Text(
                'Last Accrual: ${record.lastAccrualDate != null ? _formatDate(record.lastAccrualDate!) : 'Never'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildLeaveRequestsTab() {
    return Consumer<LeaveProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading leave requests...'),
              ],
            ),
          );
        }

        final leaveRequests = provider.leaveRequests.where((request) {
          if (_requestStatusFilter != 'all') {
            final statusStr = request.status.toString().split('.').last;
            if (statusStr.toLowerCase() != _requestStatusFilter.toLowerCase()) {
              return false;
            }
          }
          if (_selectedEmployee != 'all' &&
              request.employeeId != _selectedEmployee) {
            return false;
          }
          return true;
        }).toList();

        final pendingCount = leaveRequests
            .where((r) => r.status == LeaveRequestStatus.pending)
            .length;
        final approvedCount = leaveRequests
            .where((r) => r.status == LeaveRequestStatus.approved)
            .length;
        final rejectedCount = leaveRequests
            .where((r) => r.status == LeaveRequestStatus.rejected)
            .length;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Quick Stats Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildClickableStatCard(
                        'Pending',
                        pendingCount.toString(),
                        Colors.orange,
                        Icons.pending,
                        'pending',
                        _requestStatusFilter == 'pending',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildClickableStatCard(
                        'Approved',
                        approvedCount.toString(),
                        Colors.green,
                        Icons.check_circle,
                        'approved',
                        _requestStatusFilter == 'approved',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildClickableStatCard(
                        'Rejected',
                        rejectedCount.toString(),
                        Colors.red,
                        Icons.cancel,
                        'rejected',
                        _requestStatusFilter == 'rejected',
                      ),
                    ),
                  ],
                ),
              ),

              // Admin Leave Request Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/admin/leave_request');
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      'Submit Admin Leave Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),

              // Filter controls
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    // Employee filter
                    DropdownButtonFormField<String>(
                      initialValue: _selectedEmployee,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Employees'),
                        ),
                        ..._employees.map(
                          (emp) => DropdownMenuItem(
                            value: emp.id,
                            child: Text('${emp.firstName} ${emp.lastName}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedEmployee = value ?? 'all';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Status filter
                    DropdownButtonFormField<String>(
                      initialValue: _requestStatusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _requestStatusFilter = value ?? 'all';
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Leave requests list
              leaveRequests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: leaveRequests.length,
                      itemBuilder: (context, index) {
                        final request = leaveRequests[index];
                        return _buildModernLeaveCard(
                          request,
                          false,
                          index,
                          provider,
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClickableStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
    String filterValue,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _requestStatusFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
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
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No leave requests found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check back later',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLeaveCard(
    LeaveRequest request,
    bool isProcessing,
    int index,
    LeaveProvider provider,
  ) {
    final statusStr = request.status.toString().split('.').last;
    final statusColor = _getStatusColor(statusStr);
    final statusText =
        statusStr.substring(0, 1).toUpperCase() + statusStr.substring(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => _showLeaveRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with employee name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.role == 'admin'
                              ? 'Administration'
                              : 'Employee',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(statusText, statusColor),
                ],
              ),
              const SizedBox(height: 16),

              // Leave details
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${request.duration} days',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    request.leaveType.toString().toLowerCase(),
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),

              if (request.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Reason: ${request.reason}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],

              // Action buttons for pending requests (hide if admin's own request)
              if (request.status == LeaveRequestStatus.pending) ...[
                Builder(
                  builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final currentUserId = authProvider.user?['_id']?.toString();
                    final isOwnRequest =
                        request.role == 'admin' &&
                        request.user != null &&
                        request.user == currentUserId;

                    // Don't show buttons if this is the admin's own request
                    if (isOwnRequest) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _approveLeaveRequest(request.id),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 16),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      ThemeUtils.getStatusChipColor(
                                        'approved',
                                        Theme.of(context),
                                      ),
                                  foregroundColor:
                                      ThemeUtils.getStatusChipTextColor(
                                        'approved',
                                        Theme.of(context),
                                      ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _rejectLeaveRequest(request.id),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      ThemeUtils.getStatusChipColor(
                                        'rejected',
                                        Theme.of(context),
                                      ),
                                  foregroundColor:
                                      ThemeUtils.getStatusChipTextColor(
                                        'rejected',
                                        Theme.of(context),
                                      ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLeaveRequestDetails(LeaveRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employee: ${request.employeeName}'),
              Text(
                'Role: ${request.role == 'admin' ? 'Administration' : 'Employee'}',
              ),
              Text('Leave Type: ${request.leaveType.toString().toLowerCase()}'),
              Text('Start Date: ${_formatDate(request.startDate)}'),
              Text('End Date: ${_formatDate(request.endDate)}'),
              Text('Duration: ${request.duration} days'),
              Text(
                'Status: ${request.status.toString().split('.').last.substring(0, 1).toUpperCase() + request.status.toString().split('.').last.substring(1)}',
              ),
              if (request.reason.isNotEmpty) Text('Reason: ${request.reason}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveLeaveRequest(String requestId) async {
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    try {
      await leaveProvider.approveLeaveRequest(requestId);
      _showSnackBar('Leave request approved successfully');
      _loadLeaveRequests();
    } catch (e) {
      _showSnackBar('Error approving leave request: $e', isError: true);
    }
  }

  Future<void> _rejectLeaveRequest(String requestId) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Please provide a reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final leaveProvider = Provider.of<LeaveProvider>(
                  context,
                  listen: false,
                );
                try {
                  await leaveProvider.rejectLeaveRequest(
                    requestId,
                    reason: reasonController.text.trim(),
                  );
                  _showSnackBar('Leave request rejected');
                  _loadLeaveRequests();
                } catch (e) {
                  _showSnackBar(
                    'Error rejecting leave request: $e',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class CashOutRequestDialog extends StatefulWidget {
  final List<Employee> employees;
  final Function(String employeeId, double hours, String agreementText)
  onRequestSubmitted;

  const CashOutRequestDialog({
    super.key,
    required this.employees,
    required this.onRequestSubmitted,
  });

  @override
  State<CashOutRequestDialog> createState() => _CashOutRequestDialogState();
}

class _CashOutRequestDialogState extends State<CashOutRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _agreementController = TextEditingController();

  String? _selectedEmployeeId;
  double? _previewAmount;
  bool _isCalculating = false;
  String? _previewError;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _agreementController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _calculatePreview() async {
    if (_selectedEmployeeId == null || _hoursController.text.isEmpty) return;

    setState(() {
      _isCalculating = true;
      _previewError = null;
    });

    try {
      final hours = double.tryParse(_hoursController.text);
      if (hours == null || hours <= 0) return;

      final preview = await _apiService.getCashOutPreview(
        employeeId: _selectedEmployeeId!,
        hoursToCashOut: hours,
      );

      if (preview != null) {
        setState(() {
          _previewAmount = preview['totalPay']?.toDouble();
        });
      } else {
        // Fallback to simple calculation
        final employee = widget.employees.firstWhere(
          (emp) => emp.id == _selectedEmployeeId,
        );
        final basePay = hours * (employee.hourlyRate ?? 25.0);
        final loading = basePay * 0.175;
        final totalPay = basePay + loading;

        setState(() {
          _previewAmount = totalPay;
        });
      }
    } catch (e) {
      Logger.error('Error calculating preview: $e');
      setState(() {
        _previewError = 'Unable to calculate preview';
      });
    } finally {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Cash-Out Request'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'Employee *',
                  border: OutlineInputBorder(),
                ),
                items: widget.employees.map((employee) {
                  return DropdownMenuItem(
                    value: employee.id,
                    child: Text('${employee.firstName} ${employee.lastName}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEmployeeId = value;
                    _previewAmount = null;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an employee';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Hours Input
              TextFormField(
                controller: _hoursController,
                decoration: const InputDecoration(
                  labelText: 'Hours to Cash Out *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter number of hours',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _calculatePreview();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hours to cash out';
                  }
                  final hours = double.tryParse(value);
                  if (hours == null || hours <= 0) {
                    return 'Please enter a valid number of hours';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Agreement Text
              TextFormField(
                controller: _agreementController,
                decoration: const InputDecoration(
                  labelText: 'Agreement Details',
                  border: OutlineInputBorder(),
                  hintText: 'Brief description of the agreement',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide agreement details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Preview Amount
              if (_isCalculating) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Calculating preview...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_previewError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _previewError!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_previewAmount != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Payment:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_previewAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'Including 17.5% loading',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Info Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minimum 4 weeks leave balance must remain after cash-out',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final hours = double.parse(_hoursController.text);
              final agreementText = _agreementController.text.trim();

              Navigator.pop(context);
              widget.onRequestSubmitted(
                _selectedEmployeeId!,
                hours,
                agreementText,
              );
            }
          },
          child: const Text('Submit Request'),
        ),
      ],
    );
  }
}
