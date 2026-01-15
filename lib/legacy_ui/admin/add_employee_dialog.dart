import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sns_rooster/providers/employee_provider.dart';
import 'package:sns_rooster/models/user_model.dart';
import 'package:sns_rooster/services/user_service.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/config/api_config.dart';
import '../../services/department_designation_service.dart';
import '../../services/api_service.dart';
import '../../services/global_notification_service.dart';
import '../../utils/logger.dart';

class AddEmployeeDialog extends StatefulWidget {
  final EmployeeProvider employeeProvider;

  const AddEmployeeDialog({super.key, required this.employeeProvider});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  // Employee ID will be auto-generated - no controller needed
  final TextEditingController _hourlyRateController = TextEditingController();

  final UserService _userService = UserService();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  bool _isLoadingUsers = true;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _employees = [];

  // Department and designation dropdowns
  String? _selectedDepartmentId;
  String? _selectedDesignationId;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _designations = [];
  late DepartmentDesignationService _departmentDesignationService;
  final List<String> employeeTypes = ['Permanent', 'Temporary'];
  final List<String> permanentTypes = ['Full-time', 'Part-time'];
  final List<String> temporaryTypes = ['Casual'];
  String? _selectedEmployeeType;
  String? _selectedEmployeeSubType;

  @override
  void initState() {
    super.initState();
    _departmentDesignationService = DepartmentDesignationService(
      ApiService(baseUrl: ApiConfig.baseUrl),
    );
    _fetchUsers();
    _fetchEmployees();
    _loadDepartments();
  }

  @override
  void dispose() {
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {});

