import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/profile/domain/user_profile.dart';

/// Profile store for managing user profile data
class ProfileStore extends ChangeNotifier {
  UserProfile _profile = const UserProfile(
    fullName: 'John Doe',
    email: 'john.doe@example.com',
    phone: '+1 234-567-8900',
    department: 'Engineering',
    roleLabel: 'Employee',
    employeeId: 'EMP-001',
  );

  /// Current user profile
  UserProfile get profile => _profile;

  /// Update profile (only editable fields: phone, department)
  void updateProfile({
    String? phone,
    String? department,
  }) {
    _profile = _profile.copyWith(
      phone: phone,
      department: department,
    );
    notifyListeners();
  }

  /// Update role label (called when role changes)
  void updateRoleLabel(String roleLabel) {
    _profile = _profile.copyWith(roleLabel: roleLabel);
    notifyListeners();
  }
}

