import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/global_notification_service.dart';

class EditPayslipDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final void Function(Map<String, dynamic> payslip) onSave;
  final String? employeeId; // Add employee ID parameter

  const EditPayslipDialog({
    super.key,
    this.initialData,
    required this.onSave,
    this.employeeId,
  });

  @override
  State<EditPayslipDialog> createState() => _EditPayslipDialogState();
}

class _EditPayslipDialogState extends State<EditPayslipDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _grossPayController;
  late TextEditingController _deductionsController;
  late TextEditingController _netPayController;
  late TextEditingController _totalHoursController;
  late TextEditingController _overtimeHoursController;
  late TextEditingController _adminResponseController;
  DateTime? _issueDate;
  DateTime? _periodStart;
  DateTime? _periodEnd;

  // Time-based earnings state
  bool _isFetchingHours = false;
  double? _employeeHourlyRate;
  double _calculatedRegularHours = 0;
  double _calculatedOvertimeHours = 0;

  // Enhanced Income Types with Sub-categories
  final Map<String, List<String>> _incomeSubTypes = {
    'Basic Salary': ['Base Salary'], // Only one option
    'Allowance': [
      'Housing Allowance',
      'Transport Allowance',
      'Meal Allowance',
      'Internet Allowance',
      'Mobile Allowance',
      'Medical Allowance',
      'Education Allowance',
    ],
    'Bonus': [
      'Performance Bonus',
      'Annual Bonus',
      'Project Bonus',
      'Retention Bonus',
      'Festival Bonus',
    ],
    'TDA': ['Travel Daily Allowance'],
    'Overtime': ['Overtime Pay'],
    'Commission': ['Sales Commission', 'Target Commission'],
    'Other': ['Reimbursement', 'Special Payment', 'Arrears'],
  };

  // Enhanced Deduction Types with Sub-categories
  final Map<String, List<String>> _deductionSubTypes = {
    'Tax': ['Income Tax', 'Professional Tax', 'TDS', 'State Tax'],
    'Provident Fund': ['EPF Contribution'],
    'Insurance': [
      'Health Insurance',
      'Life Insurance',
      'Dental Insurance',
      'Accident Insurance',
    ],
    'Loan': ['Employee Loan', 'Advance Salary', 'Emergency Loan'],
    'Other': ['Union Dues', 'Canteen', 'Uniform', 'Miscellaneous'],
  };

  List<Map<String, dynamic>> _deductionsList = [];
  List<Map<String, dynamic>> _incomesList = [];

  // Helper methods to get available types
  List<String> get _defaultIncomeTypes => _incomeSubTypes.keys.toList();
  List<String> get _defaultDeductionTypes => _deductionSubTypes.keys.toList();

  // Helper method to check if Basic Salary already exists
  bool _hasBasicSalary() {
    return _incomesList.any(
      (item) =>
          item['type'] == 'Basic Salary' ||
          item['description'] == 'Base Salary',
    );
  }

  // Helper method to check for duplicate income type-description combinations
  bool _hasDuplicateIncome(String type, String description, int currentIndex) {
    for (int i = 0; i < _incomesList.length; i++) {
      if (i != currentIndex &&
          _incomesList[i]['type'] == type &&
          _incomesList[i]['description'] == description) {
        return true;
      }
    }
    return false;
  }

  // Helper method to check for duplicate deduction type-description combinations
  bool _hasDuplicateDeduction(
    String type,
    String description,
    int currentIndex,
  ) {
    for (int i = 0; i < _deductionsList.length; i++) {
      if (i != currentIndex &&
          _deductionsList[i]['type'] == type &&
          _deductionsList[i]['description'] == description) {
        return true;
      }
    }
    return false;
  }

  // Show warning for duplicate entries
  void _showDuplicateWarning(String message) {
    GlobalNotificationService().showWarning(message);
  }

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _grossPayController = TextEditingController(
      text: data['grossPay']?.toString() ?? '',
    );
    _deductionsController = TextEditingController(
      text: data['deductions']?.toString() ?? '',
    );
    _netPayController = TextEditingController(
      text: data['netPay']?.toString() ?? '',
    );
    _totalHoursController = TextEditingController(
      text: data['totalHours']?.toString() ?? '',
    );
    _overtimeHoursController = TextEditingController(
      text: data['overtimeHours']?.toString() ?? '0',
    );
    _adminResponseController = TextEditingController(
      text: data['adminResponse'] ?? '',
    );
    _issueDate = data['issueDate'] != null
        ? DateTime.tryParse(data['issueDate'])
        : DateTime.now();
    final now = DateTime.now();
    _periodStart = data['periodStart'] != null
        ? DateTime.tryParse(data['periodStart'])
        : DateTime(now.year, now.month, 1);
    _periodEnd = data['periodEnd'] != null
        ? DateTime.tryParse(data['periodEnd'])
        : DateTime(now.year, now.month + 1, 0); // Last day of month
    // Load deductions from initialData if present
    if (data['deductionsList'] != null && data['deductionsList'] is List) {
      _deductionsList = List<Map<String, dynamic>>.from(data['deductionsList']);
      // Ensure backward compatibility - add description if missing
      for (var deduction in _deductionsList) {
        if (deduction['description'] == null && deduction['type'] != null) {
          final type = deduction['type'];
          if (_deductionSubTypes[type] != null &&
              _deductionSubTypes[type]!.isNotEmpty) {
            deduction['description'] = _deductionSubTypes[type]!.first;
          }
        }
      }
    } else {
      _deductionsList = [];
    }
    // Load incomes from initialData if present
    if (data['incomesList'] != null && data['incomesList'] is List) {
      _incomesList = List<Map<String, dynamic>>.from(data['incomesList']);
      // Ensure backward compatibility - add description if missing
      for (var income in _incomesList) {
        if (income['description'] == null && income['type'] != null) {
          final type = income['type'];
          if (_incomeSubTypes[type] != null &&
              _incomeSubTypes[type]!.isNotEmpty) {
            income['description'] = _incomeSubTypes[type]!.first;
          }
        }
      }
    } else {
      _incomesList = [
        {'type': 'Basic Salary', 'description': 'Base Salary', 'amount': ''},
      ];
    }
    _updateGrossPay();
    _updateTotalHours();

    // Auto-fetch work hours if employee ID is provided and no existing totalHours
    if (widget.employeeId != null &&
        (data['totalHours'] == null || data['totalHours'] == 0)) {
      _fetchEmployeeWorkHours();
    }
  }

  @override
  void dispose() {
    _grossPayController.dispose();
    _deductionsController.dispose();
    _netPayController.dispose();
    _totalHoursController.dispose();
    _overtimeHoursController.dispose();
    _adminResponseController.dispose();
    super.dispose();
  }

  void _updateNetPay() {
    final gross = double.tryParse(_grossPayController.text) ?? 0;
    final deductions = double.tryParse(_deductionsController.text) ?? 0;
    final net = gross - deductions;
    _netPayController.text = net.toStringAsFixed(2);
  }

  // Fetch employee work hours from attendance records
  Future<void> _fetchEmployeeWorkHours() async {
    if (widget.employeeId == null || _periodStart == null || _periodEnd == null)
      return;

    setState(() => _isFetchingHours = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) return;

      // First, get employee details to get userId and hourlyRate
      final empResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/employees/${widget.employeeId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (empResponse.statusCode != 200) {
        setState(() => _isFetchingHours = false);
        return;
      }

      final empData = json.decode(empResponse.body);

      // Try to get userId from the response - it might be nested
      final userId = empData['userId'] ?? empData['data']?['userId'];
      _employeeHourlyRate =
          empData['hourlyRate']?.toDouble() ??
          empData['data']?['hourlyRate']?.toDouble();

      if (userId == null) {
        setState(() => _isFetchingHours = false);
        return;
      }

      // Fetch attendance records for the period
      final startDateStr = _periodStart!.toIso8601String().split('T')[0];
      final endDateStr = _periodEnd!.toIso8601String().split('T')[0];

      final attendanceResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/attendance/user/$userId?startDate=$startDateStr&endDate=$endDateStr',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (attendanceResponse.statusCode == 200) {
        final attendanceList = json.decode(attendanceResponse.body) as List;

        double totalHours = 0;
        double overtimeHours = 0;

        for (var record in attendanceList) {
          final workHours = record['totalWorkHours']?.toDouble() ?? 0.0;
          totalHours += workHours;

          // Calculate overtime (assume 8 hours standard work day)
          if (workHours > 8) {
            overtimeHours += (workHours - 8);
          }
        }

        if (mounted) {
          setState(() {
            _calculatedRegularHours = totalHours - overtimeHours;
            _calculatedOvertimeHours = overtimeHours;
            _totalHoursController.text = totalHours.toStringAsFixed(1);
            _overtimeHoursController.text = overtimeHours.toStringAsFixed(1);
            _isFetchingHours = false;
          });

          // Auto-calculate income if hourly rate is available
          if (_employeeHourlyRate != null && _employeeHourlyRate! > 0) {
            _calculateIncomeFromHours();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingHours = false);
      }
    }
  }

  // Calculate income breakdown from fetched hours
  void _calculateIncomeFromHours() {
    if (_employeeHourlyRate == null) return;

    final regularPay = _calculatedRegularHours * _employeeHourlyRate!;
    final overtimeRate = _employeeHourlyRate! * 1.5; // Assuming 1.5x multiplier
    final overtimePay = _calculatedOvertimeHours * overtimeRate;

    // Update or add Basic Salary income
    if (_incomesList.isEmpty || _incomesList[0]['type'] != 'Basic Salary') {
      _incomesList.insert(0, {
        'type': 'Basic Salary',
        'description': 'Base Salary',
        'amount': regularPay.toStringAsFixed(2),
      });
    } else {
      _incomesList[0]['amount'] = regularPay.toStringAsFixed(2);
    }

    // Add overtime if exists
    if (_calculatedOvertimeHours > 0) {
      final overtimeExists = _incomesList.any(
        (item) => item['type'] == 'Overtime',
      );
      if (!overtimeExists) {
        _incomesList.add({
          'type': 'Overtime',
          'description': 'Overtime Pay',
          'amount': overtimePay.toStringAsFixed(2),
        });
      } else {
        final overtimeIndex = _incomesList.indexWhere(
          (item) => item['type'] == 'Overtime',
        );
        _incomesList[overtimeIndex]['amount'] = overtimePay.toStringAsFixed(2);
      }
    }

    _updateGrossPay();
  }

  void _updateTotalHours() {
    if (_periodStart != null && _periodEnd != null) {
      int total = 0;
      DateTime d = _periodStart!;
      while (!d.isAfter(_periodEnd!)) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
          total += 8; // 8 hours per weekday
        }
        d = d.add(const Duration(days: 1));
      }
      _totalHoursController.text = total.toString();
      _updateGrossPay();
    }
  }

  void _updateDeductionsTotal() {
    double total = 0;
    for (final item in _deductionsList) {
      total += double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    }
    _deductionsController.text = total.toStringAsFixed(2);
    _updateNetPay();
  }

  void _addDeductionRow() {
    setState(() {
      // Find first available non-duplicate combination
      String defaultType = _defaultDeductionTypes.first;
      String defaultDescription = '';
      bool foundAvailable = false;

      for (String type in _defaultDeductionTypes) {
        for (String description in _deductionSubTypes[type] ?? []) {
          if (!_hasDuplicateDeduction(type, description, -1)) {
            defaultType = type;
            defaultDescription = description;
            foundAvailable = true;
            break;
          }
        }
        if (foundAvailable) break;
      }

      // If no available combination found, use first type
      if (!foundAvailable) {
        defaultDescription = _deductionSubTypes[defaultType]?.first ?? '';
      }

      _deductionsList.add({
        'type': defaultType,
        'description': defaultDescription,
        'amount': '',
      });
    });
  }

  void _removeDeductionRow(int idx) {
    setState(() {
      _deductionsList.removeAt(idx);
      _updateDeductionsTotal();
    });
  }

  void _setDeductionType(int idx, String? type) {
    setState(() {
      if (type != null && _deductionSubTypes[type] != null) {
        final firstDescription = _deductionSubTypes[type]!.first;
        // Check for duplicate type-description combination
        if (_hasDuplicateDeduction(type, firstDescription, idx)) {
          _showDuplicateWarning(
            'This ${type.toLowerCase()} type already exists',
          );
          return; // Don't allow the change
        }

        _deductionsList[idx]['type'] = type;
        _deductionsList[idx]['description'] = firstDescription;
      }
    });
  }

  void _setDeductionDescription(int idx, String? description) {
    setState(() {
      if (description != null) {
        final currentType = _deductionsList[idx]['type'];
        // Check for duplicate type-description combination
        if (_hasDuplicateDeduction(currentType, description, idx)) {
          _showDuplicateWarning(
            'This ${currentType.toLowerCase()} - ${description.toLowerCase()} combination already exists',
          );
          return; // Don't allow the change
        }

        _deductionsList[idx]['description'] = description;
      }
    });
  }

  void _setDeductionAmount(int idx, String value) {
    setState(() {
      _deductionsList[idx]['amount'] = value;
      _updateDeductionsTotal();
    });
  }

  void _updateGrossPay() {
    double total = 0;
    for (final item in _incomesList) {
      total += double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    }

    // Include overtime pay if present
    final otHours = double.tryParse(_overtimeHoursController.text) ?? 0;
    if (otHours > 0) {
      final ratePerHour =
          total / (double.tryParse(_totalHoursController.text) ?? 1);
      final multiplier =
          double.tryParse(
            widget.initialData?['overtimeMultiplier']?.toString() ?? '1.5',
          ) ??
          1.5;
      total += otHours * ratePerHour * multiplier;
    }

    _grossPayController.text = total.toStringAsFixed(2);
    _updateNetPay();
  }

  void _addIncomeRow() {
    setState(() {
      // Find a default type that doesn't create duplicates
      String defaultType = _defaultIncomeTypes.first;
      String defaultDescription = '';

      // Prevent multiple Basic Salary entries
      if (defaultType == 'Basic Salary' && _hasBasicSalary()) {
        defaultType =
            'Allowance'; // Default to Allowance if Basic Salary exists
      }

      // Find first available non-duplicate combination
      bool foundAvailable = false;
      for (String type in _defaultIncomeTypes) {
        if (type == 'Basic Salary' && _hasBasicSalary()) continue;

        for (String description in _incomeSubTypes[type] ?? []) {
          if (!_hasDuplicateIncome(type, description, -1)) {
            defaultType = type;
            defaultDescription = description;
            foundAvailable = true;
            break;
          }
        }
        if (foundAvailable) break;
      }

      // If no available combination found, use first type with suffix
      if (!foundAvailable) {
        defaultDescription = _incomeSubTypes[defaultType]?.first ?? '';
      }

      _incomesList.add({
        'type': defaultType,
        'description': defaultDescription,
        'amount': '',
      });
    });
  }

  void _removeIncomeRow(int idx) {
    setState(() {
      _incomesList.removeAt(idx);
      _updateGrossPay();
    });
  }

  void _setIncomeType(int idx, String? type) {
    setState(() {
      // Prevent multiple Basic Salary entries
      if (type == 'Basic Salary' && _hasBasicSalary()) {
        _showDuplicateWarning('Basic Salary entries are not allowed');
        return; // Don't allow the change
      }

      if (type != null && _incomeSubTypes[type] != null) {
        final firstDescription = _incomeSubTypes[type]!.first;
        // Check for duplicate type-description combination
        if (_hasDuplicateIncome(type, firstDescription, idx)) {
          _showDuplicateWarning(
            'This ${type.toLowerCase()} type already exists',
          );
          return; // Don't allow the change
        }

        _incomesList[idx]['type'] = type;
        _incomesList[idx]['description'] = firstDescription;
      }
    });
  }

  void _setIncomeDescription(int idx, String? description) {
    setState(() {
      if (description != null) {
        final currentType = _incomesList[idx]['type'];
        // Check for duplicate type-description combination
        if (_hasDuplicateIncome(currentType, description, idx)) {
          _showDuplicateWarning(
            'This ${currentType.toLowerCase()} - ${description.toLowerCase()} combination already exists',
          );
          return; // Don't allow the change
        }

        _incomesList[idx]['description'] = description;
      }
    });
  }

  void _setIncomeAmount(int idx, String value) {
    setState(() {
      _incomesList[idx]['amount'] = value;
      _updateGrossPay();
    });
  }

  Future<DateTime?> showCustomDatePicker(
    BuildContext context,
    DateTime initialDate,
  ) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initialData == null ? 'Add Payslip' : 'Edit Payslip'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Removed Pay Period field - it's redundant with Period Start/End
                const SizedBox(height: 4),
                // Period Start
                InkWell(
                  onTap: () async {
                    final picked = await showCustomDatePicker(
                      context,
                      _periodStart ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _periodStart = picked;
                        _updateTotalHours();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Period Start',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _periodStart != null
                              ? DateFormat('MMM d, y').format(_periodStart!)
                              : 'Select date',
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Period End
                InkWell(
                  onTap: () async {
                    final picked = await showCustomDatePicker(
                      context,
                      _periodEnd ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _periodEnd = picked;
                        _updateTotalHours();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Period End'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _periodEnd != null
                              ? DateFormat('MMM d, y').format(_periodEnd!)
                              : 'Select date',
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Total Hours
                Stack(
                  children: [
                    TextFormField(
                      controller: _totalHoursController,
                      decoration: InputDecoration(
                        labelText: 'Total Hours',
                        suffixIcon: _isFetchingHours
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _overtimeHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Overtime Hours',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateGrossPay(),
                ),
                const SizedBox(height: 8),
                // Refresh Hours Button
                if (widget.employeeId != null)
                  OutlinedButton.icon(
                    onPressed: _isFetchingHours
                        ? null
                        : _fetchEmployeeWorkHours,
                    icon: _isFetchingHours
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _isFetchingHours
                          ? 'Fetching hours...'
                          : 'Auto-fill from attendance',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showCustomDatePicker(
                      context,
                      _issueDate ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => _issueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Issue Date',
                      errorText:
                          _issueDate == null &&
                              _formKey.currentState?.validate() == false
                          ? 'Issue Date is required'
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _issueDate != null
                              ? DateFormat('MMM d, y').format(_issueDate!)
                              : 'Select date',
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Income Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Income Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (int i = 0; i < _incomesList.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Income Item ${i + 1}',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeIncomeRow(i),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _incomesList[i]['type'],
                                items: _defaultIncomeTypes
                                    .where(
                                      (type) =>
                                          // Allow Basic Salary only if not already present or this is the Basic Salary row
                                          type != 'Basic Salary' ||
                                          !_hasBasicSalary() ||
                                          _incomesList[i]['type'] ==
                                              'Basic Salary',
                                    )
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => _setIncomeType(i, val),
                                decoration: const InputDecoration(
                                  labelText: 'Income Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _incomesList[i]['description'],
                                items:
                                    _incomeSubTypes[_incomesList[i]['type']]
                                        ?.map(
                                          (desc) => DropdownMenuItem(
                                            value: desc,
                                            child: Text(desc),
                                          ),
                                        )
                                        .toList() ??
                                    [],
                                onChanged: (val) =>
                                    _setIncomeDescription(i, val),
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue:
                                    _incomesList[i]['amount']?.toString() ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _setIncomeAmount(i, val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _addIncomeRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Income Item'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Deductions Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Deductions', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (int i = 0; i < _deductionsList.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Deduction Item ${i + 1}',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeDeductionRow(i),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _deductionsList[i]['type'],
                                items: _defaultDeductionTypes
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => _setDeductionType(i, val),
                                decoration: const InputDecoration(
                                  labelText: 'Deduction Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _deductionsList[i]['description'],
                                items:
                                    _deductionSubTypes[_deductionsList[i]['type']]
                                        ?.map(
                                          (desc) => DropdownMenuItem(
                                            value: desc,
                                            child: Text(desc),
                                          ),
                                        )
                                        .toList() ??
                                    [],
                                onChanged: (val) =>
                                    _setDeductionDescription(i, val),
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue:
                                    _deductionsList[i]['amount']?.toString() ??
                                    '',
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _setDeductionAmount(i, val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _addDeductionRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Deduction Item'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
                // Summary Section
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Gross Pay:', style: theme.textTheme.bodyMedium),
                          Text(
                            '\$${(double.tryParse(_grossPayController.text) ?? 0).toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Deductions:',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '\$${(double.tryParse(_deductionsController.text) ?? 0).toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net Pay:',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${(double.tryParse(_netPayController.text) ?? 0).toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Admin Response (only if needs_review)
                if ((widget.initialData?['status'] ?? '') == 'needs_review')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextFormField(
                      controller: _adminResponseController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Response (visible to employee)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
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
            final valid = _formKey.currentState!.validate();
            if (!valid || _issueDate == null) {
              setState(() {}); // To show error
              return;
            }
            // Calculate pay period label from dates
            String payPeriodLabel = '';
            if (_periodStart != null && _periodEnd != null) {
              final startDateStr = DateFormat('MMM d').format(_periodStart!);
              final endDateStr = DateFormat('MMM d, y').format(_periodEnd!);
              payPeriodLabel = '$startDateStr - $endDateStr';
            }

            final payload = {
              'payPeriod': payPeriodLabel,
              'issueDate': _issueDate!.toIso8601String(),
              'periodStart': _periodStart!.toIso8601String(),
              'periodEnd': _periodEnd!.toIso8601String(),
              'totalHours': double.tryParse(_totalHoursController.text) ?? 0,
              'overtimeHours':
                  double.tryParse(_overtimeHoursController.text) ?? 0,
              'overtimeMultiplier':
                  widget.initialData?['overtimeMultiplier'] ?? 1.5,
              'grossPay': double.tryParse(_grossPayController.text) ?? 0,
              'incomesList': _incomesList,
              'deductions': double.tryParse(_deductionsController.text) ?? 0,
              'deductionsList': _deductionsList,
              'netPay': double.tryParse(_netPayController.text) ?? 0,
              'adminResponse': _adminResponseController.text,
            };
            // 'DEBUG: Admin Edit Payslip Payload:');
            // payload);
            Navigator.pop(context, payload); // Just pop with the data
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
