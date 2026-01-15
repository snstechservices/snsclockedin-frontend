import 'package:flutter/foundation.dart';

/// Admin leave context store for shared filter state across tabs
/// Manages selected employee filter for cross-tab navigation
class AdminLeaveContextStore extends ChangeNotifier {
  AdminLeaveContextStore();

  // State
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedEmployeeDepartment;

  // Getters
  String? get selectedEmployeeId => _selectedEmployeeId;
  String? get selectedEmployeeName => _selectedEmployeeName;
  String? get selectedEmployeeDepartment => _selectedEmployeeDepartment;
  bool get hasSelectedEmployee => _selectedEmployeeId != null;

  /// Set selected employee filter
  void setSelectedEmployee({
    required String id,
    required String name,
    String? department,
  }) {
    if (_selectedEmployeeId != id ||
        _selectedEmployeeName != name ||
        _selectedEmployeeDepartment != department) {
      _selectedEmployeeId = id;
      _selectedEmployeeName = name;
      _selectedEmployeeDepartment = department;
      notifyListeners();
    }
  }

  /// Clear selected employee filter
  void clearSelectedEmployee() {
    if (_selectedEmployeeId != null ||
        _selectedEmployeeName != null ||
        _selectedEmployeeDepartment != null) {
      _selectedEmployeeId = null;
      _selectedEmployeeName = null;
      _selectedEmployeeDepartment = null;
      notifyListeners();
    }
  }
}
