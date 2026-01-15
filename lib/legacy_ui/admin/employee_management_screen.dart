import 'package:flutter/material.dart';
import 'package:sns_rooster/screens/admin/edit_employee_dialog.dart';
// Coach features disabled for this company
// import 'employee_management_with_coach.dart';
import 'package:sns_rooster/screens/admin/add_employee_dialog.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/providers/employee_provider.dart';
import '../../widgets/admin_side_navigation.dart';
import 'package:sns_rooster/screens/admin/employee_detail_screen.dart';
import 'package:sns_rooster/screens/admin/user_management_screen.dart';
import 'package:sns_rooster/theme/app_theme.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import '../../core/repository/employee_repository.dart';
import '../../services/connectivity_service.dart';
import '../../core/services/hive_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late EmployeeProvider _employeeProvider;
  List<Map<String, dynamic>> _employees = []; // Master list of all employees
  List<Map<String, dynamic>> _filteredEmployees =
      []; // List of employees to display (after filtering)

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
      _loadEmployees();
    });
  }

  void _initializeProvider() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeRepository = EmployeeRepository(
      connectivityService: ConnectivityService(),
      hiveService: HiveService(),
      apiService: ApiService(baseUrl: ApiConfig.baseUrl),
      authProvider: authProvider,
    );
    _employeeProvider = EmployeeProvider(employeeRepository);
  }

  Future<void> _loadEmployees({bool forceRefresh = false}) async {
    try {
      await _employeeProvider.getEmployees(
        showInactive: true,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        // Convert Employee models to Map for compatibility with existing UI code
        _employees = _employeeProvider.employees.map((emp) {
          final map = emp.toJson();
          // Ensure each employee has a 'name' field for detail screen
          final firstName = map['firstName'] ?? '';
          final lastName = map['lastName'] ?? '';
          map['name'] = (firstName.isNotEmpty || lastName.isNotEmpty)
              ? '$firstName${lastName.isNotEmpty ? ' $lastName' : ''}'
              : null;
          // Ensure departmentId and designationId are Maps if populated info exists
          if (emp.departmentInfo != null && map['departmentId'] is! Map) {
            map['departmentId'] = emp.departmentInfo;
          }
          if (emp.designationInfo != null && map['designationId'] is! Map) {
            map['designationId'] = emp.designationInfo;
          }
          return map;
        }).toList();
        _filteredEmployees = _employees; // Initialize filtered list
        setState(() {});
      }
    } catch (e) {
      Logger.error('EmployeeManagementScreen: Failed to load employees: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            // Coach features disabled for this company
            // key: EmployeeManagementWithCoachMarks.addButtonKey,
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) =>
                    AddEmployeeDialog(employeeProvider: _employeeProvider),
              );
              if (result == true) {
                if (mounted) {
                  _loadEmployees(); // Refresh list after add
                }
              }
            },
            tooltip: 'Add Employee',
          ),
          SizedBox(width: AppTheme.spacingS),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
            tooltip: 'User Management',
          ),
          SizedBox(width: AppTheme.spacingS),
        ],
      ),
      drawer: const AdminSideNavigation(currentRoute: '/employee_management'),
      body: Column(
        children: [
          // Quick Stats Section
          Container(
            margin: EdgeInsets.all(AppTheme.spacingL),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Employees',
                    '${_employees.length}',
                    Icons.people,
                    colorScheme.primary,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Active',
                    '${_employees.where((emp) => emp['isActive'] != false).length}',
                    Icons.check_circle,
                    AppTheme.success,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Inactive',
                    '${_employees.where((emp) => emp['isActive'] == false).length}',
                    Icons.person_off,
                    AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),

          // Employee List
          Expanded(
            child: Consumer<EmployeeProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && _employees.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null && _employees.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'Error',
                    provider.error!,
                    Icons.error,
                    colorScheme.error,
                  );
                }
                if (_filteredEmployees.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'No Employees',
                    'No employees found in the system',
                    Icons.people_outline,
                    colorScheme.primary,
                  );
                }
                return _buildEmployeeList(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a stat card
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            SizedBox(height: AppTheme.spacingXs),
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

  // Helper method to build an empty state message
  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: color),
          SizedBox(height: AppTheme.spacingL),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  // Helper method to build the employee list
  Widget _buildEmployeeList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView.builder(
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        final Widget tile = Card(
          elevation: AppTheme.elevationHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeDetailScreen(
                    employee: employee,
                    employeeProvider: _employeeProvider,
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Text(() {
                      final firstName = employee['firstName']?.toString() ?? '';
                      final lastName = employee['lastName']?.toString() ?? '';
                      if (firstName.isNotEmpty) {
                        return firstName[0].toUpperCase();
                      } else if (lastName.isNotEmpty) {
                        return lastName[0].toUpperCase();
                      }
                      return '?';
                    }(), style: TextStyle(color: colorScheme.onPrimary)),
                  ),
                  SizedBox(width: AppTheme.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${employee['firstName'] ?? ''} ${employee['lastName'] ?? ''}'
                                    .trim(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (employee['isActive'] == false)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: AppTheme.spacingXs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Display designation and department from populated data
                        Text(
                          employee['designationId']?['title'] ??
                              employee['position'] ??
                              'N/A',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (employee['departmentId']?['name'] != null ||
                            employee['department'] != null)
                          Text(
                            employee['departmentId']?['name'] ??
                                employee['department'] ??
                                'N/A',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Employment Type/Subtype
                        if (employee['employeeType'] != null &&
                            employee['employeeType'].toString().isNotEmpty)
                          Text(
                            'Employment: '
                            '${employee['employeeType']}'
                            '${employee['employeeSubType'] != null && employee['employeeSubType'].toString().isNotEmpty ? ' - ${employee['employeeSubType']}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.muted,
                            ),
                          ),
                        Text(
                          employee['email'] ?? 'N/A',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => EditEmployeeDialog(
                          employee: employee,
                          employeeProvider: _employeeProvider,
                        ),
                      );
                      if (result == true) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _loadEmployees();
                          }
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      final employeeId = employee['_id'];
                      if (employeeId != null && employeeId is String) {
                        _confirmDeleteEmployee(employeeId);
                      } else {
                        GlobalNotificationService().showError(
                          'Cannot delete employee: Employee ID is missing.',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        // Attach tutorial key to the first list tile so we can highlight how to open details
        // Coach features disabled for this company
        // if (index == 0) {
        //   return KeyedSubtree(
        //     key: EmployeeManagementWithCoachMarks.firstTileKey,
        //     child: tile,
        //   );
        // }
        return tile;
      },
    );
  }

  // Updated method to confirm and delete employee from database using provider
  Future<void> _confirmDeleteEmployee(String employeeId) async {
    if (!mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Employee'),
          content: const Text(
            'Are you sure you want to permanently delete this employee? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Use provider to delete and update UI
        final success = await _employeeProvider.deleteEmployee(employeeId);
        if (success) {
          if (!mounted) return;
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Employee deleted successfully')),
          );
          // Refresh the list - provider already updated its state
          await _loadEmployees(forceRefresh: true);
        } else {
          // If the error is a 404, treat as success
          if ((_employeeProvider.error ?? '').contains('404')) {
            if (!mounted) return;
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Employee already deleted.')),
            );
            await _loadEmployees(forceRefresh: true);
          } else {
            if (!mounted) return;
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to delete employee: ${_employeeProvider.error ?? 'Unknown error'}',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Failed to delete employee: $e')),
          );
        }
      }
    }
  }
}
