import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../config/leave_config.dart';
import '../../services/global_notification_service.dart';
import '../../providers/auth_provider.dart';
import 'package:sns_rooster/utils/logger.dart';

class LeavePolicySettingsScreen extends StatefulWidget {
  const LeavePolicySettingsScreen({super.key});

  @override
  State<LeavePolicySettingsScreen> createState() =>
      _LeavePolicySettingsScreenState();
}

class _LeavePolicySettingsScreenState extends State<LeavePolicySettingsScreen> {
  List<Map<String, dynamic>> _policies = [];
  Map<String, dynamic>? _defaultPolicy;
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isSaving = false; // New flag for save operation in progress
  String? _currentPolicyId;

  // Form controllers for creating/editing policy
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Leave type controllers
  final _annualLeaveController = TextEditingController();
  final _sickLeaveController = TextEditingController();
  final _casualLeaveController = TextEditingController();
  final _maternityLeaveController = TextEditingController();
  final _paternityLeaveController = TextEditingController();
  final _unpaidLeaveController = TextEditingController();

  // Rules controllers
  final _minNoticeController = TextEditingController();
  final _maxConsecutiveController = TextEditingController();
  final _maxCarryOverController = TextEditingController();
  final _officeHoursCutoffController = TextEditingController();

  // Half-day specific controllers
  final _maxHalfDaysPerYearController = TextEditingController();
  final _maxHalfDaysPerMonthController = TextEditingController();
  final _minGapBetweenHalfDaysController = TextEditingController();
  final _annualLeaveHalfDayController = TextEditingController();
  final _sickLeaveHalfDayController = TextEditingController();
  final _casualLeaveHalfDayController = TextEditingController();
  final _maternityLeaveHalfDayController = TextEditingController();
  final _paternityLeaveHalfDayController = TextEditingController();
  final _unpaidLeaveHalfDayController = TextEditingController();

  // Boolean values
  bool _allowHalfDays = false;
  bool _allowCancellation = true;
  bool _carryOverBalance = false;
  bool _isDefault = false;

  // Half-day specific boolean values
  bool _countAsHalfDay = true;
  bool _allowHalfDayCombination = true;

  // Australian-specific fields
  String _selectedCountry = 'Nepal';
  bool _isAustralianPolicy = false;
  bool _progressiveAccrual = false;

  // Australian leave type controllers
  final _compassionateLeaveController = TextEditingController();
  final _longServiceLeaveController = TextEditingController();
  final _parentalLeaveController = TextEditingController();
  final _personalCarersLeaveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _annualLeaveController.dispose();
    _sickLeaveController.dispose();
    _casualLeaveController.dispose();
    _maternityLeaveController.dispose();
    _paternityLeaveController.dispose();
    _unpaidLeaveController.dispose();
    _minNoticeController.dispose();
    _maxConsecutiveController.dispose();
    _maxCarryOverController.dispose();
    // Australian controllers
    _compassionateLeaveController.dispose();
    _longServiceLeaveController.dispose();
    _parentalLeaveController.dispose();
    _personalCarersLeaveController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await api.get('/leave-policies/simple');

