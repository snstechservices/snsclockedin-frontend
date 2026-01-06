import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';

/// Employees store for managing employee list
class EmployeesStore extends ChangeNotifier {
  final List<Employee> _allEmployees = [];
  String _searchQuery = '';
  EmployeeStatus? _statusFilter;

  /// Get all employees
  List<Employee> get allEmployees => List.unmodifiable(_allEmployees);

  /// Get filtered and searched employees
  List<Employee> get filteredEmployees {
    var result = _allEmployees;

    // Apply status filter
    if (_statusFilter != null) {
      result = result.where((emp) => emp.status == _statusFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((emp) {
        return emp.fullName.toLowerCase().contains(query) ||
            emp.email.toLowerCase().contains(query) ||
            emp.department.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  /// Current search query
  String get searchQuery => _searchQuery;

  /// Current status filter
  EmployeeStatus? get statusFilter => _statusFilter;

  /// Set search query
  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set status filter
  void filterByStatus(EmployeeStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    notifyListeners();
  }

  /// Initialize with sample data
  void seedSampleData() {
    if (_allEmployees.isNotEmpty) return; // Already seeded

    _allEmployees.addAll([
      const Employee(
        id: '1',
        fullName: 'John Doe',
        email: 'john.doe@example.com',
        department: 'Engineering',
        status: EmployeeStatus.active,
        role: Role.employee,
      ),
      const Employee(
        id: '2',
        fullName: 'Jane Smith',
        email: 'jane.smith@example.com',
        department: 'Marketing',
        status: EmployeeStatus.active,
        role: Role.employee,
      ),
      const Employee(
        id: '3',
        fullName: 'Bob Johnson',
        email: 'bob.johnson@example.com',
        department: 'Sales',
        status: EmployeeStatus.active,
        role: Role.employee,
      ),
      const Employee(
        id: '4',
        fullName: 'Alice Williams',
        email: 'alice.williams@example.com',
        department: 'Engineering',
        status: EmployeeStatus.active,
        role: Role.employee,
      ),
      const Employee(
        id: '5',
        fullName: 'Charlie Brown',
        email: 'charlie.brown@example.com',
        department: 'HR',
        status: EmployeeStatus.active,
        role: Role.admin,
      ),
      const Employee(
        id: '6',
        fullName: 'Diana Prince',
        email: 'diana.prince@example.com',
        department: 'Finance',
        status: EmployeeStatus.inactive,
        role: Role.employee,
      ),
      const Employee(
        id: '7',
        fullName: 'Edward Norton',
        email: 'edward.norton@example.com',
        department: 'Engineering',
        status: EmployeeStatus.active,
        role: Role.employee,
      ),
      const Employee(
        id: '8',
        fullName: 'Fiona Apple',
        email: 'fiona.apple@example.com',
        department: 'Marketing',
        status: EmployeeStatus.inactive,
        role: Role.employee,
      ),
    ]);
    notifyListeners();
  }
}

