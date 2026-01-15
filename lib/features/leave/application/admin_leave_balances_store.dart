import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/employees/domain/employee.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_balance.dart';

/// Model for employee leave balance with employee info
class EmployeeLeaveBalance {
  const EmployeeLeaveBalance({
    required this.employee,
    required this.balance,
  });

  final Employee employee;
  final LeaveBalance balance;
}

/// Admin store for managing employee leave balances
/// Phase 1: Mock data only, no API calls
class AdminLeaveBalancesStore extends ChangeNotifier {
  AdminLeaveBalancesStore();

  // State
  List<EmployeeLeaveBalance> _employees = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  EmployeeStatus? _statusFilter;

  // Getters
  List<EmployeeLeaveBalance> get employees => List.unmodifiable(_employees);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  EmployeeStatus? get statusFilter => _statusFilter;

  /// Get filtered employees (applies search + status filter)
  List<EmployeeLeaveBalance> get filteredEmployees {
    var filtered = _employees;

    // Apply status filter
    if (_statusFilter != null) {
      filtered = filtered
          .where((eb) => eb.employee.status == _statusFilter)
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((eb) {
        final emp = eb.employee;
        return emp.fullName.toLowerCase().contains(query) ||
            emp.email.toLowerCase().contains(query) ||
            emp.department.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Set search query
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Set status filter
  void setStatusFilter(EmployeeStatus? status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      notifyListeners();
    }
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    notifyListeners();
  }

  /// Load employees with balances (Phase 1: mock only)
  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // In Phase 1, use seeded data
      if (_employees.isEmpty) {
        seedDemo();
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await load(forceRefresh: true);
  }

  /// Seed demo data (at least 8 employees with mix of active/inactive)
  void seedDemo() {
    _employees = [
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-1',
          fullName: 'John Doe',
          email: 'john.doe@example.com',
          department: 'Engineering',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 18.5,
          sick: 12.0,
          casual: 6.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: true,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-2',
          fullName: 'Jane Smith',
          email: 'jane.smith@example.com',
          department: 'Marketing',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 22.0,
          sick: 10.0,
          casual: 5.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: false,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-3',
          fullName: 'Alice Williams',
          email: 'alice.williams@example.com',
          department: 'Sales',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 15.0,
          sick: 14.0,
          casual: 7.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: true,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-4',
          fullName: 'Bob Johnson',
          email: 'bob.johnson@example.com',
          department: 'Operations',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 20.0,
          sick: 11.0,
          casual: 5.5,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: false,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-5',
          fullName: 'Charlie Brown',
          email: 'charlie.brown@example.com',
          department: 'HR',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 16.5,
          sick: 13.0,
          casual: 6.5,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: true,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-6',
          fullName: 'Diana Prince',
          email: 'diana.prince@example.com',
          department: 'Finance',
          status: EmployeeStatus.active,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 19.0,
          sick: 10.5,
          casual: 5.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: false,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-7',
          fullName: 'Edward Norton',
          email: 'edward.norton@example.com',
          department: 'Engineering',
          status: EmployeeStatus.inactive,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 0.0,
          sick: 0.0,
          casual: 0.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: false,
        ),
      ),
      EmployeeLeaveBalance(
        employee: Employee(
          id: 'emp-8',
          fullName: 'Fiona Green',
          email: 'fiona.green@example.com',
          department: 'Marketing',
          status: EmployeeStatus.inactive,
          role: Role.employee,
        ),
        balance: LeaveBalance(
          annual: 0.0,
          sick: 0.0,
          casual: 0.0,
          maternity: 0.0,
          paternity: 0.0,
          unpaidUnlimited: false,
        ),
      ),
    ];

    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear demo data
  void clearDemo() {
    _employees = [];
    _searchQuery = '';
    _statusFilter = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
