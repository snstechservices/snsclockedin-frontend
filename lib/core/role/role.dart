/// Role enum for user roles in SNS Clocked In
enum Role {
  /// Super admin role - highest level access
  superAdmin('super_admin'),

  /// Admin role - company-level access
  admin('admin'),

  /// Employee role - standard user access (default)
  employee('employee');

  const Role(this.value);

  /// String value of the role
  final String value;

  /// Parse role from string, defaults to employee for unknown/null values
  static Role fromString(String? value) {
    if (value == null || value.isEmpty) {
      return Role.employee;
    }

    switch (value.toLowerCase().trim()) {
      case 'super_admin':
        return Role.superAdmin;
      case 'admin':
        return Role.admin;
      case 'employee':
        return Role.employee;
      default:
        return Role.employee;
    }
  }

  /// Get the default route for a role
  static String defaultRouteForRole(Role role) {
    switch (role) {
      case Role.superAdmin:
        return '/sa/dashboard';
      case Role.admin:
        return '/a/dashboard';
      case Role.employee:
        return '/e/dashboard';
    }
  }

  /// Get the route prefix for a role
  String get routePrefix {
    switch (this) {
      case Role.superAdmin:
        return '/sa';
      case Role.admin:
        return '/a';
      case Role.employee:
        return '/e';
    }
  }
}

