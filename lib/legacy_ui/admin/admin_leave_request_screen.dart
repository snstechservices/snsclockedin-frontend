import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_request_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/global_notification_service.dart';
import '../../utils/time_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class AdminLeaveRequestScreen extends StatefulWidget {
  const AdminLeaveRequestScreen({super.key});

  @override
  State<AdminLeaveRequestScreen> createState() =>
      _AdminLeaveRequestScreenState();
}

class _AdminLeaveRequestScreenState extends State<AdminLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLeaveType = 'Annual Leave';
  bool _isLoading = false;
  bool _isHalfDay = false;
  TimeOfDay? _halfDayLeaveTime;

  final List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Unpaid Leave',
    'Personal Leave',
    'Study Leave',
  ];

  final Map<String, Color> leaveTypeColors = {
    'Annual Leave': Colors.blue,
    'Sick Leave': Colors.red,
    'Casual Leave': Colors.orange,
    'Maternity Leave': Colors.pinkAccent,
    'Paternity Leave': Colors.blueAccent,
    'Unpaid Leave': Colors.grey,
    'Personal Leave': Colors.purple,
    'Study Leave': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // For half-day leaves, automatically set end date same as start date
          if (_isHalfDay) {
            _endDate = picked;
          } else {
            // If end date is before start date, update end date
            if (_endDate != null && _endDate!.isBefore(picked)) {
              _endDate = picked;
            }
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectHalfDayLeaveTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _halfDayLeaveTime ?? const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Select time to leave for half-day',
    );

    if (picked != null) {
      setState(() {
        _halfDayLeaveTime = picked;
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate half-day leave requirements
    if (_isHalfDay) {
      if (_startDate == null) {
        GlobalNotificationService().showError(
          'Please select a date for half-day leave',
        );
        return;
      }
      if (_halfDayLeaveTime == null) {
        GlobalNotificationService().showError(
          'Please select a time to leave for half-day leave',
        );
        return;
      }
      // For half-day, set end date same as start date
      _endDate = _startDate;
    } else {
      if (_startDate == null || _endDate == null) {
        GlobalNotificationService().showError(
          'Please select start and end dates',
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final leaveProvider = Provider.of<LeaveRequestProvider>(
        context,
        listen: false,
      );

      // Format dates in YYYY-MM-DD format to avoid timezone issues
      final startDate = _startDate!;
      final endDate = _isHalfDay ? _startDate! : _endDate!;
      final startDateStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      // Create leave request data
      final leaveRequestData = {
        'leaveType': _selectedLeaveType,
        'startDate': startDateStr,
        'endDate': endDateStr,
        'reason': _reasonController.text.trim(),
        'isHalfDay': _isHalfDay,
        'halfDayLeaveTime': _isHalfDay && _halfDayLeaveTime != null
            ? '${_halfDayLeaveTime!.hour.toString().padLeft(2, '0')}:${_halfDayLeaveTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'role': 'admin', // Mark as admin leave request
      };

      // Submit the leave request
      final result = await leaveProvider.createLeaveRequest(leaveRequestData);

      if (mounted) {
        if (result['success'] == true) {
          // Show success notification
          GlobalNotificationService().showSuccess(
            result['message'] ?? 'Leave request submitted successfully',
          );

          // Show success dialog with better UI
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  const Text('Leave Request Submitted'),
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
                  _buildInfoItem(
                    icon: Icons.admin_panel_settings,
                    text: 'Other admins will review your request',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    icon: Icons.notifications_active,
                    text: 'You\'ll be notified of the decision',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    icon: Icons.info_outline,
                    text: 'You cannot approve your own request',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Go back to leave management
                  },
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
          );
        } else {
          // Show error notification with specific message
          GlobalNotificationService().showError(
            result['message'] ?? 'Failed to submit leave request',
          );

          // Show error dialog with better UI
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 30),
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
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result['message'] ??
                                'Failed to submit leave request',
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Please Check:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCheckItem(
                    icon: Icons.account_balance_wallet,
                    text: 'Your leave balance is sufficient',
                  ),
                  const SizedBox(height: 8),
                  _buildCheckItem(
                    icon: Icons.date_range,
                    text: 'Selected dates are valid',
                  ),
                  const SizedBox(height: 8),
                  _buildCheckItem(
                    icon: Icons.category,
                    text: 'Leave type is available',
                  ),
                  const SizedBox(height: 8),
                  _buildCheckItem(
                    icon: Icons.description,
                    text: 'Reason is properly filled',
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
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to submit leave request: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
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
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.orange[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysDifference = _startDate != null && _endDate != null
        ? _endDate!.difference(_startDate!).inDays + 1
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Leave Request'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      drawer: const AdminSideNavigation(currentRoute: '/leave_management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.purple,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Leave Request',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                Text(
                                  'Submit your leave request for admin review',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.purple,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: Admin leave requests require approval from other admins. You cannot approve your own request.',
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontSize: 13,
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
              const SizedBox(height: 24),

              // Leave Type Selection
              Text(
                'Leave Type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _leaveTypes.map((type) {
                  final isSelected = _selectedLeaveType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLeaveType = type;
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: leaveTypeColors[type]?.withValues(
                      alpha: 0.2,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? leaveTypeColors[type]
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? leaveTypeColors[type]!
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Consumer2<AuthProvider, CompanyProvider>(
                                  builder:
                                      (
                                        context,
                                        authProvider,
                                        companyProvider,
                                        _,
                                      ) {
                                        final user = authProvider.user;
                                        final company = companyProvider
                                            .currentCompany
                                            ?.toJson();
                                        return Text(
                                          _startDate != null
                                              ? TimeUtils.formatReadableDate(
                                                  _startDate!,
                                                  user: user,
                                                  company: company,
                                                )
                                              : 'Select Start Date',
                                          style: TextStyle(
                                            color: _startDate != null
                                                ? Colors.black
                                                : Colors.grey[600],
                                          ),
                                        );
                                      },
                                ),
                              ],
                            ),
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
                          'End Date',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _isHalfDay
                              ? null
                              : () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isHalfDay
                                    ? Colors.grey[200]!
                                    : Colors.grey[300]!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _isHalfDay
                                  ? Colors.grey[100]
                                  : Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: _isHalfDay
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Consumer2<AuthProvider, CompanyProvider>(
                                    builder:
                                        (
                                          context,
                                          authProvider,
                                          companyProvider,
                                          _,
                                        ) {
                                          final user = authProvider.user;
                                          final company = companyProvider
                                              .currentCompany
                                              ?.toJson();
                                          return Text(
                                            _isHalfDay && _startDate != null
                                                ? TimeUtils.formatReadableDate(
                                                    _startDate!,
                                                    user: user,
                                                    company: company,
                                                  )
                                                : _endDate != null
                                                ? TimeUtils.formatReadableDate(
                                                    _endDate!,
                                                    user: user,
                                                    company: company,
                                                  )
                                                : 'Select End Date',
                                            style: TextStyle(
                                              color: _isHalfDay
                                                  ? Colors.grey[500]
                                                  : _endDate != null
                                                  ? Colors.black
                                                  : Colors.grey[600],
                                              fontStyle: _isHalfDay
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                                if (_isHalfDay)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.info_outline,
                                      color: Colors.grey[400],
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_isHalfDay)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Same as start date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duration Display
              if (_startDate != null && _endDate != null)
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
                      Icon(Icons.access_time, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Duration: $daysDifference day${daysDifference != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Half Day Toggle
              Row(
                children: [
                  Switch(
                    value: _isHalfDay,
                    onChanged: (value) {
                      setState(() {
                        _isHalfDay = value;
                        if (value) {
                          // Set default leave time to 12:00 PM if not set
                          _halfDayLeaveTime ??= const TimeOfDay(
                            hour: 12,
                            minute: 0,
                          );
                          // For half-day, set end date same as start date
                          if (_startDate != null) {
                            _endDate = _startDate;
                          }
                        } else {
                          _halfDayLeaveTime = null;
                        }
                      });
                    },
                    activeThumbColor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Half Day Leave',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, color: Colors.orange, size: 20),
                ],
              ),
              // Show time picker when half-day is enabled
              if (_isHalfDay) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectHalfDayLeaveTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _halfDayLeaveTime != null
                              ? 'Leave at ${_halfDayLeaveTime!.format(context)}'
                              : 'Select time to leave',
                          style: TextStyle(
                            color: _halfDayLeaveTime != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Reason Field
              Text(
                'Reason for Leave',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Please provide a detailed reason for your leave request...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for your leave request';
                  }
                  if (value.trim().length < 10) {
                    return 'Reason must be at least 10 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLeaveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Submit Leave Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
