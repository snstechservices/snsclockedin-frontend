import 'package:flutter/foundation.dart';
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

/// Store for managing employee leave balances
class LeaveBalancesStore extends ChangeNotifier {
  final Map<String, LeaveBalance> _balances = {};
  String _searchQuery = '';
  EmployeeStatus? _statusFilter;

  /// Get all balances
  Map<String, LeaveBalance> get balances => Map.unmodifiable(_balances);

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

  /// Get balance for an employee ID
  LeaveBalance? getBalanceForEmployee(String employeeId) {
    return _balances[employeeId];
  }

  /// Get mock balance for an employee (stable based on ID)
  LeaveBalance _getMockBalanceForEmployee(String employeeId) {
    // Generate stable mock balances based on employee ID hash
    final hash = employeeId.hashCode;
    final annual = 15.0 + (hash % 10); // 15-24 days
    final sick = 10.0 + (hash % 5); // 10-14 days
    final casual = 5.0 + (hash % 3); // 5-7 days
    final maternity = hash % 2 == 0 ? 0.0 : 12.0;
    final paternity = hash % 3 == 0 ? 0.0 : 5.0;
    final unpaidUnlimited = hash % 2 == 0;

    return LeaveBalance(
      annual: annual,
      sick: sick,
      casual: casual,
      maternity: maternity,
      paternity: paternity,
      unpaidUnlimited: unpaidUnlimited,
    );
  }

  /// Initialize balances for employees
  void initializeBalancesForEmployees(List<Employee> employees) {
    for (final employee in employees) {
      if (!_balances.containsKey(employee.id)) {
        _balances[employee.id] = _getMockBalanceForEmployee(employee.id);
      }
    }
    notifyListeners();
  }

  /// Debug-only seed: prefill balances for given employees
  void seedDebugData(List<Employee> employees) {
    if (!kDebugMode) return;
    initializeBalancesForEmployees(employees);
  }

  /// Get filtered employee balances
  List<EmployeeLeaveBalance> getFilteredBalances(List<Employee> employees) {
    var filteredEmployees = employees;

    // Apply status filter
    if (_statusFilter != null) {
      filteredEmployees = filteredEmployees
          .where((emp) => emp.status == _statusFilter)
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredEmployees = filteredEmployees.where((emp) {
        return emp.fullName.toLowerCase().contains(query) ||
            emp.email.toLowerCase().contains(query) ||
            emp.department.toLowerCase().contains(query);
      }).toList();
    }

    // Initialize balances for filtered employees
    initializeBalancesForEmployees(filteredEmployees);

    // Return as EmployeeLeaveBalance list
    return filteredEmployees
        .map((emp) => EmployeeLeaveBalance(
              employee: emp,
              balance: _balances[emp.id] ?? _getMockBalanceForEmployee(emp.id),
            ))
        .toList();
  }
}
