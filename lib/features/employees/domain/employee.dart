import 'package:sns_clocked_in/core/role/role.dart';

/// Employee status
enum EmployeeStatus {
  active,
  inactive,
}

/// Employee domain model
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.department,
    required this.status,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String department;
  final EmployeeStatus status;
  final Role role;

  /// Get display name for status
  String get statusDisplay {
    switch (status) {
      case EmployeeStatus.active:
        return 'Active';
      case EmployeeStatus.inactive:
        return 'Inactive';
    }
  }

  /// Get display name for role
  String get roleDisplay {
    switch (role) {
      case Role.superAdmin:
        return 'Super Admin';
      case Role.admin:
        return 'Admin';
      case Role.employee:
        return 'Employee';
    }
  }
}

