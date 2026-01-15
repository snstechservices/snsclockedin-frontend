// Suppress the analyzer warning about an optional constructor parameter
// that remains supplied at call sites across the codebase.
// ignore_for_file: unused_element_parameter
import 'package:flutter/material.dart';
import 'package:sns_rooster/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/company_provider.dart';
import '../../utils/time_utils.dart';
import '../../utils/theme_utils.dart';
import 'package:sns_rooster/widgets/app_drawer.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/global_notification_service.dart';
import '../../widgets/modern_card_widget.dart';
import '../../widgets/leave_policy_info_widget.dart';
import '../../widgets/employee_cash_out_dialog.dart';
import '../../services/api_service.dart';
import 'dart:convert'; // Added for json.decode
import 'package:http/http.dart' as http; // Added for http
import '../../config/api_config.dart'; // Added for ApiConfig
import '../../providers/company_calendar_provider.dart'; // Added for CompanyCalendarProvider
import 'dart:async'; // Added for Timer
// Note: removed local `print` redirect to avoid ambiguous symbol imports.
// We'll replace `print(...)` usages with `Logger` calls in a controlled sweep.

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  // Form and UI state
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  bool _showHalfDayDetails = false;
  bool _notificationCleared = false;

  // Leave request state
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLeaveType = 'Annual Leave';
  bool _isHalfDay = false;
  TimeOfDay? _halfDayLeaveTime;
  String? _employeeId;
  String _currentAttendanceStatus = 'unknown';

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Company calendar state
  bool _companyCalendarLoaded = false;
  List<Map<String, dynamic>> _companyHolidays = [];
  List<Map<String, dynamic>> _companyNonWorkingDays = [];

  // Auto-refresh timer
  Timer? _refreshTimer;

  // Accrual preview state
  Map<String, dynamic>? _accrualPreview;
  bool _isLoadingAccrualPreview = false;

  // Leave balance state
  Map<String, dynamic> _annualLeave = {};
  Map<String, dynamic> _sickLeave = {};
  Map<String, dynamic> _casualLeave = {};
  Map<String, dynamic> _maternityLeave = {};
  Map<String, dynamic> _paternityLeave = {};
  Map<String, dynamic> _unpaidLeave = {};

  // Leave policy state
  bool _allowHalfDays = false;
  bool _policyLoaded = false;
  Map<String, dynamic>? _currentPolicy;

  // Tab controller
  late TabController _tabController;

  // Constants
  static const List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Unpaid Leave',
  ];

  static const Map<String, Color> _leaveTypeColors = {
    'Annual Leave': Colors.blue,
    'Sick Leave': Colors.red,
    'Casual Leave': Colors.orange,
    'Maternity Leave': Colors.pinkAccent,
    'Paternity Leave': Colors.blueAccent,
    'Unpaid Leave': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild UI when tab changes
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check for initial tab from route arguments (for navigation from notifications)
      final route = ModalRoute.of(context);
      final arguments = route?.settings.arguments;
      if (arguments is Map<String, dynamic> &&
          arguments.containsKey('initialTab')) {
        final initialTab = arguments['initialTab'] as int?;
        if (initialTab != null && initialTab >= 0 && initialTab < 3) {
          _tabController.animateTo(initialTab);
          Logger.info(
            'LeaveRequestScreen: Navigated to tab index $initialTab from notification',
          );
        }
      }

      await _loadEmployeeAndLeaveRequests();
      _loadLeavePolicy();
      _startAutoRefresh();
    });
    _selectedDay = _focusedDay; // Initialize selectedDay
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notificationCleared) {
      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.hide();
      _notificationCleared = true;
    }
  }

  @override
  void didUpdateWidget(LeaveRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload policy when widget updates to get latest changes
    _loadLeavePolicy();
  }

  Future<void> _loadEmployeeAndLeaveRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leaveProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );
    if (authProvider.user?['_id'] != null) {
      final employeeId = await leaveProvider.fetchEmployeeIdByUserId(
        authProvider.user!['_id'],
      );
      setState(() {
        _employeeId = employeeId;
      });
      if (employeeId != null) {
        await leaveProvider.getUserLeaveRequests(employeeId);
        await leaveProvider.loadLeaveBalances(
          employeeId,
        ); // Load real leave balances
      }
    }

    // Fetch current attendance status
    await _fetchCurrentAttendanceStatus();

    // Load company calendar data
    await _loadCompanyCalendar();
  }

  /// Load company calendar data including holidays and non-working days
  Future<void> _loadCompanyCalendar() async {
    try {
      final companyCalendarProvider = Provider.of<CompanyCalendarProvider>(
        context,
        listen: false,
      );

      // Check if company calendar feature is available
      await companyCalendarProvider.checkFeatureAvailability();

      if (companyCalendarProvider.featureAvailable) {
        // Fetch current year's calendar
        final currentYear = DateTime.now().year;
        await companyCalendarProvider.fetchCompanyCalendar(currentYear);

        if (companyCalendarProvider.calendar != null) {
          final calendar = companyCalendarProvider.calendar!;

          setState(() {
            _companyHolidays = List<Map<String, dynamic>>.from(
              calendar['holidays'] ?? [],
            );
            _companyNonWorkingDays = List<Map<String, dynamic>>.from(
              calendar['nonWorkingDays'] ?? [],
            );
            _companyCalendarLoaded = true;
          });
        }
      }
    } catch (e) {
      Logger.warning('Failed to load company calendar: $e');
      // Don't show error to user as this is not critical for leave requests
    }
  }

  Future<void> _fetchCurrentAttendanceStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['_id'];
      if (userId == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attendance/status'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentAttendanceStatus = data['status'] ?? 'unknown';
        });
      }
    } catch (e) {
      // 'Error fetching attendance status: $e');
    }
  }

  String _getTodayLeaveGuidance() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (_startDate != null) {
      final startDateOnly = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      if (startDateOnly.isAtSameMomentAs(todayOnly)) {
        // User is requesting leave for today
        switch (_currentAttendanceStatus) {
          case 'clocked_in':
          case 'on_break':
            if (_isHalfDay) {
              return '✅ You can request a half-day leave while clocked in.';
            } else {
              return '⚠️ You cannot request a full-day leave while clocked in. Please clock out first or select half-day leave.';
            }
          case 'clocked_out':
          case 'not_clocked_in':
            if (_isHalfDay) {
              return '⚠️ You must be clocked in to request a half-day leave for today.';
            } else {
              return '✅ You can request a full-day leave since you are not clocked in.';
            }
          default:
            return 'ℹ️ Select your leave type and dates.';
        }
      }
    }
    return 'ℹ️ Select your leave type and dates.';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    // Calculate minimum date (tomorrow)
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final DateTime minDate = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    );

    // Set initial date to tomorrow if no date is selected
    final DateTime initialDate = _startDate ?? minDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate, // Always require at least 1 day in advance
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Prevent selecting weekends if company policy requires it
        // return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
        return true; // For now, allow all days
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Normalize the picked date to avoid timezone issues
      final normalizedDate = DateTime(picked.year, picked.month, picked.day);
      Logger.debug(
        'Date picker selected: $picked (normalized: $normalizedDate)',
      );

      setState(() {
        if (_isHalfDay) {
          // For half-day leaves, set both start and end date to the same date
          _startDate = normalizedDate;
          _endDate = normalizedDate;
        } else {
          // For full-day leaves, handle start and end dates separately
          if (isStartDate) {
            _startDate = normalizedDate;
            if (_endDate != null && _endDate!.isBefore(_startDate!)) {
              _endDate = _startDate;
            }
          } else {
            _endDate = normalizedDate;
          }
        }
      });

      // Refresh attendance status if selecting today's date
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final pickedOnly = DateTime(picked.year, picked.month, picked.day);
      if (pickedOnly.isAtSameMomentAs(todayOnly)) {
        await _fetchCurrentAttendanceStatus();
      }
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate today's leave request based on attendance status
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (_startDate != null) {
      final startDateOnly = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      if (startDateOnly.isAtSameMomentAs(todayOnly)) {
        // User is requesting leave for today
        switch (_currentAttendanceStatus) {
          case 'clocked_in':
          case 'on_break':
            if (!_isHalfDay) {
              final notificationService =
                  Provider.of<GlobalNotificationService>(
                    context,
                    listen: false,
                  );
              notificationService.showError(
                'You cannot request a full-day leave for today while clocked in. Please either clock out first or select half-day leave.',
              );
              return;
            }
            break;
          case 'clocked_out':
          case 'not_clocked_in':
            if (_isHalfDay) {
              final notificationService =
                  Provider.of<GlobalNotificationService>(
                    context,
                    listen: false,
                  );
              notificationService.showError(
                'You must be clocked in to request a half-day leave for today. Please clock in first and then apply for half-day leave.',
              );
              return;
            }
            break;
        }
      }
    }

    // For half-day leaves, start date and leave time are required
    if (_isHalfDay) {
      if (_startDate == null) {
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showWarning(
          'Please select a date for half-day leave',
        );
        return;
      }
      if (_halfDayLeaveTime == null) {
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showWarning(
          'Please select a time to leave for half-day leave',
        );
        return;
      }
      // For half-day, set end date same as start date
      _endDate = _startDate;
    } else {
      // For full-day leaves, both dates are required
      if (_startDate == null || _endDate == null) {
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showWarning(
          'Please select both start and end dates',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveRequestProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      Logger.info(
        'DEBUG: profileProvider.profile = ${profileProvider.profile}',
      );
      Logger.info('DEBUG: authProvider.user = ${authProvider.user}');
      final userId = authProvider.user?['_id'];
      final userRole = authProvider.user?['role'];
      String? employeeId;

      if (userRole == 'admin') {
        // For admins, we don't need an employee ID - we'll use the user ID directly
        employeeId = null;
      } else {
        // For employees, fetch the Employee document
        if (userId != null) {
          final fetchedEmployeeId = await leaveProvider.fetchEmployeeIdByUserId(
            userId,
          );
          if (fetchedEmployeeId != null) {
            employeeId = fetchedEmployeeId;
          }
        }
        if (employeeId == null) {
          final notificationService = Provider.of<GlobalNotificationService>(
            context,
            listen: false,
          );
          notificationService.showError(
            'Employee record not found. Please contact admin.',
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Ensure same day leaves have the same date
      DateTime startDate = _startDate!;
      DateTime endDate = _endDate!;

      // If start and end are the same day, set end to same date as start
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        endDate = DateTime(startDate.year, startDate.month, startDate.day);
      }

      // Send dates in YYYY-MM-DD format to avoid timezone issues
      final startDateStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      Logger.debug('📤 Sending to backend:');
      Logger.debug('📤 Start date: $_startDate -> $startDateStr');
      Logger.debug('📤 End date: $_endDate -> $endDateStr');

      final requestData = {
        'leaveType': _selectedLeaveType,
        'startDate': startDateStr,
        'endDate': endDateStr,
        'reason': _reasonController.text,
        'isHalfDay': _isHalfDay, // Add half-day flag
        'halfDayLeaveTime': _isHalfDay && _halfDayLeaveTime != null
            ? '${_halfDayLeaveTime!.hour.toString().padLeft(2, '0')}:${_halfDayLeaveTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'approverId': null,
        'comments': '',
      };

      // Add employeeId only for employees, not for admins
      if (employeeId != null) {
        requestData['employeeId'] = employeeId;
      }

      final result = await leaveProvider.createLeaveRequest(requestData);

      if (!mounted) {
        return;
      }

      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );

      if (result['success'] == true) {
        // Show success message
        notificationService.showSuccess(
          result['message'] ?? 'Leave request submitted successfully',
        );

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Leave Request Submitted',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result['message'] ??
                                'Your leave request has been submitted successfully.',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Next Steps:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.timer,
                    'Your request will be reviewed soon',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.notifications_active,
                    'You\'ll be notified of the decision',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Check the Leave History tab for status',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('OK, Got It'),
                ),
              ],
            ),
          ),
        );

        _resetForm();

        // Reload leave requests and balances
        if (_employeeId != null) {
          await leaveProvider.getUserLeaveRequests(_employeeId!);
          await leaveProvider.fetchLeaveBalances(_employeeId!);
          setState(() {}); // Force UI update
        }
      } else {
        // Parse validation errors from response
        final errorMessage =
            result['message'] ?? 'Failed to submit leave request';
        final errors = result['errors'] as Map<String, dynamic>?;

        // Show error message
        notificationService.showError(errorMessage);

        // Build list of specific error messages
        List<Widget> errorItems = [];

        if (errors != null && errors.isNotEmpty) {
          // Map field names to user-friendly labels and icons
          final fieldLabels = {
            'reason': {
              'label': 'Reason',
              'icon': Icons.description,
              'hint': 'Reason must be at least 10 characters',
            },
            'startDate': {
              'label': 'Start Date',
              'icon': Icons.date_range,
              'hint': 'Start date cannot be in the past',
            },
            'endDate': {
              'label': 'End Date',
              'icon': Icons.date_range,
              'hint': 'End date cannot be before start date',
            },
            'leaveType': {
              'label': 'Leave Type',
              'icon': Icons.category,
              'hint': 'Please select a valid leave type',
            },
            'halfDayLeaveTime': {
              'label': 'Half-Day Time',
              'icon': Icons.access_time,
              'hint':
                  'Half-day leave time is required when requesting half-day leave',
            },
          };

          errors.forEach((field, errorList) {
            if (errorList is List && errorList.isNotEmpty) {
              final firstError = errorList[0] as Map<String, dynamic>?;
              final errorMsg = firstError?['message'] ?? 'Invalid input';
              final fieldInfo =
                  fieldLabels[field] ??
                  {
                    'label': field,
                    'icon': Icons.error_outline,
                    'hint': errorMsg,
                  };

              errorItems.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        fieldInfo['icon'] as IconData,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fieldInfo['label'] as String,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              errorMsg,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
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
          });
        }

        // If no specific errors, show generic checks
        if (errorItems.isEmpty) {
          errorItems.addAll([
            _buildCheckRow(
              Icons.account_balance_wallet,
              'Your leave balance is sufficient',
            ),
            const SizedBox(height: 8),
            _buildCheckRow(Icons.date_range, 'Selected dates are valid'),
            const SizedBox(height: 8),
            _buildCheckRow(Icons.category, 'Leave type is available'),
            const SizedBox(height: 8),
            _buildCheckRow(Icons.description, 'Reason is properly filled'),
          ]);
        }

        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 30,
                ),
                const SizedBox(width: 10),
                const Text('Leave Request Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    errors != null && errors.isNotEmpty
                        ? 'Issues Found:'
                        : 'Please Check:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...errorItems,
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _reasonController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedLeaveType = 'Annual Leave';
      _isHalfDay = false; // Reset half-day option
      _halfDayLeaveTime = null; // Reset half-day leave time
    });
  }

  // Show cancel confirmation dialog
  void _showCancelDialog(String requestId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Leave Request'),
          content: Text(
            'Are you sure you want to cancel this leave request? (ID: $requestId)\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _cancelLeaveRequest(requestId);
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Cancel leave request
  Future<void> _cancelLeaveRequest(String requestId) async {
    final leaveProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );
    final notificationService = Provider.of<GlobalNotificationService>(
      context,
      listen: false,
    );

    try {
      final success = await leaveProvider.cancelLeaveRequest(requestId);

      if (success) {
        notificationService.showSuccess('Leave request cancelled successfully');
        // Refresh the leave requests list
        if (_employeeId != null) {
          await leaveProvider.getUserLeaveRequests(_employeeId!);
        }
      } else {
        final errorMessage =
            leaveProvider.error ?? 'Failed to cancel leave request';
        notificationService.showError(errorMessage);
      }
    } catch (e) {
      notificationService.showError('Error cancelling leave request: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Start auto-refresh timer to update leave requests every 30 seconds
  void _startAutoRefresh() {
    Logger.info('🔄 Starting auto-refresh timer for employee leave requests');
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      Logger.debug(
        '🔄 Auto-refresh triggered - mounted: $mounted, employeeId: $_employeeId',
      );
      if (mounted && _employeeId != null) {
        _refreshLeaveRequests();
      }
    });
  }

  /// Refresh leave requests data
  Future<void> _refreshLeaveRequests() async {
    try {
      Logger.info('🔄 Refreshing leave requests for employee: $_employeeId');
      final leaveProvider = Provider.of<LeaveRequestProvider>(
        context,
        listen: false,
      );
      if (_employeeId != null) {
        await leaveProvider.getUserLeaveRequests(_employeeId!);
        if (mounted) {
          setState(() {}); // Update UI
          Logger.debug('🔄 Leave requests refreshed successfully');
        }
      } else {
        Logger.warning('🔄 Cannot refresh - employeeId is null');
      }
    } catch (e) {
      // Silent fail for auto-refresh
      Logger.error('Auto-refresh error: $e');
    }
  }

  /// Check if two dates are the same day
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Format date for display, handling timezone issues
  String _formatDateForDisplay(String dateString) {
    try {
      // If the date string is in YYYY-MM-DD format, parse it as local date
      if (dateString.contains('T')) {
        // ISO format - parse and convert to local
        final parsed = DateTime.parse(dateString);
        return DateFormat('yyyy-MM-dd').format(parsed.toLocal());
      } else {
        // YYYY-MM-DD format - parse as local date directly
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final localDate = DateTime(year, month, day);
          return DateFormat('yyyy-MM-dd').format(localDate);
        }
      }
      // Fallback to original parsing
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(dateString));
    } catch (e) {
      Logger.error('Error formatting date: $dateString, error: $e');
      return dateString; // Return original string if parsing fails
    }
  }

  /// Format DateTime for API (yyyy-MM-dd format)
  String _formatDateForAPI(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parse date for comparison, handling timezone issues
  DateTime _parseDateForComparison(String dateString) {
    try {
      // If the date string is in YYYY-MM-DD format, parse it as local date
      if (dateString.contains('T')) {
        // ISO format - parse and convert to local
        return DateTime.parse(dateString).toLocal();
      } else {
        // YYYY-MM-DD format - parse as local date directly
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
      // Fallback to original parsing
      return DateTime.parse(dateString);
    } catch (e) {
      Logger.error('Error parsing date: $dateString, error: $e');
      return DateTime.now(); // Return current date if parsing fails
    }
  }

  // Calendar day selection handler
  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  // Function to get events for a given day
  List<dynamic> getEventsForDay(DateTime day) {
    final leaveProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );
    final events = <dynamic>[];

    // Add leave requests
    final leaveEvents = leaveProvider.leaveRequests.where((request) {
      final startDate = _parseDateForComparison(request['startDate']);
      final endDate = _parseDateForComparison(request['endDate']);
      // Normalize dates to compare only year, month, and day
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final normalizedStartDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEndDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );

      return (normalizedDay.isAfter(
            normalizedStartDate.subtract(const Duration(days: 1)),
          ) &&
          normalizedDay.isBefore(
            normalizedEndDate.add(const Duration(days: 1)),
          ));
    }).toList();

    // Add leave request events
    for (final request in leaveEvents) {
      events.add({
        'leaveType': request['leaveType'],
        'status': request['status'],
        'type': null, // null indicates it's a leave request
      });
    }

    // Add company calendar events
    if (_companyCalendarLoaded) {
      // Add holidays (including multi-day holidays)
      for (final holiday in _companyHolidays) {
        try {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          bool isHoliday = false;

          // Check if it's a multi-day holiday
          if (holiday['startDate'] != null && holiday['endDate'] != null) {
            final startDate = DateTime.parse(holiday['startDate']);
            final endDate = DateTime.parse(holiday['endDate']);
            final normalizedStartDate = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            final normalizedEndDate = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
            );

            // Check if the current day falls within the holiday range
            if (normalizedDay.isAtSameMomentAs(normalizedStartDate) ||
                normalizedDay.isAtSameMomentAs(normalizedEndDate) ||
                (normalizedDay.isAfter(normalizedStartDate) &&
                    normalizedDay.isBefore(normalizedEndDate))) {
              isHoliday = true;
              // Use start date for display
            }
          } else {
            // Single-day holiday
            final holidayDateObj = DateTime.parse(holiday['date']);
            final normalizedHolidayDate = DateTime(
              holidayDateObj.year,
              holidayDateObj.month,
              holidayDateObj.day,
            );

            if (normalizedDay.isAtSameMomentAs(normalizedHolidayDate)) {
              isHoliday = true;
            }
          }

          if (isHoliday) {
            // Ensure we always use a valid ISO date string
            String eventDate;
            if (holiday['startDate'] != null) {
              eventDate = holiday['startDate'];
            } else if (holiday['date'] != null) {
              eventDate = holiday['date'];
            } else {
              eventDate = DateTime.now().toIso8601String();
            }

            events.add({
              'name': holiday['name'],
              'date': eventDate, // Always use parseable ISO date
              'description': holiday['description'],
              'type': 'holiday',
            });
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Add non-working days
      for (final nwd in _companyNonWorkingDays) {
        try {
          final startDate = DateTime.parse(nwd['startDate']);
          final endDate = DateTime.parse(nwd['endDate'] ?? nwd['startDate']);
          final normalizedStartDate = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final normalizedEndDate = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
          );
          final normalizedDay = DateTime(day.year, day.month, day.day);

          if (normalizedDay.isAfter(
                normalizedStartDate.subtract(const Duration(days: 1)),
              ) &&
              normalizedDay.isBefore(
                normalizedEndDate.add(const Duration(days: 1)),
              )) {
            events.add({
              'name': nwd['name'],
              'startDate': nwd['startDate'],
              'endDate': nwd['endDate'],
              'reason': nwd['reason'],
              'type': 'nonWorkingDay',
            });
          }
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    return events;
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.blue[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
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

    final theme = Theme.of(context);
    final leaveProvider = Provider.of<LeaveRequestProvider>(context);

    // Update leave balance state from provider
    _updateLeaveBalances(leaveProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: ThemeUtils.getAutoTextColor(
          Theme.of(context).colorScheme.primary,
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: theme.colorScheme.surface,
            child: Builder(
              builder: (context) {
                final headerColor = ThemeUtils.getSafeHeaderColor(theme);
                return TabBar(
                  controller: _tabController,
                  labelColor: headerColor,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
                  indicatorColor: headerColor,
                  tabs: const [
                    Tab(icon: Icon(Icons.edit_note), text: 'Leave Application'),
                    Tab(
                      icon: Icon(Icons.calendar_today),
                      text: 'Company Calendar',
                    ),
                    Tab(icon: Icon(Icons.history), text: 'Leave History'),
                  ],
                );
              },
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaveApplicationTab(),
                _buildCompanyCalendarTab(),
                _buildLeaveHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Update leave balance state from provider
  void _updateLeaveBalances(LeaveRequestProvider leaveProvider) {
    final leaveBalances = leaveProvider.leaveBalances;
    _annualLeave = leaveBalances['annual'] ?? {};
    _sickLeave = leaveBalances['sick'] ?? {};
    _casualLeave = leaveBalances['casual'] ?? {};
    _maternityLeave = leaveBalances['maternity'] ?? {};
    _paternityLeave = leaveBalances['paternity'] ?? {};
    _unpaidLeave = leaveBalances['unpaid'] ?? {};
  }

  /// Format leave balance for display
  String _formatLeaveBalance(dynamic value) {
    if (value == null) return '-';
    if (value is double) {
      if (value == 0.0) return '0.0';
      // Format to 1 decimal place for better readability
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  /// Build leave balance item with half-day support
  Widget _buildLeaveBalanceItemWithHalfDay(
    String type,
    String used,
    String total,
    String? halfDayUsed,
    String? halfDayTotal,
  ) {
    // Special handling for Unpaid Leave
    final isUnpaidLeave = type == 'Unpaid Leave';

    return Column(
      children: [
        Text(
          type,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _leaveTypeColors[type] ?? Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        // Full day balance
        Text(
          isUnpaidLeave ? 'Unlimited' : used,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isUnpaidLeave
                ? Colors.green
                : (_leaveTypeColors[type] ?? Colors.black),
          ),
        ),
        Text(
          isUnpaidLeave ? 'Available' : 'of $total',
          style: TextStyle(
            fontSize: 12,
            color: isUnpaidLeave ? Colors.green : Colors.grey,
          ),
        ),
        // Half day balance (if available and not Unpaid Leave)
        if (halfDayUsed != null && halfDayTotal != null && !isUnpaidLeave) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              '½: ${_formatLeaveBalance(halfDayUsed)}/${_formatLeaveBalance(halfDayTotal)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build half-day detail item
  Widget _buildHalfDayDetailItem(
    String type,
    String used,
    String total,
    Color color,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: 9, // Further reduced font size
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2), // Minimal spacing
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 1,
            ), // Minimal padding
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3), // Minimal border radius
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '½: $used/$total',
              style: TextStyle(
                fontSize: 8, // Minimal font size
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Get status color for leave requests
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Build calendar event item for display
  Widget _buildCalendarEventItem(
    String title,
    String date,
    String description,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date, // Display the date string directly without parsing
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the Leave Application tab content
  Widget _buildLeaveApplicationTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeaveBalanceSection(theme),
          const SizedBox(height: 24),
          _buildLeavePolicySection(theme),
          const SizedBox(height: 24),
          _buildCashOutSection(theme),
          const SizedBox(height: 24),
          _buildLeaveRequestForm(theme),
        ],
      ),
    );
  }

  /// Build the leave balance section
  Widget _buildLeaveBalanceSection(ThemeData theme) {
    return ModernCard(
      accentColor: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Balance',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Main leave balance cards - first row
          Row(
            children: [
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Annual Leave',
                  _formatLeaveBalance(_annualLeave['available']),
                  _formatLeaveBalance(_annualLeave['total']),
                  _formatLeaveBalance(_annualLeave['halfDayUsed']),
                  _formatLeaveBalance(_annualLeave['halfDayTotal']),
                ),
              ),
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Sick Leave',
                  _formatLeaveBalance(_sickLeave['available']),
                  _formatLeaveBalance(_sickLeave['total']),
                  _formatLeaveBalance(_sickLeave['halfDayUsed']),
                  _formatLeaveBalance(_sickLeave['halfDayTotal']),
                ),
              ),
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Casual Leave',
                  _formatLeaveBalance(_casualLeave['available']),
                  _formatLeaveBalance(_casualLeave['total']),
                  _formatLeaveBalance(_casualLeave['halfDayUsed']),
                  _formatLeaveBalance(_casualLeave['halfDayTotal']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row of leave balance cards
          Row(
            children: [
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Maternity Leave',
                  _formatLeaveBalance(_maternityLeave['available']),
                  _formatLeaveBalance(_maternityLeave['total']),
                  _formatLeaveBalance(_maternityLeave['halfDayUsed']),
                  _formatLeaveBalance(_maternityLeave['halfDayTotal']),
                ),
              ),
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Paternity Leave',
                  _formatLeaveBalance(_paternityLeave['available']),
                  _formatLeaveBalance(_paternityLeave['total']),
                  _formatLeaveBalance(_paternityLeave['halfDayUsed']),
                  _formatLeaveBalance(_paternityLeave['halfDayTotal']),
                ),
              ),
              Expanded(
                child: _buildLeaveBalanceItemWithHalfDay(
                  'Unpaid Leave',
                  _unpaidLeave['used']?.toString() ??
                      '-', // Keep 'used' for Unpaid Leave as it's special
                  _unpaidLeave['total']?.toString() ?? '-',
                  _formatLeaveBalance(_unpaidLeave['halfDayUsed']),
                  _formatLeaveBalance(_unpaidLeave['halfDayTotal']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAccrualPreviewSection(theme),
          const SizedBox(height: 16),
          // Only show half-day details if policy allows half-day leave
          if (_policyLoaded && _allowHalfDays)
            _buildHalfDayDetailsSection(theme),
        ],
      ),
    );
  }

  /// Build the leave policy section
  Widget _buildLeavePolicySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.policy, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CURRENT LEAVE POLICY',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                _loadLeavePolicy();
                if (_policyLoaded) {
                  GlobalNotificationService().showSuccess('Policy refreshed');
                } else {
                  GlobalNotificationService().showWarning(
                    'Retrying policy load...',
                  );
                }
              },
              icon: _policyLoaded
                  ? Icon(
                      Icons.refresh,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
              tooltip: _policyLoaded
                  ? 'Refresh Policy'
                  : 'Retry Loading Policy',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Enhanced policy summary with key entitlements
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Policy Summary',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Key entitlements display - use actual policy data
              _buildPolicyEntitlementsFromData(),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Default Policy - Nepal',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap the policy card below to view full details and rules',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Leave policy widget
        const LeavePolicyInfoWidget(showFullDetails: false),
      ],
    );
  }

  /// Build policy entitlements from actual policy data
  Widget _buildPolicyEntitlementsFromData() {
    if (!_policyLoaded || _currentPolicy == null) {
      // Show loading state if policy not loaded yet
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPolicyEntitlementItem(
                  'Annual Leave',
                  _policyLoaded ? 'Error' : 'Loading...',
                  Colors.blue,
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPolicyEntitlementItem(
                  'Sick Leave',
                  _policyLoaded ? 'Error' : 'Loading...',
                  Colors.red,
                  Icons.health_and_safety,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPolicyEntitlementItem(
                  'Casual Leave',
                  _policyLoaded ? 'Error' : 'Loading...',
                  Colors.orange,
                  Icons.event_available,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPolicyEntitlementItem(
                  'Maternity',
                  _policyLoaded ? 'Error' : 'Loading...',
                  Colors.pink,
                  Icons.child_care,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final leaveTypes =
        _currentPolicy!['leaveTypes'] as Map<String, dynamic>? ?? {};

    // Get the main leave types for display
    final annualDays = leaveTypes['annualLeave']?['totalDays'] ?? 0;
    final sickDays = leaveTypes['sickLeave']?['totalDays'] ?? 0;
    final casualDays = leaveTypes['casualLeave']?['totalDays'] ?? 0;
    final maternityDays = leaveTypes['maternityLeave']?['totalDays'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPolicyEntitlementItem(
                'Annual Leave',
                '$annualDays days',
                Colors.blue,
                Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPolicyEntitlementItem(
                'Sick Leave',
                '$sickDays days',
                Colors.red,
                Icons.health_and_safety,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPolicyEntitlementItem(
                'Casual Leave',
                '$casualDays days',
                Colors.orange,
                Icons.event_available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPolicyEntitlementItem(
                'Maternity',
                '$maternityDays days',
                Colors.pink,
                Icons.child_care,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build policy entitlement item
  Widget _buildPolicyEntitlementItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the accrual preview section
  Widget _buildAccrualPreviewSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Monthly Accrual Preview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (_isLoadingAccrualPreview)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _loadAccrualPreview,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh accrual preview',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_accrualPreview != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAccrualPreviewItem(
                  'This Month',
                  '${_accrualPreview!['estimatedAccrual']?.toStringAsFixed(2) ?? '0.00'}h',
                  '${_accrualPreview!['dailyBreakdown']?.length ?? 0} days',
                  Colors.green,
                ),
                _buildAccrualPreviewItem(
                  'Accrual Rate',
                  '${_accrualPreview!['accrualFactor']?.toStringAsFixed(3) ?? '0.000'}',
                  'per hour worked',
                  Colors.blue,
                ),
                _buildAccrualPreviewItem(
                  'Employee Type',
                  _accrualPreview!['employeeType']?.toString() ?? 'Unknown',
                  _accrualPreview!['isShiftworker'] == true
                      ? 'Shiftworker'
                      : 'Regular',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Based on your working hours, you accrue approximately ${_accrualPreview!['estimatedAccrual']?.toStringAsFixed(2) ?? '0.00'} hours of annual leave this month.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            Text(
              'Tap refresh to see your monthly accrual preview based on your working hours.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build accrual preview item
  Widget _buildAccrualPreviewItem(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Load accrual preview for current month
  Future<void> _loadAccrualPreview() async {
    if (_isLoadingAccrualPreview || _employeeId == null) return;

    setState(() {
      _isLoadingAccrualPreview = true;
    });

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final startDate =
          '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}-${monthStart.day.toString().padLeft(2, '0')}';
      final endDate =
          '${monthEnd.year}-${monthEnd.month.toString().padLeft(2, '0')}-${monthEnd.day.toString().padLeft(2, '0')}';

      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final preview = await apiService.getAccrualPreview(
        employeeId: _employeeId!,
        startDate: startDate,
        endDate: endDate,
        leaveType: 'annualLeave',
      );

      if (mounted) {
        setState(() {
          _accrualPreview = preview;
        });
      }
    } catch (e) {
      Logger.error('Error loading accrual preview: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAccrualPreview = false;
        });
      }
    }
  }

  /// Build the half-day details section
  Widget _buildHalfDayDetailsSection(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Half-Day Leave Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _showHalfDayDetails = !_showHalfDayDetails;
                });
              },
              icon: Icon(
                _showHalfDayDetails ? Icons.expand_less : Icons.expand_more,
                color: Colors.orange[700],
              ),
              tooltip: _showHalfDayDetails ? 'Hide Details' : 'Show Details',
            ),
          ],
        ),
        if (_showHalfDayDetails) ...[
          const SizedBox(height: 16),
          // Half-day details - first row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHalfDayDetailItem(
                'Annual',
                _formatLeaveBalance(_annualLeave['halfDayUsed']),
                _formatLeaveBalance(_annualLeave['halfDayTotal']),
                Colors.blue,
              ),
              _buildHalfDayDetailItem(
                'Sick',
                _formatLeaveBalance(_sickLeave['halfDayUsed']),
                _formatLeaveBalance(_sickLeave['halfDayTotal']),
                Colors.red,
              ),
              _buildHalfDayDetailItem(
                'Casual',
                _formatLeaveBalance(_casualLeave['halfDayUsed']),
                _formatLeaveBalance(_casualLeave['halfDayTotal']),
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Half-day details - second row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHalfDayDetailItem(
                'Maternity',
                _formatLeaveBalance(_maternityLeave['halfDayUsed']),
                _formatLeaveBalance(_maternityLeave['halfDayTotal']),
                Colors.pink,
              ),
              _buildHalfDayDetailItem(
                'Paternity',
                _formatLeaveBalance(_paternityLeave['halfDayUsed']),
                _formatLeaveBalance(_paternityLeave['halfDayTotal']),
                Colors.indigo,
              ),
              _buildHalfDayDetailItem(
                'Unpaid',
                _formatLeaveBalance(_unpaidLeave['halfDayUsed']),
                _formatLeaveBalance(_unpaidLeave['halfDayTotal']),
                Colors.grey,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Build the cash-out section
  Widget _buildCashOutSection(ThemeData theme) {
    return Consumer<LeaveRequestProvider>(
      builder: (context, leaveProvider, child) {
        // Get annual leave balance
        final annualLeaveData = leaveProvider.leaveBalances['annual'];
        final annualLeaveBalance =
            annualLeaveData?['available']?.toDouble() ?? 0.0;

        // Calculate available cash-out (minimum 4 weeks = 160 hours must remain)
        const minRequiredBalance = 160.0; // 4 weeks * 40 hours
        final availableForCashOut = (annualLeaveBalance - minRequiredBalance)
            .clamp(0.0, double.infinity);
        final availableDays =
            availableForCashOut / 8; // Assuming 8 hours per day

        return ModernCard(
          accentColor: Colors.orange,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cash Out Annual Leave',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Available Cash-Out Balance Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: availableForCashOut > 0
                        ? Colors.green[50]
                        : Colors.orange[50],
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
                            availableForCashOut > 0
                                ? Icons.check_circle
                                : Icons.warning,
                            color: availableForCashOut > 0
                                ? Colors.green[600]
                                : Colors.orange[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available Cash-Out Balance',
                            style: TextStyle(
                              color: availableForCashOut > 0
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Annual Leave',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${annualLeaveBalance.toStringAsFixed(1)} hours (${(annualLeaveBalance / 8).toStringAsFixed(1)} days)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available for Cash-Out',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  availableForCashOut > 0
                                      ? '${availableForCashOut.toStringAsFixed(1)} hours (${availableDays.toStringAsFixed(1)} days)'
                                      : '0 hours (0 days)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
                ),

                const SizedBox(height: 12),
                Text(
                  'Convert your annual leave hours to cash payment (requires approval)',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: availableForCashOut > 0
                      ? _showCashOutDialog
                      : null,
                  icon: const Icon(Icons.monetization_on),
                  label: Text(
                    availableForCashOut > 0
                        ? 'Request Cash-Out'
                        : 'Not Eligible for Cash-Out',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: availableForCashOut > 0
                        ? Colors.orange[600]
                        : Colors.grey[400],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show cash-out dialog
  void _showCashOutDialog() {
    if (_employeeId == null) {
      GlobalNotificationService().showError(
        'Unable to load employee information',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EmployeeCashOutDialog(
        employeeId: _employeeId!,
        onSubmit: _submitCashOutRequest,
      ),
    );
  }

  /// Submit cash-out request
  Future<void> _submitCashOutRequest(double hours, String agreementText) async {
    try {
      // Check if employeeId is available
      if (_employeeId == null) {
        Logger.debug('Employee ID is null, attempting to fetch...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final leaveProvider = Provider.of<LeaveRequestProvider>(
          context,
          listen: false,
        );

        if (authProvider.user?['_id'] != null) {
          final employeeId = await leaveProvider.fetchEmployeeIdByUserId(
            authProvider.user!['_id'],
          );
          setState(() {
            _employeeId = employeeId;
          });
        }

        if (_employeeId == null) {
          GlobalNotificationService().showError(
            'Unable to load employee information. Please try again.',
          );
          return;
        }
      }

      Logger.debug(
        'Submitting cash-out request for employee: $_employeeId, hours: $hours',
      );

      final apiService = ApiService(baseUrl: ApiConfig.baseUrl);
      final result = await apiService.requestLeaveCashOut(
        employeeId: _employeeId!,
        hoursToCashOut: hours,
        agreementText: agreementText,
      );

      Logger.debug('Cash-out request result: $result');

      if (result['success']) {
        GlobalNotificationService().showSuccess(
          'Cash-out request submitted successfully. Pending admin approval.',
        );
        // Close the dialog if it's still open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        final errorMessage =
            result['message'] ?? 'Failed to submit cash-out request';
        GlobalNotificationService().showError(errorMessage);
      }
    } catch (e) {
      Logger.debug('Error submitting cash-out request: $e');
      GlobalNotificationService().showError('Error: $e');
    }
  }

  /// Build the leave request form
  Widget _buildLeaveRequestForm(ThemeData theme) {
    return ModernCard(
      accentColor: theme.colorScheme.tertiary,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Leave Request',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildLeaveTypeDropdown(),
            const SizedBox(height: 16),
            _buildHalfDayToggle(),
            const SizedBox(height: 16),
            _buildDateSelectionSection(theme),
            const SizedBox(height: 8),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leave requests must be submitted at least 1 day in advance.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Same-day leave requests must be submitted before 9:00 AM.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuidanceText(),
            const SizedBox(height: 16),
            _buildReasonField(),
            const SizedBox(height: 24),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  /// Build the leave type dropdown
  Widget _buildLeaveTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLeaveType,
      decoration: InputDecoration(
        labelText: 'Leave Type',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _leaveTypes.map((String type) {
        return DropdownMenuItem<String>(value: type, child: Text(type));
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedLeaveType = newValue;
          });
        }
      },
    );
  }

  /// Load company leave policy to check if half-day leave is enabled
  Future<void> _loadLeavePolicy() async {
    try {
      Logger.debug('LeaveRequestScreen: Starting policy load...');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/leave-policies/simple'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${Provider.of<AuthProvider>(context, listen: false).token}',
        },
      );

      Logger.debug(
        'LeaveRequestScreen: Policy API response status: ${response.statusCode}',
      );
      Logger.debug(
        'LeaveRequestScreen: Policy API response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        Logger.debug(
          'LeaveRequestScreen: Parsed policy response: $responseData',
        );

        // Handle both direct array response and wrapped response
        List<dynamic> data;
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        Logger.debug('LeaveRequestScreen: Extracted policy data: $data');

        if (data.isNotEmpty) {
          // Find the default policy
          final defaultPolicy = data.firstWhere(
            (policy) => policy['isDefault'] == true,
            orElse: () => data.first, // Use first policy if no default found
          );

          Logger.debug(
            'LeaveRequestScreen: Found default policy: $defaultPolicy',
          );

          final rules = defaultPolicy['rules'] ?? {};
          Logger.debug('LeaveRequestScreen: Policy rules: $rules');

          setState(() {
            _currentPolicy = defaultPolicy; // Store the full policy
            _allowHalfDays = rules['allowHalfDays'] ?? false;
            _policyLoaded = true;

            // If half-day leave is disabled in policy, reset the half-day state
            if (!_allowHalfDays && _isHalfDay) {
              _isHalfDay = false;
              _startDate = null;
              _endDate = null;
              _halfDayLeaveTime = null;
            }
          });

          Logger.debug(
            'LeaveRequestScreen: Policy loaded successfully - allowHalfDays: $_allowHalfDays',
          );
          Logger.debug(
            'LeaveRequestScreen: Policy loaded successfully - policyLoaded: $_policyLoaded',
          );
        } else {
          Logger.debug('LeaveRequestScreen: No policies found in response');
          setState(() {
            _policyLoaded = true; // Set to true to avoid infinite loading
            _currentPolicy = null; // Clear policy data
          });
        }
      } else {
        Logger.debug(
          'LeaveRequestScreen: Policy API error - status: ${response.statusCode}',
        );
        setState(() {
          _policyLoaded = true; // Set to true to avoid infinite loading
        });
      }
    } catch (e) {
      Logger.error('LeaveRequestScreen: Error loading leave policy: $e');
      setState(() {
        _policyLoaded =
            true; // Set to true even on error to avoid infinite loading
      });
    }
  }

  /// Select half-day leave time
  Future<void> _selectHalfDayLeaveTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _halfDayLeaveTime ?? const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Select time to leave for half-day',
    );

    if (picked != null && picked != _halfDayLeaveTime) {
      setState(() {
        _halfDayLeaveTime = picked;
      });
    }
  }

  /// Build the half-day toggle (only shown if company policy allows half-day leave)
  Widget _buildHalfDayToggle() {
    // Only show the toggle if the company policy allows half-day leave
    if (!_policyLoaded || !_allowHalfDays) {
      return const SizedBox.shrink(); // Hide the toggle
    }

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Half Day Leave'),
          subtitle: const Text('Request half-day leave instead of full day'),
          value: _isHalfDay,
          onChanged: (value) {
            setState(() {
              _isHalfDay = value;
              if (value) {
                _startDate = DateTime.now();
                _endDate = null;
                // Set default leave time to 12:00 PM if not set
                _halfDayLeaveTime ??= const TimeOfDay(hour: 12, minute: 0);
              } else {
                _startDate = null;
                _endDate = null;
                _halfDayLeaveTime = null;
              }
            });

            if (value && _startDate != null) {
              final today = DateTime.now();
              final todayOnly = DateTime(today.year, today.month, today.day);
              final startDateOnly = DateTime(
                _startDate!.year,
                _startDate!.month,
                _startDate!.day,
              );
              if (startDateOnly.isAtSameMomentAs(todayOnly)) {
                _fetchCurrentAttendanceStatus();
              }
            }
          },
        ),
        // Show time picker when half-day is enabled
        if (_isHalfDay) ...[
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Leave Time'),
            subtitle: Text(
              _halfDayLeaveTime != null
                  ? 'Leave at ${_halfDayLeaveTime!.format(context)}'
                  : 'Select time to leave',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: _selectHalfDayLeaveTime,
          ),
        ],
      ],
    );
  }

  /// Build the date selection section
  Widget _buildDateSelectionSection(ThemeData theme) {
    return _isHalfDay
        ? _buildHalfDayDateField(theme)
        : _buildFullDayDateFields(theme);
  }

  /// Build half-day date field
  Widget _buildHalfDayDateField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: const Icon(Icons.calendar_today),
            helperText: 'Current date automatically set for half-day leave',
          ),
          controller: TextEditingController(
            text: _startDate != null ? _formatDateForAPI(_startDate!) : '',
          ),
          onTap: () => _selectDate(context, true),
        ),
        const SizedBox(height: 8),
        Text(
          '📅 Half-day leave automatically uses today\'s date (${TimeUtils.formatReadableDate(DateTime.now(), user: Provider.of<AuthProvider>(context, listen: false).user, company: Provider.of<CompanyProvider>(context, listen: false).currentCompany?.toJson())})',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Build full-day date fields
  Widget _buildFullDayDateFields(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Start Date',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(
              text: _startDate != null
                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                  : '',
            ),
            onTap: () => _selectDate(context, true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'End Date',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(
              text: _endDate != null ? _formatDateForAPI(_endDate!) : '',
            ),
            onTap: () => _selectDate(context, false),
          ),
        ),
      ],
    );
  }

  /// Build the guidance text
  Widget _buildGuidanceText() {
    if (_startDate == null ||
        _startDate!.year != DateTime.now().year ||
        _startDate!.month != DateTime.now().month ||
        _startDate!.day != DateTime.now().day) {
      return const SizedBox.shrink();
    }

    final guidance = _getTodayLeaveGuidance();
    final isWarning = guidance.contains('⚠️');
    final isSuccess = guidance.contains('✅');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.orange.withValues(alpha: 0.1)
            : isSuccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        border: Border.all(
          color: isWarning
              ? Colors.orange
              : isSuccess
              ? Colors.green
              : Colors.blue,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isWarning
                ? Icons.warning
                : isSuccess
                ? Icons.check_circle
                : Icons.info,
            color: isWarning
                ? Colors.orange
                : isSuccess
                ? Colors.green
                : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              guidance,
              style: TextStyle(
                color: isWarning
                    ? Colors.orange[800]
                    : isSuccess
                    ? Colors.green[800]
                    : Colors.blue[800],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the reason field
  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      decoration: InputDecoration(
        labelText: 'Reason',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a reason';
        }
        return null;
      },
    );
  }

  /// Build the submit button
  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLeaveRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator()
            : const Text('Submit Request'),
      ),
    );
  }

  /// Build the Company Calendar tab content
  Widget _buildCompanyCalendarTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Calendar Information
          if (_companyCalendarLoaded) ...[
            ModernCard(
              accentColor: ThemeUtils.getSafeHeaderColor(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: ThemeUtils.getSafeHeaderColor(theme),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Company Calendar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ThemeUtils.getSafeHeaderColor(theme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Upcoming Holidays
                  if (_companyHolidays.isNotEmpty) ...[
                    Text(
                      'Upcoming Holidays',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._companyHolidays
                        .where((holiday) {
                          try {
                            // For multi-day holidays, check if start date is in the future
                            if (holiday['startDate'] != null &&
                                holiday['endDate'] != null) {
                              final startDate = DateTime.parse(
                                holiday['startDate'],
                              );
                              return startDate.isAfter(
                                DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                              );
                            } else {
                              // For single-day holidays, check the date
                              final holidayDate = DateTime.parse(
                                holiday['date'],
                              );
                              return holidayDate.isAfter(
                                DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            return false;
                          }
                        })
                        .take(5)
                        .map((holiday) {
                          // Format date display for multi-day holidays
                          String dateDisplay;
                          if (holiday['startDate'] != null &&
                              holiday['endDate'] != null) {
                            final startDate = DateTime.parse(
                              holiday['startDate'],
                            );
                            final endDate = DateTime.parse(holiday['endDate']);
                            final startFormatted =
                                '${startDate.day}/${startDate.month}/${startDate.year}';
                            final endFormatted =
                                '${endDate.day}/${endDate.month}/${endDate.year}';
                            dateDisplay = '$startFormatted - $endFormatted';
                          } else {
                            final holidayDate = DateTime.parse(holiday['date']);
                            dateDisplay =
                                '${holidayDate.day}/${holidayDate.month}/${holidayDate.year}';
                          }

                          return _buildCalendarEventItem(
                            holiday['name'] ?? 'Holiday',
                            dateDisplay,
                            holiday['description'] ?? '',
                            ThemeUtils.getStatusChipColor('error', theme),
                            Icons.celebration,
                          );
                        }),
                  ],

                  // Upcoming Non-Working Days
                  if (_companyNonWorkingDays.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Upcoming Non-Working Days',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._companyNonWorkingDays
                        .where((nwd) {
                          try {
                            final startDate = DateTime.parse(nwd['startDate']);
                            return startDate.isAfter(
                              DateTime.now().subtract(const Duration(days: 1)),
                            );
                          } catch (e) {
                            return false;
                          }
                        })
                        .take(5)
                        .map(
                          (nwd) => _buildCalendarEventItem(
                            nwd['name'] ?? 'Non-Working Day',
                            nwd['startDate'],
                            nwd['reason'] ?? '',
                            Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            Icons.block,
                          ),
                        ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    '💡 Tip: Check the calendar below to avoid applying for leave on holidays or non-working days.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Leave Calendar
          ModernCard(
            accentColor: theme.colorScheme.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Calendar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: onDaySelected,
                  eventLoader: getEventsForDay,
                  calendarFormat: CalendarFormat.month,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      // Get company calendar provider to check day types
                      final companyCalendarProvider =
                          Provider.of<CompanyCalendarProvider>(
                            context,
                            listen: false,
                          );

                      // Check if this day is a working day
                      bool isWorkingDay = false;
                      if (companyCalendarProvider.calendar != null &&
                          companyCalendarProvider.calendar!['workingDays'] !=
                              null) {
                        final workingDays = List<String>.from(
                          companyCalendarProvider.calendar!['workingDays'],
                        );
                        final dayName = _getDayName(day.weekday);
                        isWorkingDay = workingDays.contains(dayName);
                      }

                      // Check if this day is a holiday
                      bool isHoliday = false;
                      if (_companyCalendarLoaded &&
                          _companyHolidays.isNotEmpty) {
                        final holiday = _getHolidayForDate(day);
                        isHoliday = holiday != null;
                      }

                      // Check if this day is a non-working day
                      bool isNonWorkingDay = false;
                      if (companyCalendarProvider.calendar != null &&
                          companyCalendarProvider.calendar!['nonWorkingDays'] !=
                              null) {
                        isNonWorkingDay = _isNonWorkingDay(
                          day,
                          companyCalendarProvider,
                        );
                      }

                      // Check if this day is an override working day
                      bool isOverrideWorkingDay = companyCalendarProvider
                          .isOverrideWorkingDay(day);

                      // Determine styling based on day type (same as admin calendar)
                      Color backgroundColor;
                      Color borderColor;
                      Color textColor;
                      FontWeight fontWeight;
                      String? badgeText;

                      if (isOverrideWorkingDay) {
                        // Override working day: Blue background with blue border
                        backgroundColor = Colors.blue.withValues(alpha: 0.25);
                        borderColor = Colors.blue[700]!;
                        textColor = Colors.blue[900]!;
                        fontWeight = FontWeight.bold;
                        badgeText = 'O'; // Override indicator
                      } else if (isHoliday) {
                        // Holiday: Red background with red border
                        backgroundColor = Colors.red.withValues(alpha: 0.2);
                        borderColor = Colors.red;
                        textColor = Colors.red[800]!;
                        fontWeight = FontWeight.bold;
                      } else if (isNonWorkingDay) {
                        // Non-working day: Orange background with orange border
                        backgroundColor = Colors.orange.withValues(alpha: 0.2);
                        borderColor = Colors.orange;
                        textColor = Colors.orange[800]!;
                        fontWeight = FontWeight.w600;
                      } else if (isWorkingDay) {
                        // Working day: Green background with green border
                        backgroundColor = Colors.green.withValues(alpha: 0.1);
                        borderColor = Colors.green.withValues(alpha: 0.3);
                        textColor = Colors.green[700]!;
                        fontWeight = FontWeight.w600;
                      } else {
                        // Non-working day (weekend): Red background with red border
                        backgroundColor = Colors.red.withValues(alpha: 0.1);
                        borderColor = Colors.red.withValues(alpha: 0.3);
                        textColor = Colors.red[700]!;
                        fontWeight = FontWeight.normal;
                      }

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                            width: isHoliday || isOverrideWorkingDay
                                ? 2
                                : 1, // Thicker border for holidays and overrides
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: fontWeight,
                                ),
                              ),
                            ),
                            if (badgeText != null)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();

                      // Separate events by type
                      final leaveEvents = events
                          .where(
                            (e) =>
                                e is Map<String, dynamic> && e['type'] == null,
                          )
                          .toList();
                      final holidayEvents = events
                          .where(
                            (e) =>
                                e is Map<String, dynamic> &&
                                e['type'] == 'holiday',
                          )
                          .toList();
                      final nonWorkingDayEvents = events
                          .where(
                            (e) =>
                                e is Map<String, dynamic> &&
                                e['type'] == 'nonWorkingDay',
                          )
                          .toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show leave request markers
                          if (leaveEvents.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: leaveEvents.take(3).map<Widget>((
                                event,
                              ) {
                                final leaveType =
                                    (event is Map<String, dynamic>
                                        ? event['leaveType']
                                        : '') ??
                                    '';
                                final status =
                                    (event is Map<String, dynamic>
                                        ? event['status']
                                        : 'pending') ??
                                    'pending';

                                // Different marker styles based on status
                                Color markerColor;
                                double markerSize;
                                BoxBorder? markerBorder;

                                switch (status.toString().toLowerCase()) {
                                  case 'approved':
                                    markerColor =
                                        _leaveTypeColors[leaveType] ??
                                        Colors.black;
                                    markerSize = 8.0;
                                    markerBorder = null;
                                    break;
                                  case 'rejected':
                                    markerColor = Colors.red;
                                    markerSize = 6.0;
                                    markerBorder = Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    );
                                    break;
                                  case 'pending':
                                    markerColor = Colors.orange;
                                    markerSize = 7.0;
                                    markerBorder = null;
                                    break;
                                  default:
                                    markerColor = Colors.grey;
                                    markerSize = 6.0;
                                    markerBorder = null;
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.0,
                                  ),
                                  width: markerSize,
                                  height: markerSize,
                                  decoration: BoxDecoration(
                                    color: markerColor,
                                    shape: BoxShape.circle,
                                    border: markerBorder,
                                  ),
                                );
                              }).toList(),
                            ),

                          // Show holiday markers
                          if (holidayEvents.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[400],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'H',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Show non-working day markers
                          if (nonWorkingDayEvents.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'N',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
                const SizedBox(height: 16),

                // Simplified Day Type Legend (matching admin style)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _SimpleDayTypeLegend(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.1,
                            ),
                            borderColor: Colors.green.withValues(alpha: 0.3),
                            label: 'Working Day',
                          ),
                          _SimpleDayTypeLegend(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            borderColor: Colors.red.withValues(alpha: 0.3),
                            label: 'Holiday / Weekend',
                          ),
                          _SimpleDayTypeLegend(
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.2,
                            ),
                            borderColor: Colors.orange,
                            label: 'Non-Working',
                          ),
                          _SimpleDayTypeLegend(
                            backgroundColor: Colors.blue.withValues(
                              alpha: 0.25,
                            ),
                            borderColor: Colors.blue[700]!,
                            label: 'Override',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '💡 Tap any day to view details and your leave requests',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Selected Day Details Panel (Read-only for employees)
          if (_selectedDay != null)
            _buildSelectedDayDetailsPanel(_selectedDay!),
        ],
      ),
    );
  }

  /// Build read-only day details panel for employees
  Widget _buildSelectedDayDetailsPanel(DateTime selectedDay) {
    final theme = Theme.of(context);
    final leaveProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );
    final companyCalendarProvider = Provider.of<CompanyCalendarProvider>(
      context,
      listen: false,
    );

    // Get employee's leave requests for this day
    final dayLeaveRequests = _getLeaveRequestsForDay(
      selectedDay,
      leaveProvider,
    );

    // Check day type
    final holiday = _getHolidayForDate(selectedDay);
    final isNonWorkingDay = _isNonWorkingDay(
      selectedDay,
      companyCalendarProvider,
    );
    final isOverrideWorkingDay = _isOverrideWorkingDay(
      selectedDay,
      companyCalendarProvider,
    );
    final isRegularWorkingDay = _isRegularWorkingDay(
      selectedDay,
      companyCalendarProvider,
    );

    // Determine day type and styling
    String dayType;
    IconData dayIcon;
    Color dayColor;
    String? dayDescription;

    if (isOverrideWorkingDay) {
      dayType = 'Override Working Day';
      dayIcon = Icons.work;
      dayColor = Colors.blue;
      dayDescription = _getOverrideReason(selectedDay, companyCalendarProvider);
    } else if (holiday != null) {
      final holidayType = holiday['type'] ?? 'company';
      dayType = '${_getHolidayTypeDisplayName(holidayType)} Holiday';
      dayIcon = _getHolidayIcon(holiday['type']);
      dayColor = _getHolidayColor(holiday['type']);
      dayDescription = holiday['name'] ?? 'Holiday';
    } else if (isNonWorkingDay) {
      dayType = 'Non-Working Day';
      dayIcon = Icons.event_busy;
      dayColor = Colors.orange;
      dayDescription = _getNonWorkingDayName(selectedDay);
    } else if (isRegularWorkingDay) {
      dayType = 'Regular Working Day';
      dayIcon = Icons.event_available;
      dayColor = Colors.green;
      dayDescription = 'Standard working day';
    } else {
      dayType = 'Weekend / Non-Working Day';
      dayIcon = Icons.weekend;
      dayColor = Colors.grey;
      dayDescription = 'Not in working days list';
    }

    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(dayIcon, color: dayColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer2<AuthProvider, CompanyProvider>(
                        builder: (context, authProvider, companyProvider, _) {
                          final user = authProvider.user;
                          final company = companyProvider.currentCompany
                              ?.toJson();
                          return Text(
                            TimeUtils.formatReadableDate(
                              selectedDay,
                              user: user,
                              company: company,
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayType,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: dayColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey[600],
                  tooltip: 'Clear Selection',
                  onPressed: () {
                    setState(() {
                      _selectedDay = null;
                    });
                  },
                ),
              ],
            ),

            // Day Description
            if (dayDescription != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dayColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: dayColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dayDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: dayColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Holiday details (if holiday)
            if (holiday != null) ...[
              if (holiday['description'] != null &&
                  holiday['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    holiday['description'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (holiday['type'] != null)
                      Chip(
                        label: Text(
                          _getHolidayTypeDisplayName(holiday['type']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: dayColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: dayColor.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (holiday['isRecurring'] == true)
                      Chip(
                        label: Text(
                          'Recurring',
                          style: theme.textTheme.bodySmall,
                        ),
                        backgroundColor: dayColor.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],

            // Employee's Leave Requests for this day
            if (dayLeaveRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Your Leave Requests',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...dayLeaveRequests.map((request) {
                final status =
                    request['status']?.toString().toLowerCase() ?? 'pending';
                final leaveType = request['leaveType'] ?? 'Leave';
                final statusColor = _getStatusColor(request['status']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getLeaveStatusIcon(status),
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leaveType,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                if (request['startDate'] != null &&
                                    request['endDate'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatLeaveDateRange(
                                      request['startDate'],
                                      request['endDate'],
                                      context,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (request['reason'] != null &&
                                request['reason'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                request['reason'],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper method to get leave requests for a specific day
  List<Map<String, dynamic>> _getLeaveRequestsForDay(
    DateTime day,
    LeaveRequestProvider leaveProvider,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final requests = <Map<String, dynamic>>[];

    for (final request in leaveProvider.leaveRequests) {
      try {
        final startDate = _parseDateForComparison(request['startDate']);
        final endDate = _parseDateForComparison(request['endDate']);
        final normalizedStartDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final normalizedEndDate = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        );

        // Check if the day falls within the leave request range
        if (normalizedDay.isAtSameMomentAs(normalizedStartDate) ||
            normalizedDay.isAtSameMomentAs(normalizedEndDate) ||
            (normalizedDay.isAfter(normalizedStartDate) &&
                normalizedDay.isBefore(normalizedEndDate))) {
          requests.add(request);
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return requests;
  }

  /// Helper method to get holiday for a specific date
  Map<String, dynamic>? _getHolidayForDate(DateTime day) {
    if (!_companyCalendarLoaded || _companyHolidays.isEmpty) return null;

    final dayDate = DateTime(day.year, day.month, day.day);

    for (final holiday in _companyHolidays) {
      try {
        // Check if holiday is active
        if (holiday['isActive'] == false) continue;

        // Check for multi-day holidays
        if (holiday['startDate'] != null && holiday['endDate'] != null) {
          final startDate = DateTime.parse(holiday['startDate']);
          final endDate = DateTime.parse(holiday['endDate']);
          final startDateOnly = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          final endDateOnly = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
          );

          if (dayDate.isAtSameMomentAs(startDateOnly) ||
              dayDate.isAtSameMomentAs(endDateOnly) ||
              (dayDate.isAfter(startDateOnly) &&
                  dayDate.isBefore(endDateOnly))) {
            return holiday;
          }
        } else if (holiday['date'] != null) {
          // Single-day holiday
          final holidayDate = DateTime.parse(holiday['date']);
          final holidayDateOnly = DateTime(
            holidayDate.year,
            holidayDate.month,
            holidayDate.day,
          );

          if (dayDate.isAtSameMomentAs(holidayDateOnly)) {
            return holiday;
          }
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return null;
  }

  /// Helper method to check if a day is a non-working day
  bool _isNonWorkingDay(DateTime day, CompanyCalendarProvider provider) {
    if (provider.calendar == null ||
        provider.calendar!['nonWorkingDays'] == null) {
      return false;
    }

    final nonWorkingDays = List<Map<String, dynamic>>.from(
      provider.calendar!['nonWorkingDays'],
    );
    final dayDate = DateTime(day.year, day.month, day.day);

    for (final nwd in nonWorkingDays) {
      try {
        final startDate = DateTime.parse(nwd['startDate']);
        final endDate = DateTime.parse(nwd['endDate'] ?? nwd['startDate']);
        final startDateOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

        if (dayDate.isAtSameMomentAs(startDateOnly) ||
            dayDate.isAtSameMomentAs(endDateOnly) ||
            (dayDate.isAfter(startDateOnly) && dayDate.isBefore(endDateOnly))) {
          return true;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return false;
  }

  /// Helper method to check if a day is an override working day
  bool _isOverrideWorkingDay(DateTime day, CompanyCalendarProvider provider) {
    return provider.isOverrideWorkingDay(day);
  }

  /// Helper method to check if a day is a regular working day
  bool _isRegularWorkingDay(DateTime day, CompanyCalendarProvider provider) {
    if (provider.calendar == null) return false;

    final workingDays = provider.calendar!['workingDays'];
    if (workingDays == null) return false;

    final workingDaysList = List<String>.from(workingDays);
    final dayName = _getDayName(day.weekday);

    return workingDaysList.contains(dayName);
  }

  /// Helper method to get day name from weekday number
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  /// Helper method to get override reason
  String? _getOverrideReason(DateTime day, CompanyCalendarProvider provider) {
    if (provider.calendar == null ||
        provider.calendar!['overrideWorkingDays'] == null) {
      return null;
    }

    final overrides = List<Map<String, dynamic>>.from(
      provider.calendar!['overrideWorkingDays'],
    );
    for (final override in overrides) {
      try {
        final overrideDate = DateTime.parse(override['date']);
        if (overrideDate.year == day.year &&
            overrideDate.month == day.month &&
            overrideDate.day == day.day) {
          return override['reason']?.toString().isEmpty == false
              ? override['reason']
              : 'No reason provided';
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return null;
  }

  /// Helper method to get non-working day name
  String? _getNonWorkingDayName(DateTime day) {
    if (!_companyCalendarLoaded || _companyNonWorkingDays.isEmpty) return null;

    final dayDate = DateTime(day.year, day.month, day.day);

    for (final nwd in _companyNonWorkingDays) {
      try {
        final startDate = DateTime.parse(nwd['startDate']);
        final endDate = DateTime.parse(nwd['endDate'] ?? nwd['startDate']);
        final startDateOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

        if (dayDate.isAtSameMomentAs(startDateOnly) ||
            dayDate.isAtSameMomentAs(endDateOnly) ||
            (dayDate.isAfter(startDateOnly) && dayDate.isBefore(endDateOnly))) {
          return nwd['name'] ?? 'Company Non-Working Day';
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    return null;
  }

  /// Helper method to get holiday type display name
  String _getHolidayTypeDisplayName(String? type) {
    switch (type?.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'company':
        return 'Company';
      case 'religious':
        return 'Religious';
      default:
        return 'Company';
    }
  }

  /// Helper method to get holiday icon
  IconData _getHolidayIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'public':
        return Icons.flag;
      case 'company':
        return Icons.celebration;
      case 'religious':
        return Icons.church;
      default:
        return Icons.celebration;
    }
  }

  /// Helper method to get holiday color
  Color _getHolidayColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'public':
        return Colors.blue;
      case 'company':
        return Colors.red;
      case 'religious':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }

  /// Helper method to get leave status icon
  IconData _getLeaveStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  /// Helper method to format leave date range
  String _formatLeaveDateRange(
    dynamic startDate,
    dynamic endDate,
    BuildContext context,
  ) {
    try {
      final start = _parseDateForComparison(startDate);
      final end = _parseDateForComparison(endDate);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyProvider = Provider.of<CompanyProvider>(
        context,
        listen: false,
      );
      final user = authProvider.user;
      final company = companyProvider.currentCompany?.toJson();

      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return TimeUtils.formatReadableDate(
          start,
          user: user,
          company: company,
        );
      } else {
        final startFormatted = TimeUtils.formatReadableDate(
          start,
          user: user,
          company: company,
        );
        final endFormatted = TimeUtils.formatReadableDate(
          end,
          user: user,
          company: company,
        );
        // Extract just the date part for start (without year if same year)
        if (start.year == end.year) {
          final startDateOnly = DateFormat('MMM d').format(start);
          return '$startDateOnly - $endFormatted';
        } else {
          return '$startFormatted - $endFormatted';
        }
      }
    } catch (e) {
      return '';
    }
  }

  /// Build the Leave History tab content
  Widget _buildLeaveHistoryTab() {
    final theme = Theme.of(context);
    final leaveProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave History',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Status legend
          Row(
            children: const [
              _StatusLegend(
                color: Colors.green,
                label: 'Approved',
                size: 12.0,
                hasBorder: false,
                isText: false,
              ),
              SizedBox(width: 8),
              _StatusLegend(
                color: Colors.orange,
                label: 'Pending',
                size: 12.0,
                hasBorder: false,
                isText: false,
              ),
              SizedBox(width: 8),
              _StatusLegend(
                color: Colors.red,
                label: 'Rejected',
                size: 12.0,
                hasBorder: false,
                isText: false,
              ),
              SizedBox(width: 8),
              _StatusLegend(
                color: Colors.grey,
                label: 'Other',
                size: 12.0,
                hasBorder: false,
                isText: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (leaveProvider.leaveRequests.isEmpty)
            Center(
              child: Text(
                'No leave requests found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaveProvider.leaveRequests.length,
              itemBuilder: (context, index) {
                final request = leaveProvider.leaveRequests[index];
                final isPending = (request['status'] ?? 'Pending') == 'Pending';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(request['leaveType'] ?? 'N/A'),
                        if (request['isHalfDay'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Text(
                              'Half Day',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // For half-day leaves, show only one date
                          request['isHalfDay'] == true
                              ? _formatDateForDisplay(request['startDate'])
                              : '${_formatDateForDisplay(request['startDate'])} - ${_formatDateForDisplay(request['endDate'])}',
                        ),
                        Text(request['reason'] ?? 'No reason provided'),
                        // Add cancel button for pending requests
                        if (isPending) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () =>
                                  _showCancelDialog(request['_id']),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Cancel Request',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        (request['status'] ?? 'Pending').toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(request['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: _getStatusColor(
                        request['status'],
                      ).withValues(alpha: 0.1),
                      side: BorderSide(
                        color: _getStatusColor(request['status']),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Simple day type legend widget (matching admin style)
class _SimpleDayTypeLegend extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final String label;

  const _SimpleDayTypeLegend({
    required this.backgroundColor,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

/// Status legend widget for calendar markers (kept for leave history tab)
class _StatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double size;
  final bool hasBorder;
  final bool isText;
  final String? text;

  const _StatusLegend({
    super.key,
    required this.color,
    required this.label,
    required this.size,
    required this.hasBorder,
    required this.isText,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isText && text != null)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: Center(
              child: Text(
                text!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: hasBorder
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