      if (response.success) {
        setState(() {
          _policies = List<Map<String, dynamic>>.from(response.data);
          _defaultPolicy = _policies.firstWhere(
            (policy) => policy['isDefault'] == true,
            orElse: () => {},
          );
        });
      }
    } catch (e) {
      Logger.error('Error loading policies: $e');
      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.showError('Failed to load leave policies');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreatePolicyDialog() {
    _resetForm();
    _currentPolicyId = null;
    _isUpdating = false;
    _isCreating = false;
    _showPolicyDialog('Create Leave Policy');
  }

  void _showEditPolicyDialog(Map<String, dynamic> policy) {
    _currentPolicyId = policy['_id'];
    _isUpdating = true;
    _isCreating = false;
    _populateForm(policy);
    _showPolicyDialog('Edit Leave Policy');
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _annualLeaveController.text = '12';
    _sickLeaveController.text = '10';
    _casualLeaveController.text = '5';
    _maternityLeaveController.text = '90';
    _paternityLeaveController.text = '10';
    _unpaidLeaveController.text = '0';
    _minNoticeController.text = '1';
    _maxConsecutiveController.text = '30';
    _maxCarryOverController.text = '5';
    _officeHoursCutoffController.text = '9';
    _allowHalfDays = false;
    _allowCancellation = true;
    _carryOverBalance = false;
    _isDefault = false;

    // Reset half-day specific fields
    _maxHalfDaysPerYearController.text = '10';
    _maxHalfDaysPerMonthController.text = '2';
    _minGapBetweenHalfDaysController.text = '1';
    _annualLeaveHalfDayController.text = '5';
    _sickLeaveHalfDayController.text = '3';
    _casualLeaveHalfDayController.text = '2';
    _maternityLeaveHalfDayController.text = '0';
    _paternityLeaveHalfDayController.text = '0';
    _unpaidLeaveHalfDayController.text = '0';
    _countAsHalfDay = true;
    _allowHalfDayCombination = true;
  }

  void _populateForm(Map<String, dynamic> policy) {
    _nameController.text = policy['name'] ?? '';
    _descriptionController.text = policy['description'] ?? '';

    final leaveTypes = policy['leaveTypes'] ?? {};
    _annualLeaveController.text =
        (leaveTypes['annualLeave']?['totalDays'] ?? 12).toString();
    _sickLeaveController.text = (leaveTypes['sickLeave']?['totalDays'] ?? 10)
        .toString();
    _casualLeaveController.text = (leaveTypes['casualLeave']?['totalDays'] ?? 5)
        .toString();
    _maternityLeaveController.text =
        (leaveTypes['maternityLeave']?['totalDays'] ?? 90).toString();
    _paternityLeaveController.text =
        (leaveTypes['paternityLeave']?['totalDays'] ?? 10).toString();
    _unpaidLeaveController.text = (leaveTypes['unpaidLeave']?['totalDays'] ?? 0)
        .toString();

    final rules = policy['rules'] ?? {};
    _minNoticeController.text = (rules['minNoticeDays'] ?? 1).toString();
    _maxConsecutiveController.text = (rules['maxConsecutiveDays'] ?? 30)
        .toString();
    _maxCarryOverController.text = (rules['maxCarryOverDays'] ?? 5).toString();
    _officeHoursCutoffController.text = (rules['officeHoursCutoff'] ?? 9)
        .toString();
    _allowHalfDays = rules['allowHalfDays'] ?? false;
    _allowCancellation = rules['allowCancellation'] ?? true;
    _carryOverBalance = rules['carryOverBalance'] ?? false;
    _isDefault = policy['isDefault'] ?? false;

    // Populate half-day specific fields
    final halfDayRules = rules['halfDayRules'] ?? {};
    _maxHalfDaysPerYearController.text =
        (halfDayRules['maxHalfDaysPerYear'] ?? 10).toString();
    _maxHalfDaysPerMonthController.text =
        (halfDayRules['maxHalfDaysPerMonth'] ?? 2).toString();
    _minGapBetweenHalfDaysController.text =
        (halfDayRules['minGapBetweenHalfDays'] ?? 1).toString();
    _annualLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['annualLeave'] ?? 5).toString();
    _sickLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['sickLeave'] ?? 3).toString();
    _casualLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['casualLeave'] ?? 2).toString();
    _maternityLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['maternityLeave'] ?? 0).toString();
    _paternityLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['paternityLeave'] ?? 0).toString();
    _unpaidLeaveHalfDayController.text =
        (halfDayRules['leaveTypeLimits']?['unpaidLeave'] ?? 0).toString();
    _countAsHalfDay = halfDayRules['countAsHalfDay'] ?? true;
    _allowHalfDayCombination = halfDayRules['allowCombination'] ?? true;
  }

  late StateSetter _dialogSetState;

  // Build standard leave types data for API
  Map<String, dynamic> _buildStandardLeaveTypesData() {
    return {
      'annualLeave': {
        'totalDays': int.parse(_annualLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Annual Leave'),
        'isActive': true,
      },
      'sickLeave': {
        'totalDays': int.parse(_sickLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Sick Leave'),
        'isActive': true,
      },
      'casualLeave': {
        'totalDays': int.parse(_casualLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Casual Leave'),
        'isActive': true,
      },
      'maternityLeave': {
        'totalDays': int.parse(_maternityLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Maternity Leave'),
        'isActive': true,
      },
      'paternityLeave': {
        'totalDays': int.parse(_paternityLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Paternity Leave'),
        'isActive': true,
      },
      'unpaidLeave': {
        'totalDays': int.parse(_unpaidLeaveController.text),
        'description': LeaveConfig.getLeaveTypeDescription('Unpaid Leave'),
        'isActive': true,
      },
      'compassionateLeave': {
        'totalDays': 0,
        'description': 'Compassionate Leave',
        'isActive': false,
      },
      'longServiceLeave': {
        'totalDays': 0,
        'description': 'Long Service Leave',
        'isActive': false,
        'yearsRequired': 7,
      },
      'parentalLeave': {
        'totalDays': 0,
        'description': 'Parental Leave',
        'isActive': false,
        'maxWeeks': 0,
      },
    };
  }

  // Build Australian leave types data for API
  Map<String, dynamic> _buildAustralianLeaveTypesData() {
    return {
      'annualLeave': {
        'totalDays': int.parse(_annualLeaveController.text),
        'description': 'Annual Leave',
        'isActive': true,
      },
      'sickLeave': {
        'totalDays': 0, // Replaced by personalCarersLeave
        'description': 'Sick Leave (Legacy)',
        'isActive': false,
      },
      'casualLeave': {
        'totalDays': 0, // Not used in Australian system
        'description': 'Casual Leave (Legacy)',
        'isActive': false,
      },
      'maternityLeave': {
        'totalDays': 0, // Replaced by parentalLeave
        'description': 'Maternity Leave (Legacy)',
        'isActive': false,
      },
      'paternityLeave': {
        'totalDays': 0, // Replaced by parentalLeave
        'description': 'Paternity Leave (Legacy)',
        'isActive': false,
      },
      'unpaidLeave': {
        'totalDays': int.parse(_unpaidLeaveController.text),
        'description': 'Unpaid Leave',
        'isActive': true,
      },
      'compassionateLeave': {
        'totalDays': int.parse(_compassionateLeaveController.text),
        'description': 'Compassionate Leave',
        'isActive': true,
      },
      'longServiceLeave': {
        'totalDays': int.parse(_longServiceLeaveController.text),
        'description': 'Long Service Leave',
        'isActive': true,
        'yearsRequired': 7,
      },
      'parentalLeave': {
        'totalDays': int.parse(_parentalLeaveController.text),
        'description': 'Parental Leave',
        'isActive': true,
        'maxWeeks': 52,
      },
    };
  }

  // Build standard leave types
  List<Widget> _buildStandardLeaveTypes() {
    return [
      _buildLeaveTypeRow(
        'Annual Leave',
        _annualLeaveController,
        Icons.beach_access,
        Colors.blue,
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Sick Leave',
        _sickLeaveController,
        Icons.local_hospital,
        Colors.red,
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Casual Leave',
        _casualLeaveController,
        Icons.free_breakfast,
        Colors.orange,
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Maternity Leave',
        _maternityLeaveController,
        Icons.favorite,
        Colors.pink,
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Paternity Leave',
        _paternityLeaveController,
        Icons.family_restroom,
        Colors.indigo,
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Unpaid Leave',
        _unpaidLeaveController,
        Icons.money_off,
        Colors.grey,
      ),
    ];
  }

  // Build Australian leave types
  List<Widget> _buildAustralianLeaveTypes() {
    return [
      _buildLeaveTypeRow(
        'Annual Leave',
        _annualLeaveController,
        Icons.beach_access,
        Colors.blue,
        helpText: '4 weeks (20 days) for full-time/part-time employees',
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Personal/Carer\'s Leave',
        _personalCarersLeaveController,
        Icons.local_hospital,
        Colors.red,
        helpText: '10 days per year for personal illness or caring for family',
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Compassionate Leave',
        _compassionateLeaveController,
        Icons.favorite,
        Colors.brown,
        helpText: '2 days per occasion for death or serious illness of family',
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Parental Leave',
        _parentalLeaveController,
        Icons.child_care,
        Colors.pink,
        helpText: 'Up to 52 weeks unpaid for birth or adoption',
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Long Service Leave',
        _longServiceLeaveController,
        Icons.work_history,
        Colors.blueGrey,
        helpText: 'Additional leave after 7+ years of service',
      ),
      const SizedBox(height: 16),
      _buildLeaveTypeRow(
        'Unpaid Leave',
        _unpaidLeaveController,
        Icons.money_off,
        Colors.grey,
        helpText: 'Leave without pay for special circumstances',
      ),
      const SizedBox(height: 16),

      // Employee Type Information
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
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Employee Type Entitlements',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Full-time & Part-time: 20 days annual leave, 10 days personal/carer\'s leave\n'
              '• Casual: No leave entitlements (25% loading instead)',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ],
        ),
      ),
    ];
  }

  // Load Australian template
  Future<void> _loadAustralianTemplate() async {
    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await api.get('/leave-policies/templates/australia');

      if (response.success) {
        final template = response.data;

        setState(() {
          _selectedCountry = 'Australia';
          _isAustralianPolicy = true;
          _progressiveAccrual =
              template['rules']?['progressiveAccrual'] ?? true;
        });

        // Populate form with Australian template data
        _nameController.text =
            template['name'] ?? 'Australian Fair Work Policy';
        _descriptionController.text = template['description'] ?? '';

        // Populate leave types
        final leaveTypes = template['leaveTypes'] ?? {};
        _annualLeaveController.text =
            (leaveTypes['annualLeave']?['totalDays'] ?? 20).toString();
        _personalCarersLeaveController.text =
            (leaveTypes['sickLeave']?['totalDays'] ?? 0).toString();
        _compassionateLeaveController.text =
            (leaveTypes['compassionateLeave']?['totalDays'] ?? 2).toString();
        _parentalLeaveController.text =
            (leaveTypes['parentalLeave']?['totalDays'] ?? 0).toString();
        _longServiceLeaveController.text =
            (leaveTypes['longServiceLeave']?['totalDays'] ?? 0).toString();
        _unpaidLeaveController.text =
            (leaveTypes['unpaidLeave']?['totalDays'] ?? 0).toString();

        // Disable legacy leave types for Australian policy
        _sickLeaveController.text = '0';
        _casualLeaveController.text = '0';
        _maternityLeaveController.text = '0';
        _paternityLeaveController.text = '0';

        // Populate rules
        final rules = template['rules'] ?? {};
        _minNoticeController.text = (rules['minNoticeDays'] ?? 1).toString();
        _maxConsecutiveController.text = (rules['maxConsecutiveDays'] ?? 30)
            .toString();
        _maxCarryOverController.text = (rules['maxCarryOverDays'] ?? 5)
            .toString();
        _officeHoursCutoffController.text = (rules['officeHoursCutoff'] ?? 9)
            .toString();
        _allowHalfDays = rules['allowHalfDays'] ?? true;
        _allowCancellation = rules['allowCancellation'] ?? true;
        _carryOverBalance = rules['carryOverBalance'] ?? true;

        GlobalNotificationService().showSuccess(
          'Australian template loaded successfully',
        );
      } else {
        GlobalNotificationService().showError(
          'Failed to load Australian template',
        );
      }
    } catch (e) {
      GlobalNotificationService().showError(
        'Error loading Australian template: $e',
      );
    }
  }

  // Handle country selection change
  void _onCountryChanged(String? country) {
    if (country != null) {
      setState(() {
        _selectedCountry = country;
        _isAustralianPolicy = country == 'Australia';
        if (!_isAustralianPolicy) {
          _progressiveAccrual = false;
        }
      });
    }
  }

  List<Widget> _buildFormContent() {
    return [
      _buildSectionCard(
        title: 'Basic Information',
        icon: Icons.info_outline,
        children: [
          // Country Selection
          DropdownButtonFormField<String>(
            initialValue: _selectedCountry,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Country',
              hintText: 'Select country for policy',
              prefixIcon: const Icon(Icons.public),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: const [
              DropdownMenuItem(value: 'Nepal', child: Text('Nepal')),
              DropdownMenuItem(value: 'Australia', child: Text('Australia')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: _onCountryChanged,
          ),
          const SizedBox(height: 16),

          // Australian Template Button
          if (_selectedCountry == 'Australia')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadAustralianTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Load Australian Fair Work Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Policy Name',
              hintText: 'Enter policy name',
              prefixIcon: const Icon(Icons.edit),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Policy name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Enter policy description',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 3,
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildSectionCard(
        title: 'Leave Entitlements',
        subtitle: _isAustralianPolicy
            ? 'Days per year for each leave type (Australian Fair Work compliant)'
            : 'Days per year for each leave type',
        icon: Icons.calendar_today,
        children: _isAustralianPolicy
            ? _buildAustralianLeaveTypes()
            : _buildStandardLeaveTypes(),
      ),
      const SizedBox(height: 24),
      _buildSectionCard(
        title: 'Policy Rules',
        subtitle: 'Configure leave request rules and limits',
        icon: Icons.settings,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRuleField(
                  'Min Notice',
                  _minNoticeController,
                  Icons.schedule,
                  Colors.green,
                  hint: 'Days',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRuleField(
                  'Max Consecutive',
                  _maxConsecutiveController,
                  Icons.timeline,
                  Colors.purple,
                  hint: 'Days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRuleField(
            'Office Hours Cutoff',
            _officeHoursCutoffController,
            Icons.access_time,
            Colors.blue,
            hint: '24h format (e.g., 9 for 9:00 AM)',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final hour = int.tryParse(value);
              if (hour == null) {
                return 'Invalid hour';
              }
              if (hour < 0 || hour > 23) {
                return 'Must be between 0-23';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildRuleField(
            'Max Carry Over',
            _maxCarryOverController,
            Icons.swap_horiz,
            Colors.teal,
            hint: 'Days',
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildSectionCard(
        title: 'Policy Options',
        subtitle: 'Enable or disable policy features',
        icon: Icons.toggle_on,
        children: [
          _buildToggleOption(
            'Allow Half Days',
            'Employees can request half-day leaves',
            _allowHalfDays,
            (value) => _dialogSetState(() => _allowHalfDays = value),
            Icons.access_time,
          ),
          _buildToggleOption(
            'Allow Cancellation',
            'Employees can cancel approved leaves',
            _allowCancellation,
            (value) => _dialogSetState(() => _allowCancellation = value),
            Icons.cancel,
          ),
          _buildToggleOption(
            'Carry Over Balance',
            'Unused leave carries over to next year',
            _carryOverBalance,
            (value) => _dialogSetState(() => _carryOverBalance = value),
            Icons.forward,
          ),
          // Australian-specific progressive accrual toggle
          if (_isAustralianPolicy)
            _buildToggleOption(
              'Progressive Accrual',
              'Leave accrues throughout the year (Australian standard)',
              _progressiveAccrual,
              (value) => _dialogSetState(() => _progressiveAccrual = value),
              Icons.trending_up,
            ),
          _buildToggleOption(
            'Set as Default',
            'Make this the default policy for new employees',
            _isDefault,
            (value) => _dialogSetState(() => _isDefault = value),
            Icons.star,
          ),
        ],
      ),
      if (_allowHalfDays) ...[
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Half-Day Management',
          subtitle: 'Configure half-day leave rules and limits',
          icon: Icons.access_time_filled,
          children: [
            _buildToggleOption(
              'Count as Half Days',
              'Half-day leaves count as 0.5 days in balance',
              _countAsHalfDay,
              (value) => _dialogSetState(() => _countAsHalfDay = value),
              Icons.calculate,
            ),
            _buildToggleOption(
              'Allow Combination',
              'Half-day leaves can be combined with full-day leaves',
              _allowHalfDayCombination,
              (value) =>
                  _dialogSetState(() => _allowHalfDayCombination = value),
              Icons.link,
            ),
            const SizedBox(height: 24),
            const Text(
              'Global Half-Day Limits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRuleField(
                    'Max per Year',
                    _maxHalfDaysPerYearController,
                    Icons.calendar_today,
                    Colors.blue,
                    hint: 'Half-Days',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRuleField(
                    'Max per Month',
                    _maxHalfDaysPerMonthController,
                    Icons.calendar_month,
                    Colors.green,
                    hint: 'Half-Days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRuleField(
              'Min Gap Between Half-Days',
              _minGapBetweenHalfDaysController,
              Icons.schedule,
              Colors.orange,
              hint: 'Days',
            ),
            const SizedBox(height: 24),
            const Text(
              'Half-Day Limits by Leave Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Annual Leave',
                    _annualLeaveHalfDayController,
                    Icons.beach_access,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Sick Leave',
                    _sickLeaveHalfDayController,
                    Icons.local_hospital,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Casual Leave',
                    _casualLeaveHalfDayController,
                    Icons.free_breakfast,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Maternity Leave',
                    _maternityLeaveHalfDayController,
                    Icons.favorite,
                    Colors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Paternity Leave',
                    _paternityLeaveHalfDayController,
                    Icons.family_restroom,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHalfDayLimitField(
                    'Unpaid Leave',
                    _unpaidLeaveHalfDayController,
                    Icons.money_off,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ];
  }

  void _showPolicyDialog(String title) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _dialogSetState = setDialogState;
          Logger.debug(
            'LeavePolicySettings: Dialog builder - _isCreating: $_isCreating, _isUpdating: $_isUpdating, _currentPolicyId: $_currentPolicyId',
          );
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.95,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
                minWidth: 300,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.policy, color: Colors.white, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withAlpha(51),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildFormContent(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    Logger.debug(
                                      'LeavePolicySettings: Button pressed!',
                                    );
                                    Logger.debug(
                                      'LeavePolicySettings: _isCreating: $_isCreating, _isUpdating: $_isUpdating, _isSaving: $_isSaving',
                                    );
                                    _savePolicy();
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isUpdating
                                        ? 'Update Policy'
                                        : 'Save Policy',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeRow(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color, {
    String? helpText,
  }) {
    final rowWidget = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              if (int.tryParse(value) == null) {
                return 'Invalid';
              }
              return null;
            },
          ),
        ),
      ],
    );

    if (helpText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rowWidget,
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44), // Align with text
            child: Text(
              helpText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return rowWidget;
  }

  Widget _buildRuleField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color, {
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint != null ? '$label ($hint)' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.number,
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (int.tryParse(value) == null) {
                  return 'Invalid number';
                }
                return null;
              },
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildHalfDayLimitField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: color.withAlpha(13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            hintText: '0',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (int.tryParse(value) == null) {
              return 'Invalid number';
            }
            final num = int.parse(value);
            if (num < 0) {
              return 'Must be ≥ 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) {
      Logger.debug('LeavePolicySettings: Form validation failed');
      return;
    }

    if (!mounted) return;

    Logger.info('LeavePolicySettings: Starting save operation...');
    Logger.debug(
      'LeavePolicySettings: Policy ID: ${_currentPolicyId ?? 'new'}',
    );
    Logger.debug('LeavePolicySettings: Is updating: $_isUpdating');
    Logger.debug('LeavePolicySettings: Is creating: $_isCreating');

    // Set saving state
    _dialogSetState(() {
      _isSaving = true;
    });

    // Add timeout to prevent infinite loading
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isSaving) {
        Logger.error('LeavePolicySettings: Save operation timed out');
        _dialogSetState(() {
          _isSaving = false;
        });
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showError(
          'Save operation timed out. Please try again.',
        );
      }
    });

    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);

      // Build policy data
      final policyData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'country': _selectedCountry,
        'isDefault': _isDefault,
        'leaveTypes': _isAustralianPolicy
            ? _buildAustralianLeaveTypesData()
            : _buildStandardLeaveTypesData(),
        'rules': {
          'minNoticeDays': int.parse(_minNoticeController.text),
          'maxConsecutiveDays': int.parse(_maxConsecutiveController.text),
          'officeHoursCutoff': int.parse(_officeHoursCutoffController.text),
          'allowHalfDays': _allowHalfDays,
          'allowCancellation': _allowCancellation,
          'carryOverBalance': _carryOverBalance,
          'maxCarryOverDays': int.parse(_maxCarryOverController.text),
          'leaveYearStartMonth': 1,
          'leaveYearStartDay': 1,
          'progressiveAccrual': _progressiveAccrual,

          // Add half-day specific rules
          'halfDayRules': {
            'maxHalfDaysPerYear': int.parse(_maxHalfDaysPerYearController.text),
            'maxHalfDaysPerMonth': int.parse(
              _maxHalfDaysPerMonthController.text,
            ),
            'countAsHalfDay': _countAsHalfDay,
            'minGapBetweenHalfDays': int.parse(
              _minGapBetweenHalfDaysController.text,
            ),
            'allowCombination': _allowHalfDayCombination,
            'leaveTypeLimits': {
              'annualLeave': int.parse(_annualLeaveHalfDayController.text),
              'sickLeave': int.parse(_sickLeaveHalfDayController.text),
              'casualLeave': int.parse(_casualLeaveHalfDayController.text),
              'maternityLeave': int.parse(
                _maternityLeaveHalfDayController.text,
              ),
              'paternityLeave': int.parse(
                _paternityLeaveHalfDayController.text,
              ),
              'unpaidLeave': int.parse(_unpaidLeaveHalfDayController.text),
            },
          },
        },
      };

      Logger.debug('LeavePolicySettings: Policy data prepared');
      Logger.info('LeavePolicySettings: Making API call...');

      // Make API call
      final response = _currentPolicyId != null
          ? await api.put(
              '/leave-policies/simple/$_currentPolicyId',
              policyData,
            )
          : await api.post('/leave-policies/simple', policyData);

      Logger.debug('LeavePolicySettings: API response received');
      Logger.debug('LeavePolicySettings: Success: ${response.success}');
      Logger.debug('LeavePolicySettings: Message: ${response.message}');

      if (!mounted) return;

      if (response.success) {
        Logger.info('LeavePolicySettings: Save successful');

        // Close dialog first
        Navigator.of(context).pop();

        // Reload policies
        await _loadPolicies();

        if (!mounted) return;

        // Show success message
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showSuccess(
          _isUpdating
              ? 'Leave policy updated successfully'
              : 'Leave policy created successfully',
        );
      } else {
        Logger.warning('LeavePolicySettings: Save failed: ${response.message}');
        throw Exception(response.message);
      }
    } catch (e) {
      Logger.error('LeavePolicySettings: Error saving policy: $e');
      Logger.debug('LeavePolicySettings: Error type: ${e.runtimeType}');

      if (!mounted) return;

      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.showError(
        _isUpdating
            ? 'Failed to update leave policy: ${e.toString()}'
            : 'Failed to create leave policy: ${e.toString()}',
      );
    } finally {
      // Cancel timeout timer
      timeoutTimer.cancel();

      // Always reset saving state
      if (mounted) {
        _dialogSetState(() {
          _isSaving = false;
        });
      }
      Logger.debug(
        'LeavePolicySettings: Save operation completed, _isSaving set to false',
      );
    }
  }

  Future<void> _setAsDefaultPolicy(String policyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Default Policy'),
        content: const Text(
          'Are you sure you want to set this policy as the default? This will make it the default policy for all new employees.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Set as Default'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);

      // First, unset all other policies as default
      for (final policy in _policies) {
        if (policy['isDefault'] == true && policy['_id'] != policyId) {
          await api.put('/leave-policies/simple/${policy['_id']}', {
            ...policy,
            'isDefault': false,
          });
        }
      }

      // Set the selected policy as default
      final policy = _policies.firstWhere((p) => p['_id'] == policyId);
      final response = await api.put('/leave-policies/simple/$policyId', {
        ...policy,
        'isDefault': true,
      });

      if (response.success) {
        await _loadPolicies();
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showSuccess('Policy set as default successfully');
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      Logger.error('Error setting default policy: $e');
      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.showError('Failed to set policy as default');
    }
  }

  void _showPolicyDetails(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(policy['name'] ?? 'Policy Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (policy['description'] != null) ...[
                Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(policy['description']),
                const SizedBox(height: 16),
              ],
              Text(
                'Leave Entitlements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(policy['leaveTypes'] as Map<String, dynamic>? ?? {}).entries
                  .map((entry) {
                    final leaveType = entry.key;
                    final data = entry.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            leaveType
                                .replaceAll(RegExp(r'([A-Z])'), ' \$1')
                                .trim(),
                          ),
                          Text('${data['totalDays'] ?? 0} days'),
                        ],
                      ),
                    );
                  }),
              const SizedBox(height: 16),
              Text('Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(policy['rules'] as Map<String, dynamic>? ?? {}).entries.map((
                entry,
              ) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim(),
                      ),
                      Text(entry.value.toString()),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditPolicyDialog(policy);
            },
            child: const Text('Edit Policy'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePolicy(String policyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Policy'),
        content: const Text(
          'Are you sure you want to delete this policy? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ApiService(baseUrl: ApiConfig.baseUrl);
      final response = await api.delete('/leave-policies/simple/$policyId');

      if (response.success) {
        await _loadPolicies();
        final notificationService = Provider.of<GlobalNotificationService>(
          context,
          listen: false,
        );
        notificationService.showSuccess('Policy deleted successfully');
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      Logger.error('Error deleting policy: $e');
      final notificationService = Provider.of<GlobalNotificationService>(
        context,
        listen: false,
      );
      notificationService.showError('Failed to delete policy');
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(
    BuildContext context,
    Map<String, dynamic> policy,
    bool isDefault,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(policy['name'] ?? 'Unnamed Policy'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (policy['description'] != null)
              Text(policy['description']?.toString() ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isDefault)
                  const Chip(
                    label: Text('DEFAULT'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                const SizedBox(width: 8),
                Text(() {
                  final raw = policy['createdAt'];
                  if (raw == null) return 'Created: Unknown';
                  try {
                    final d = DateTime.parse(raw.toString()).toLocal();
                    return 'Created: ${d.toString().split(' ')[0]}';
                  } catch (_) {
                    return 'Created: Unknown';
                  }
                }(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditPolicyDialog(policy);
            } else if (value == 'setDefault') {
              _setAsDefaultPolicy(policy['_id']);
            } else if (value == 'viewDetails') {
              _showPolicyDetails(policy);
            } else if (value == 'delete') {
              _deletePolicy(policy['_id']);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Policy'),
                ],
              ),
            ),
            if (!isDefault)
              const PopupMenuItem(
                value: 'setDefault',
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      'Set as Default',
                      style: TextStyle(color: Colors.amber),
                    ),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'viewDetails',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            if (!isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Policy', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.policy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No policies found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first leave policy to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if user is admin
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.user?['role'] == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leave Policy Settings'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only company administrators can manage leave policies.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Policy Settings'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPolicies,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Policies',
                              '${_policies.length}',
                              Icons.policy,
                              colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Default Policy',
                              _defaultPolicy != null ? 'Active' : 'None',
                              Icons.star,
                              Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Custom Policies',
                              '${_policies.where((p) => p['isDefault'] != true).length}',
                              Icons.settings,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Header Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.policy,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Leave Policies',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Manage leave entitlements and rules for your company',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _showCreatePolicyDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Policy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Default Policy Section
                    if (_defaultPolicy != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Default Policy',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildPolicyCard(context, _defaultPolicy!, true),
                          ],
                        ),
                      ),
                    ],

                    // All Policies Section
                    if (_policies.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.list,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Policies',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._policies
                          .where((policy) => policy['isDefault'] != true)
                          .map(
                            (policy) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: _buildPolicyCard(context, policy, false),
                            ),
                          ),
                    ],

                    // Empty State
                    if (_policies.isEmpty) _buildEmptyState(context),
                  ],
                ),
              ),
            ),
    );
  }
}
