/// User profile domain model
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    this.phone,
    this.department,
    required this.roleLabel,
    this.employeeId,
  });

  final String fullName;
  final String email;
  final String? phone;
  final String? department;
  final String roleLabel; // Read-only
  final String? employeeId;

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? department,
    String? roleLabel,
    String? employeeId,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      roleLabel: roleLabel ?? this.roleLabel,
      employeeId: employeeId ?? this.employeeId,
    );
  }
}