    try {
      final departments = await _departmentDesignationService.getDepartments();
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load departments: $e';
      });
    }
  }

  Future<void> _loadDesignations(String departmentId) async {
    setState(() {});

    try {
      final designations = await _departmentDesignationService
          .getDesignationsByDepartment(departmentId);
      setState(() {
        _designations = designations;
        // Reset designation selection if current selection is not in the new list
        if (_selectedDesignationId != null &&
            !_designations.any((d) => d['_id'] == _selectedDesignationId)) {
          _selectedDesignationId = null;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load designations: $e';
      });
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      // Fetch all users
      final users = await _userService.getUsers();
      if (kDebugMode) {
        Logger.debug('🔍 DEBUG: Fetched ${users.length} total users');
      }

      // Fetch all employees (ensure _employees is up to date)
      if (_employees.isEmpty) {
        await _fetchEmployees();
      }
      final employeeUserIds = _employees.map((e) => e['userId']).toSet();
      if (kDebugMode) {
        Logger.debug(
          '🔍 DEBUG: Found ${employeeUserIds.length} existing employees',
        );
      }

      // Filter: role == 'employee' and not already an employee
      final filtered = <UserModel>[];
      for (final user in users) {
        final isEmployeeRole = user.role == 'employee';
        final notAlreadyEmployee = !employeeUserIds.contains(user.id);

        if (kDebugMode) {
          Logger.debug(
            '🔍 DEBUG: User ${user.email} - role: ${user.role}, isEmployee: $isEmployeeRole, notAlreadyEmployee: $notAlreadyEmployee',
          );
        }

        if (isEmployeeRole && notAlreadyEmployee) {
          filtered.add(user);
        }
      }
      if (kDebugMode) {
        Logger.debug(
          '🔍 DEBUG: Final filtered users count: ${filtered.length}',
        );
      }
      setState(() {
        _users = filtered;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
      });
      if (mounted) {
        GlobalNotificationService().showError(
          'Failed to load users: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      await widget.employeeProvider.getEmployees(showInactive: true);
      setState(() {
        _employees = widget.employeeProvider.employees
            .map((e) => e.toJson())
            .toList();
      });
    } catch (e) {
      // Optionally show a warning, but don't block the dialog
      setState(() {
        _employees = [];
      });
    }
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUser == null) {
      setState(() {
        _error = 'Please select a user.';
      });
      return;
    }

    if (_selectedEmployeeType == null) {
      setState(() {
        _error = 'Please select an employee type.';
      });
      return;
    }

    if (_selectedEmployeeSubType == null) {
      setState(() {
        _error = 'Please select a subtype.';
      });
      return;
    }

    // Extra validation: check if this user is already an employee
    final alreadyEmployeeByUserId = _employees.any(
      (emp) => emp['userId'] == _selectedUser!.id,
    );

    // Check if email is already used globally
    bool emailAlreadyUsed = false;
    try {
      emailAlreadyUsed = await widget.employeeProvider.checkEmailExists(
        _selectedUser!.email,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to verify email availability. Please try again.';
        _isLoading = false;
      });
      return;
    }

    if (alreadyEmployeeByUserId || emailAlreadyUsed) {
      setState(() {
        if (alreadyEmployeeByUserId) {
          _error = 'This user is already assigned as an employee.';
        } else {
          _error =
              'An employee with email "${_selectedUser!.email}" already exists.';
        }
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Auto-generate employee ID based on company code pattern
      final employeeId = await _generateEmployeeId();

      // Build employee data, only including fields that have values
      final newEmployeeData = <String, dynamic>{
        'userId': _selectedUser!.id,
        'firstName': _selectedUser!.firstName,
        'lastName': _selectedUser!.lastName,
        'email': _selectedUser!.email,
        'employeeId': employeeId, // Auto-generated
        'employeeType': _selectedEmployeeType,
        'employeeSubType': _selectedEmployeeSubType,
      };

      // Only include departmentId if selected
      if (_selectedDepartmentId != null && _selectedDepartmentId!.isNotEmpty) {
        newEmployeeData['departmentId'] = _selectedDepartmentId;
      }

      // Only include designationId if selected
      if (_selectedDesignationId != null &&
          _selectedDesignationId!.isNotEmpty) {
        newEmployeeData['designationId'] = _selectedDesignationId;
      }

      // Only include hourlyRate if provided (not empty and not 0)
      final hourlyRateText = _hourlyRateController.text.trim();
      if (hourlyRateText.isNotEmpty) {
        final hourlyRate = double.tryParse(hourlyRateText);
        if (hourlyRate != null && hourlyRate > 0) {
          newEmployeeData['hourlyRate'] = hourlyRate;
        }
      }

      Logger.info(
        'AddEmployeeDialog: Creating employee for user: ${_selectedUser!.email}',
      );
      await widget.employeeProvider.createEmployee(newEmployeeData);

      // Log success regardless of mount state (for debugging and monitoring)
      Logger.info('AddEmployeeDialog: Employee created successfully');

      // Check if widget is still mounted before UI operations
      if (!mounted) return;

      // Success - close dialog
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      // Log error regardless of mount state (for debugging and monitoring)
      Logger.error(
        'AddEmployeeDialog: Error creating employee: ${e.toString()}',
      );

      // Check if widget is still mounted before UI operations
      if (!mounted) return;
      // Error - show error message and keep dialog open
      setState(() {
        _error = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Generate employee ID based on company code pattern
  Future<String> _generateEmployeeId() async {
    try {
      // Get company data from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final companyId = authProvider.user?['companyId']?.toString();

      if (companyId == null) {
        // Fallback to simple pattern if no company context
        final employeeCount = _employees.length;
        return 'EMP${(employeeCount + 1).toString().padLeft(3, '0')}';
      }

      // Get company code from API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/companies/$companyId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final companyData = json.decode(response.body);
        final companyCode = companyData['companyCode'] ?? 'EMP';

        // Get current employee count for this company
        final employeeCount = _employees.length;
        final nextNumber = employeeCount + 1;

        // Generate ID based on company code pattern
        // If company code is "SNS001", employee IDs will be "SNS001-001", "SNS001-002", etc.
        return '$companyCode-${nextNumber.toString().padLeft(3, '0')}';
      } else {
        // Fallback if company data fetch fails
        final employeeCount = _employees.length;
        return 'EMP${(employeeCount + 1).toString().padLeft(3, '0')}';
      }
    } catch (e) {
      // Fallback if any error occurs
      final employeeCount = _employees.length;
      return 'EMP${(employeeCount + 1).toString().padLeft(3, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add New Employee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Selection
              _isLoadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                  ? const Center(child: Text('No users available'))
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select User',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<UserModel>(
                              decoration: const InputDecoration(
                                hintText: 'Select a user to add as employee',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: _selectedUser,
                              isExpanded: true,
                              items: _users.map((UserModel user) {
                                return DropdownMenuItem<UserModel>(
                                  value: user,
                                  child: Text(
                                    user.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (UserModel? newValue) {
                                setState(() {
                                  _selectedUser = newValue;
                                  // Employee ID will be auto-generated when saving
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Please select a user' : null,
                            ),
                            if (_selectedUser != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Selected: ${_selectedUser!.displayName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Email: ${_selectedUser!.email}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // Employee ID will be auto-generated - no manual input needed

              // Department Dropdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Department',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartmentId,
                        decoration: const InputDecoration(
                          hintText: 'Select department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments.map<DropdownMenuItem<String>>((
                          dept,
                        ) {
                          return DropdownMenuItem<String>(
                            value: dept['_id']?.toString(),
                            child: Text(dept['name'] ?? 'Unknown Department'),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDepartmentId = newValue;
                            _selectedDesignationId =
                                null; // Reset designation when department changes
                          });
                          if (newValue != null) {
                            _loadDesignations(newValue);
                          }
                        },
                        validator: (value) =>
                            value == null ? 'Please select a department' : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Designation Dropdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Designation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDesignationId,
                        decoration: const InputDecoration(
                          hintText: 'Select designation',
                          border: OutlineInputBorder(),
                        ),
                        items: _designations.map<DropdownMenuItem<String>>((
                          designation,
                        ) {
                          return DropdownMenuItem<String>(
                            value: designation['_id']?.toString(),
                            child: Text(
                              designation['title'] ?? 'Unknown Designation',
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedDesignationId = newValue;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select a designation'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Employee Type Dropdowns
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employee Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          hintText: 'Select employee type',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedEmployeeType,
                        items: employeeTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedEmployeeType = newValue;
                            // Set default subtype when type changes
                            if (newValue == 'Permanent') {
                              _selectedEmployeeSubType = 'Full-time';
                            } else if (newValue == 'Temporary') {
                              _selectedEmployeeSubType = 'Casual';
                            } else {
                              _selectedEmployeeSubType = null;
                            }
                          });
                        },
                        validator: (value) => value == null
                            ? 'Please select an employee type'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (_selectedEmployeeType == 'Permanent')
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            hintText: 'Select permanent type',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedEmployeeSubType,
                          items: permanentTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedEmployeeSubType = newValue;
                            });
                          },
                          validator: (value) => value == null
                              ? 'Please select a permanent type'
                              : null,
                        ),
                      if (_selectedEmployeeType == 'Temporary')
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            hintText: 'Select temporary type',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedEmployeeSubType,
                          items: temporaryTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedEmployeeSubType = newValue;
                            });
                          },
                          validator: (value) => value == null
                              ? 'Please select a temporary type'
                              : null,
                        ),
                    ],
                  ),
                ),
              ),

              // Hourly Rate Field
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hourly Rate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _hourlyRateController,
                        decoration: const InputDecoration(
                          labelText: 'Hourly Rate',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),

              if (_error != null) ...[
                // Show error message if present
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addEmployee,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
