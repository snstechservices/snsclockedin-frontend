import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_rooster/providers/auth_provider.dart';
import 'package:sns_rooster/config/api_config.dart';
import 'package:sns_rooster/services/global_notification_service.dart';
import 'package:sns_rooster/utils/logger.dart';
import 'package:sns_rooster/widgets/admin_side_navigation.dart';
import 'package:sns_rooster/services/connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class OrganizationManagementScreen extends StatefulWidget {
  const OrganizationManagementScreen({super.key});

  @override
  State<OrganizationManagementScreen> createState() =>
      _OrganizationManagementScreenState();
}

class _OrganizationManagementScreenState
    extends State<OrganizationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalNotificationService _notificationService =
      GlobalNotificationService();

  // Data
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _employees = [];

  // Loading states
  bool _isLoading = true;
  bool _isLoadingEmployees = false;
  bool _isCreating = false;

  // Connectivity listener (no subscription needed, using addConnectivityListener)

  // Department form controllers
  final _deptNameController = TextEditingController();
  final _deptCodeController = TextEditingController();
  final _deptDescriptionController = TextEditingController();
  final _deptColorController = TextEditingController();
  final _deptBudgetController = TextEditingController();
  final _deptContactEmailController = TextEditingController();
  final _deptContactPhoneController = TextEditingController();

  // Designation form controllers
  final _desigTitleController = TextEditingController();
  final _desigCodeController = TextEditingController();
  final _desigDescriptionController = TextEditingController();
  final _desigMinSalaryController = TextEditingController();
  final _desigMaxSalaryController = TextEditingController();
  final _desigMinHourlyRateController = TextEditingController();
  final _desigMaxHourlyRateController = TextEditingController();

  // Form state
  String? _selectedDepartment;
  String? _selectedParentDepartment;
  String? _selectedHeadOfDepartment;
  String _selectedLevel = 'entry';
  bool _allowCrossDepartment = false;
  bool _requireAdminApproval = true;
  bool _isManagerial = false;
  bool _canRequestCover = true;
  bool _canCoverShift = true;
  bool _canApproveCover = false;

  // Edit state

  final List<String> _levels = [
    'entry',
    'junior',
    'mid',
    'senior',
    'lead',
    'principal',
    'manager',
    'director',
    'executive',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      // Refresh employees when switching to employees tab (index 4)
      if (_tabController.index == 4) {
        _loadEmployees();
      }
    });
    _loadData();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = ConnectivityService();
    connectivityService.addConnectivityListener((isOnline) {
      if (isOnline && mounted) {
        // Retry loading data when server comes back online
        Logger.info(
          'OrganizationManagement: Server back online, retrying data load...',
        );
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deptNameController.dispose();
    _deptCodeController.dispose();
    _deptDescriptionController.dispose();
    _deptColorController.dispose();
    _deptBudgetController.dispose();
    _deptContactEmailController.dispose();
    _deptContactPhoneController.dispose();
    _desigTitleController.dispose();
    _desigCodeController.dispose();
    _desigDescriptionController.dispose();
    _desigMinSalaryController.dispose();
    _desigMaxSalaryController.dispose();
    _desigMinHourlyRateController.dispose();
    _desigMaxHourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([_loadDepartments(), _loadDesignations()]);
    } catch (error) {
      Logger.error('OrganizationManagement: Error loading data: $error');
      _notificationService.showError(
        'Failed to load organization data: $error',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/departments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _departments = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      } else {
        throw Exception('Failed to load departments: ${response.statusCode}');
      }
    } catch (error) {
      Logger.error('OrganizationManagement: Error loading departments: $error');
      if (mounted) {
        _notificationService.showError('Failed to load departments: $error');
      }
    }
  }

  Future<void> _loadDesignations() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/designations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _designations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      } else {
        throw Exception('Failed to load designations: ${response.statusCode}');
      }
    } catch (error) {
      Logger.error(
        'OrganizationManagement: Error loading designations: $error',
      );
      if (mounted) {
        _notificationService.showError('Failed to load designations: $error');
      }
    }
  }

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/employees'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Logger.debug(
          'OrganizationManagement: Employee API response type: ${data.runtimeType}',
        );
        Logger.debug(
          'OrganizationManagement: Employee count: ${data is List ? data.length : 'Not a list'}',
        );

        // The API returns employees directly as an array, not wrapped in an object
        List<dynamic> employeesList = [];
        if (data is List) {
          employeesList = data;
        } else if (data is Map<String, dynamic>) {
          // Fallback for different response structures
          if (data.containsKey('employees')) {
            employeesList = data['employees'] ?? [];
          } else if (data.containsKey('data')) {
            employeesList = data['data'] ?? [];
          }
        }

        if (mounted) {
          setState(() {
            _employees = List<Map<String, dynamic>>.from(employeesList);
          });
          Logger.info(
            'OrganizationManagement: Loaded ${_employees.length} employees',
          );
          // Debug: Print department info for each employee
          for (var emp in _employees) {
            final deptId = emp['departmentId'];
            final deptName = deptId is Map
                ? deptId['name']
                : (deptId?.toString() ?? 'null');
            Logger.debug(
              'OrganizationManagement: Employee ${emp['firstName']} ${emp['lastName']} - departmentId: $deptId, departmentName: $deptName',
            );
          }
        }
      } else {
        throw Exception('Failed to load employees: ${response.statusCode}');
      }
    } catch (error) {
      Logger.error('OrganizationManagement: Error loading employees: $error');
      Logger.error('OrganizationManagement: Error type: ${error.runtimeType}');
      if (error is TypeError) {
        Logger.error(
          'OrganizationManagement: TypeError details: ${error.toString()}',
        );
      }
      if (mounted) {
        _notificationService.showError('Failed to load employees: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Departments', icon: Icon(Icons.business)),
            Tab(text: 'Designations', icon: Icon(Icons.work)),
            Tab(text: 'Create Dept', icon: Icon(Icons.add_business)),
            Tab(
              text: 'Create Designation',
              icon: Icon(Icons.add_business_outlined),
            ),
            Tab(text: 'Employees', icon: Icon(Icons.people)),
          ],
        ),
      ),
      drawer: const AdminSideNavigation(
        currentRoute: '/organization_management',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDepartmentsList(),
                _buildDesignationsList(),
                _buildCreateDepartmentForm(),
                _buildCreateDesignationForm(),
                _buildEmployeesView(),
              ],
            ),
    );
  }

  Widget _buildDepartmentsList() {
    if (_departments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No departments found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first department',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _departments.length,
      itemBuilder: (context, index) {
        final department = _departments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(
                int.parse(
                  department['settings']?['color']?.replaceAll('#', '0xFF') ??
                      '0xFF28a745',
                ),
              ),
              child: Text(
                department['name']?.substring(0, 1).toUpperCase() ?? 'D',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              department['name'] ?? 'Unknown Department',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (department['description'] != null)
                  Text('Description: ${department['description']}'),
                if (department['code'] != null)
                  Text('Code: ${department['code']}'),
                if (department['settings']?['budget'] != null)
                  Text('Budget: \$${department['settings']['budget']}'),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editDepartment(department);
                } else if (value == 'delete') {
                  _deleteDepartment(department);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesignationsList() {
    if (_designations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No designations found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first designation',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _designations.length,
      itemBuilder: (context, index) {
        final designation = _designations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                designation['title']?.substring(0, 1).toUpperCase() ?? 'D',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              designation['title'] ?? 'Unknown Designation',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (designation['description'] != null)
                  Text('Description: ${designation['description']}'),
                if (designation['code'] != null)
                  Text('Code: ${designation['code']}'),
                if (designation['hourlyRateRange'] != null)
                  Text(
                    'Hourly Rate: \$${designation['hourlyRateRange']['min']} - \$${designation['hourlyRateRange']['max']}/hour',
                  ),
                if (designation['salaryRange'] != null &&
                    designation['salaryRange']['min'] != null)
                  Text(
                    'Annual Salary: \$${designation['salaryRange']['min']} - \$${designation['salaryRange']['max']}',
                  ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editDesignation(designation);
                } else if (value == 'delete') {
                  _deleteDesignation(designation);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateDepartmentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Department',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Department Name
          TextFormField(
            controller: _deptNameController,
            decoration: const InputDecoration(
              labelText: 'Department Name *',
              hintText: 'e.g., Human Resources',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),

          // Department Code
          TextFormField(
            controller: _deptCodeController,
            decoration: const InputDecoration(
              labelText: 'Department Code *',
              hintText: 'e.g., HR',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.code),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _deptDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Department description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Color
          TextFormField(
            controller: _deptColorController,
            decoration: const InputDecoration(
              labelText: 'Color (Hex)',
              hintText: '#28a745',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.palette),
            ),
          ),
          const SizedBox(height: 16),

          // Budget
          TextFormField(
            controller: _deptBudgetController,
            decoration: const InputDecoration(
              labelText: 'Annual Budget',
              hintText: '25000',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Contact Email
          TextFormField(
            controller: _deptContactEmailController,
            decoration: const InputDecoration(
              labelText: 'Contact Email',
              hintText: 'hr@company.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Contact Phone
          TextFormField(
            controller: _deptContactPhoneController,
            decoration: const InputDecoration(
              labelText: 'Contact Phone',
              hintText: '+1 (555) 123-4567',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),

          // Shift Cover Settings
          const Text(
            'Shift Cover Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Allow Cross-Department Covers'),
            subtitle: const Text(
              'Allow employees from other departments to cover shifts',
            ),
            value: _allowCrossDepartment,
            onChanged: (value) {
              setState(() {
                _allowCrossDepartment = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Require Admin Approval'),
            subtitle: const Text(
              'Cross-department covers require admin approval',
            ),
            value: _requireAdminApproval,
            onChanged: (value) {
              setState(() {
                _requireAdminApproval = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createDepartment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating...'),
                      ],
                    )
                  : const Text(
                      'Create Department',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateDesignationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Designation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Title
          TextFormField(
            controller: _desigTitleController,
            decoration: const InputDecoration(
              labelText: 'Designation Title *',
              hintText: 'e.g., Senior Developer',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work),
            ),
          ),
          const SizedBox(height: 16),

          // Code
          TextFormField(
            controller: _desigCodeController,
            decoration: const InputDecoration(
              labelText: 'Designation Code *',
              hintText: 'e.g., SEN-DEV',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.code),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _desigDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Designation description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Department Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            items: _departments.map<DropdownMenuItem<String>>((dept) {
              return DropdownMenuItem<String>(
                value: dept['_id']?.toString(),
                child: Text(dept['name'] ?? 'Unknown Department'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDepartment = newValue;
              });
            },
          ),
          const SizedBox(height: 16),

          // Level Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(
              labelText: 'Level *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.trending_up),
            ),
            items: _levels.map<DropdownMenuItem<String>>((level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level.toUpperCase()),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedLevel = newValue ?? 'entry';
              });
            },
          ),
          const SizedBox(height: 24),

          // Hourly Rate Range (Primary for Australian system)
          const Text(
            'Hourly Rate Range (AUD)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _desigMinHourlyRateController,
                  decoration: const InputDecoration(
                    labelText: 'Min Hourly Rate',
                    hintText: '22',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                    suffixText: 'AUD/hour',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _desigMaxHourlyRateController,
                  decoration: const InputDecoration(
                    labelText: 'Max Hourly Rate',
                    hintText: '35',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                    suffixText: 'AUD/hour',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Annual Salary Range (Optional)
          const Text(
            'Annual Salary Range (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _desigMinSalaryController,
                  decoration: const InputDecoration(
                    labelText: 'Min Annual Salary',
                    hintText: '45000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: 'AUD/year',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _desigMaxSalaryController,
                  decoration: const InputDecoration(
                    labelText: 'Max Annual Salary',
                    hintText: '65000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: 'AUD/year',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Managerial Role
          SwitchListTile(
            title: const Text('Managerial Role'),
            subtitle: const Text(
              'This designation has management responsibilities',
            ),
            value: _isManagerial,
            onChanged: (value) {
              setState(() {
                _isManagerial = value;
              });
            },
          ),

          const SizedBox(height: 24),

          // Shift Cover Permissions
          const Text(
            'Shift Cover Permissions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Can Request Cover'),
            subtitle: const Text('Can request shift covers'),
            value: _canRequestCover,
            onChanged: (value) {
              setState(() {
                _canRequestCover = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Can Cover Shifts'),
            subtitle: const Text('Can accept shift cover requests'),
            value: _canCoverShift,
            onChanged: (value) {
              setState(() {
                _canCoverShift = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Can Approve Covers'),
            subtitle: const Text('Can approve shift cover requests (managers)'),
            value: _canApproveCover,
            onChanged: (value) {
              setState(() {
                _canApproveCover = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createDesignation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating...'),
                      ],
                    )
                  : const Text(
                      'Create Designation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesView() {
    if (_isLoadingEmployees) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No employees found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Load employees to see assignments',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group employees by department
    final Map<String, List<Map<String, dynamic>>> employeesByDepartment = {};
    for (final employee in _employees) {
      String departmentName = 'Unknown Department';

      // Check if departmentId is populated (Map with name)
      if (employee['departmentId'] is Map<String, dynamic>) {
        final deptMap = employee['departmentId'] as Map<String, dynamic>;
        departmentName = deptMap['name']?.toString() ?? 'Unknown Department';
      }
      // Check if departmentId is a string ID (not populated) - shouldn't happen but handle it
      else if (employee['departmentId'] != null &&
          employee['departmentId'].toString().isNotEmpty) {
        // If we have an ID but it's not populated, we can't get the name
        // This shouldn't happen if backend populates correctly, but fallback to old field
        departmentName =
            employee['department']?.toString() ?? 'Unknown Department';
      }
      // Fallback to old department field or Unknown
      else {
        departmentName =
            employee['department']?.toString() ?? 'Unknown Department';
      }

      if (!employeesByDepartment.containsKey(departmentName)) {
        employeesByDepartment[departmentName] = [];
      }
      employeesByDepartment[departmentName]!.add(employee);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Employees by Department',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _loadEmployees,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Employees',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...employeesByDepartment.entries.map((entry) {
            final departmentName = entry.key;
            final employees = entry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    (departmentName.isNotEmpty
                            ? departmentName.substring(0, 1)
                            : 'D')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  departmentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${employees.length} employee${employees.length == 1 ? '' : 's'}',
                ),
                children: employees.map((employee) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        '${(employee['firstName']?.toString() ?? '').isNotEmpty ? (employee['firstName'].toString().substring(0, 1)) : ''}${(employee['lastName']?.toString() ?? '').isNotEmpty ? (employee['lastName'].toString().substring(0, 1)) : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${employee['firstName']} ${employee['lastName']}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee['email'] ?? ''),
                        if (employee['designationId']?['title'] != null)
                          Text(
                            'Position: ${employee['designationId']['title']}',
                          ),
                        if (employee['hourlyRate'] != null)
                          Text('Rate: \$${employee['hourlyRate']}/hour'),
                      ],
                    ),
                    trailing: employee['isActive'] == true
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.red),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Department CRUD methods
  Future<void> _createDepartment() async {
    if (_deptNameController.text.trim().isEmpty) {
      _notificationService.showError('Department name is required');
      return;
    }

    if (_deptCodeController.text.trim().isEmpty) {
      _notificationService.showError('Department code is required');
      return;
    }

    try {
      setState(() {
        _isCreating = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final departmentData = {
        'name': _deptNameController.text.trim(),
        'code': _deptCodeController.text.trim(),
        'description': _deptDescriptionController.text.trim().isNotEmpty
            ? _deptDescriptionController.text.trim()
            : null,
        'parentDepartment': _selectedParentDepartment,
        'headOfDepartment': _selectedHeadOfDepartment,
        'settings': {
          'color': _deptColorController.text.trim().isNotEmpty
              ? _deptColorController.text.trim()
              : '#28a745',
          'budget': _deptBudgetController.text.trim().isNotEmpty
              ? double.tryParse(_deptBudgetController.text.trim())
              : null,
          'contactEmail': _deptContactEmailController.text.trim().isNotEmpty
              ? _deptContactEmailController.text.trim()
              : null,
          'contactPhone': _deptContactPhoneController.text.trim().isNotEmpty
              ? _deptContactPhoneController.text.trim()
              : null,
          'shiftCover': {
            'allowCrossDepartment': _allowCrossDepartment,
            'requireAdminApproval': _requireAdminApproval,
          },
        },
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/departments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(departmentData),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 201) {
        if (mounted) {
          _notificationService.showSuccess('Department created successfully!');
          _clearDepartmentForm();
          _loadDepartments();
          _tabController.animateTo(0); // Switch to departments list
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create department');
      }
    } catch (e) {
      Logger.error('DepartmentManagement: Error creating department: $e');
      _notificationService.showError('Failed to create department: $e');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _createDesignation() async {
    if (_desigTitleController.text.trim().isEmpty) {
      _notificationService.showError('Designation title is required');
      return;
    }

    if (_desigCodeController.text.trim().isEmpty) {
      _notificationService.showError('Designation code is required');
      return;
    }

    if (_selectedDepartment == null) {
      _notificationService.showError('Please select a department');
      return;
    }

    try {
      setState(() {
        _isCreating = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final designationData = {
        'title': _desigTitleController.text.trim(),
        'code': _desigCodeController.text.trim(),
        'description': _desigDescriptionController.text.trim().isNotEmpty
            ? _desigDescriptionController.text.trim()
            : null,
        'departmentId': _selectedDepartment,
        'level':
            _levels.indexOf(_selectedLevel) +
            1, // Convert string level to number (1-9)
        'isManagerial': _isManagerial,
        'salaryRange': {
          'min': _desigMinSalaryController.text.trim().isNotEmpty
              ? double.tryParse(_desigMinSalaryController.text.trim())
              : null,
          'max': _desigMaxSalaryController.text.trim().isNotEmpty
              ? double.tryParse(_desigMaxSalaryController.text.trim())
              : null,
          'currency': 'AUD',
        },
        'hourlyRateRange': {
          'min': _desigMinHourlyRateController.text.trim().isNotEmpty
              ? double.tryParse(_desigMinHourlyRateController.text.trim())
              : null,
          'max': _desigMaxHourlyRateController.text.trim().isNotEmpty
              ? double.tryParse(_desigMaxHourlyRateController.text.trim())
              : null,
          'currency': 'AUD',
        },
        'shiftCoverPermissions': {
          'canRequestCover': _canRequestCover,
          'canCoverShift': _canCoverShift,
          'canApproveCover': _canApproveCover,
        },
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/designations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(designationData),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 201) {
        if (mounted) {
          _notificationService.showSuccess('Designation created successfully!');
          _clearDesignationForm();
          _loadDesignations();
          _tabController.animateTo(1); // Switch to designations list
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create designation');
      }
    } catch (e) {
      Logger.error('OrganizationManagement: Error creating designation: $e');
      _notificationService.showError('Failed to create designation: $e');
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _clearDepartmentForm() {
    _deptNameController.clear();
    _deptCodeController.clear();
    _deptDescriptionController.clear();
    _deptColorController.clear();
    _deptBudgetController.clear();
    _deptContactEmailController.clear();
    _deptContactPhoneController.clear();
    _selectedParentDepartment = null;
    _selectedHeadOfDepartment = null;
    _allowCrossDepartment = false;
    _requireAdminApproval = true;
  }

  void _clearDesignationForm() {
    _desigTitleController.clear();
    _desigCodeController.clear();
    _desigDescriptionController.clear();
    _desigMinSalaryController.clear();
    _desigMaxSalaryController.clear();
    _desigMinHourlyRateController.clear();
    _desigMaxHourlyRateController.clear();
    _selectedDepartment = null;
    _selectedLevel = 'entry';
    _isManagerial = false;
    _canRequestCover = true;
    _canCoverShift = true;
    _canApproveCover = false;
  }

  void _editDepartment(Map<String, dynamic> department) {
    setState(() {
      // Populate form fields
      _deptNameController.text = department['name'] ?? '';
      _deptCodeController.text = department['code'] ?? '';
      _deptDescriptionController.text = department['description'] ?? '';
      _deptColorController.text = department['settings']?['color'] ?? '#28a745';
      _deptBudgetController.text =
          department['settings']?['budget']?.toString() ?? '';
      _deptContactEmailController.text =
          department['settings']?['contactEmail'] ?? '';
      _deptContactPhoneController.text =
          department['settings']?['contactPhone'] ?? '';
      _selectedParentDepartment = department['parentDepartmentId']?['_id']
          ?.toString();
      _allowCrossDepartment =
          department['settings']?['allowCrossDepartment'] ?? false;
      _requireAdminApproval =
          department['settings']?['requireAdminApproval'] ?? true;
      _tabController.animateTo(2); // Switch to create tab
    });
  }

  void _editDesignation(Map<String, dynamic> designation) {
    setState(() {
      // Populate form fields
      _desigTitleController.text = designation['title'] ?? '';
      _desigCodeController.text = designation['code'] ?? '';
      _desigDescriptionController.text = designation['description'] ?? '';
      _selectedDepartment = designation['departmentId']?['_id']?.toString();
      _selectedLevel = _levels[designation['level'] - 1];
      _isManagerial = designation['isManagerial'] ?? false;
      if (designation['salaryRange'] != null) {
        _desigMinSalaryController.text =
            designation['salaryRange']['min']?.toString() ?? '';
        _desigMaxSalaryController.text =
            designation['salaryRange']['max']?.toString() ?? '';
      }
      if (designation['hourlyRateRange'] != null) {
        _desigMinHourlyRateController.text =
            designation['hourlyRateRange']['min']?.toString() ?? '';
        _desigMaxHourlyRateController.text =
            designation['hourlyRateRange']['max']?.toString() ?? '';
      }
      _tabController.animateTo(3); // Switch to create tab
    });
  }

  void _deleteDepartment(Map<String, dynamic> department) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text(
          'Are you sure you want to delete "${department['name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteDepartment(department['_id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteDesignation(Map<String, dynamic> designation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Designation'),
        content: Text(
          'Are you sure you want to delete "${designation['title']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDeleteDesignation(designation['_id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteDepartment(String departmentId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/departments/$departmentId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        if (mounted) {
          _notificationService.showSuccess('Department deleted successfully!');
          _loadDepartments();
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete department');
      }
    } catch (e) {
      Logger.error('OrganizationManagement: Error deleting department: $e');
      _notificationService.showError('Error deleting department: $e');
    }
  }

  Future<void> _performDeleteDesignation(String designationId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/designations/$designationId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      if (response.statusCode == 200) {
        if (mounted) {
          _notificationService.showSuccess('Designation deleted successfully!');
          _loadDesignations();
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete designation');
      }
    } catch (e) {
      Logger.error('OrganizationManagement: Error deleting designation: $e');
      _notificationService.showError('Error deleting designation: $e');
    }
  }
}
