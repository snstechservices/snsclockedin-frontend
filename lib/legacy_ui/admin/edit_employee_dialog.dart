import 'package:flutter/material.dart';
import 'package:sns_rooster/providers/employee_provider.dart'; // Import EmployeeProvider
import '../../services/department_designation_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/logger.dart';

class EditEmployeeDialog extends StatefulWidget {
  final Map<String, dynamic> employee;
  final EmployeeProvider employeeProvider; // Change to EmployeeProvider

  const EditEmployeeDialog({
    super.key,
    required this.employee,
    required this.employeeProvider,
  }); // Update constructor

  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _employeeIdController;
  late TextEditingController _hourlyRateController;
  bool _isLoading = false;
  String? _error;
  bool _dialogResult = false;

  // Department and designation dropdowns
  String? _selectedDepartmentId;
  String? _selectedDesignationId;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _designations = [];
  late DepartmentDesignationService _departmentDesignationService;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.employee['firstName'],
    );
    _lastNameController = TextEditingController(
      text: widget.employee['lastName'],
    );
    _emailController = TextEditingController(text: widget.employee['email']);
    _employeeIdController = TextEditingController(
      text: widget.employee['employeeId'],
    );
    _hourlyRateController = TextEditingController(
      text: widget.employee['hourlyRate']?.toString() ?? '',
    );

    // Initialize department and designation service
    _departmentDesignationService = DepartmentDesignationService(
      ApiService(baseUrl: ApiConfig.baseUrl),
    );

    // Set selected department and designation
    // Handle both populated objects and ID strings
    if (widget.employee['departmentId'] is Map<String, dynamic>) {
      _selectedDepartmentId = widget.employee['departmentId']['_id']
          ?.toString();
      Logger.debug(
        '🔍 EditEmployeeDialog: Department is populated object, extracted ID: $_selectedDepartmentId',
      );
    } else {
      _selectedDepartmentId = widget.employee['departmentId']?.toString();
      Logger.debug(
        '🔍 EditEmployeeDialog: Department is string/ID: $_selectedDepartmentId',
      );
    }

    if (widget.employee['designationId'] is Map<String, dynamic>) {
      _selectedDesignationId = widget.employee['designationId']['_id']
          ?.toString();
      Logger.debug(
        '🔍 EditEmployeeDialog: Designation is populated object, extracted ID: $_selectedDesignationId',
      );
    } else {
      _selectedDesignationId = widget.employee['designationId']?.toString();
      Logger.debug(
        '🔍 EditEmployeeDialog: Designation is string/ID: $_selectedDesignationId',
      );
    }

    // Load departments and designations
    _loadDepartments();
    if (_selectedDepartmentId != null) {
      _loadDesignations(_selectedDepartmentId!);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
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

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updates = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': _employeeIdController.text.trim(),
        'departmentId': _selectedDepartmentId,
        'designationId': _selectedDesignationId,
        'hourlyRate': double.tryParse(_hourlyRateController.text) ?? 0,
      };
      Logger.info(
        '🔍 EditEmployeeDialog: Updating employee ${widget.employee['_id']} with departmentId: $_selectedDepartmentId',
      );
      Logger.debug('🔍 EditEmployeeDialog: Full updates: $updates');
      // Call updateEmployee on the EmployeeProvider
      await widget.employeeProvider.updateEmployee(
        widget.employee['_id'],
        updates,
      );

      // No snackbar here; success is indicated by the dialog closing and list refreshing
      _dialogResult = true;
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred: ${e.toString()}';
      });
      _dialogResult = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(_dialogResult);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Edit Employee'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employeeIdController,
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.badge, color: colorScheme.primary),
                ),
                enabled: false, // Make Employee ID read-only
                style: TextStyle(color: Colors.grey[600]), // Gray out the text
              ),
              const SizedBox(height: 12),
              // Department Dropdown
              DropdownButtonFormField<String>(
                initialValue: () {
                  final isValid =
                      _selectedDepartmentId != null &&
                      _departments.any(
                        (dept) =>
                            dept['_id']?.toString() == _selectedDepartmentId,
                      );
                  Logger.debug(
                    '🔍 EditEmployeeDialog: Department dropdown value validation - selectedId: $_selectedDepartmentId, isValid: $isValid, availableIds: ${_departments.map((d) => d['_id']?.toString()).toList()}',
                  );
                  return isValid ? _selectedDepartmentId : null;
                }(),
                decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.business, color: colorScheme.primary),
                ),
                items: _departments.map<DropdownMenuItem<String>>((dept) {
                  return DropdownMenuItem<String>(
                    value: dept['_id']?.toString(),
                    child: Text(dept['name'] ?? 'Unknown Department'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedDesignationId =
                        null; // Reset designation when department changes
                  });
                  if (value != null) {
                    _loadDesignations(value);
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select a department' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 12),
              // Designation Dropdown
              DropdownButtonFormField<String>(
                initialValue:
                    _selectedDesignationId != null &&
                        _designations.any(
                          (designation) =>
                              designation['_id']?.toString() ==
                              _selectedDesignationId,
                        )
                    ? _selectedDesignationId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Designation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.work, color: colorScheme.primary),
                ),
                items: _designations.map<DropdownMenuItem<String>>((
                  designation,
                ) {
                  return DropdownMenuItem<String>(
                    value: designation['_id']?.toString(),
                    child: Text(designation['title'] ?? 'Unknown Designation'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDesignationId = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a designation' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hourlyRateController,
                decoration: InputDecoration(
                  labelText: 'Hourly Rate',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: colorScheme.primary,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel', style: TextStyle(color: colorScheme.onSurface)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
