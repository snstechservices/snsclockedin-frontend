import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/storage/onboarding_storage.dart';

/// Simple representation of a company account (mock for now)
class CompanyAccount {
  const CompanyAccount({required this.id, required this.name, this.roleLabel});

  final String id;
  final String name;
  final String? roleLabel;
}

/// Global app state managing authentication and bootstrap status
class AppState extends ChangeNotifier {
  bool isBootstrapped = false;
  bool isAuthenticated = false;
  String? accessToken;
  String? userId;
  String? companyId;
  List<CompanyAccount> _companies = const [];
  bool _forceSingleCompany = false;
  bool _hasSeenOnboarding = false;
  Role _currentRole = Role.employee;

  /// Cached onboarding status (loaded during bootstrap)
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  /// Current user role (mock - defaults to employee)
  Role get currentRole => _currentRole;

  /// Available companies (mocked for now)
  List<CompanyAccount> get companies => _companies;

  /// Whether user must pick a company before proceeding
  bool get requiresCompanySelection =>
      isAuthenticated && companyId == null && _companies.length > 1;

  /// Toggle mock companies between single-company and multi-company modes (debug only)
  void setMockCompanyMode({required bool singleCompany}) {
    _forceSingleCompany = singleCompany;
  }

  /// Bootstrap the app (simulate initialization delay)
  Future<void> bootstrap() async {
    // Load onboarding status early (before delay) to cache it
    _hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
    
    // Delay to show splash screen and allow logo to load
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    isBootstrapped = true;
    notifyListeners();
  }

  /// Update onboarding status (called when user completes/skips onboarding)
  /// Updates in-memory state immediately, persists to storage asynchronously
  Future<void> setOnboardingSeen({bool value = true}) async {
    // Update in-memory state immediately (synchronous)
    _hasSeenOnboarding = value;
    notifyListeners(); // Router will redirect immediately
    
    // Persist to storage asynchronously (non-blocking)
    OnboardingStorage.setSeen(value: value);
  }

  /// Clear onboarding status (for debug/testing)
  /// Updates in-memory state immediately, persists to storage asynchronously
  Future<void> clearOnboarding() async {
    // Update in-memory state immediately (synchronous)
    _hasSeenOnboarding = false;
    notifyListeners(); // Router will redirect immediately
    
    // Persist to storage asynchronously (non-blocking)
    OnboardingStorage.clear();
  }

  /// Mock login - sets authentication state
  /// Updates state immediately, simulates network delay separately
  Future<void> loginMock({Role? role}) async {
    // Update state immediately (synchronous) - router will redirect immediately
    isAuthenticated = true;
    accessToken = 'mock-token';
    userId = 'mock-user';
    _companies = _mockCompanies();

    // Auto-select if only one company is available
    if (_companies.length == 1) {
      companyId = _companies.first.id;
    } else {
      companyId = null;
    }
    if (role != null) {
      _currentRole = role;
    }
    notifyListeners(); // Router redirect happens here, no jank
    
    // Simulate network delay separately (non-blocking for UI)
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Set user role (for testing/debugging)
  void setRole(Role role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Logout - clears authentication state
  void logout() {
    isAuthenticated = false;
    accessToken = null;
    userId = null;
    companyId = null;
    _companies = const [];
    _currentRole = Role.employee;
    notifyListeners();
  }

  /// Select a company (used by company selection flow)
  void selectCompany(String id) {
    final found = _companies.firstWhere(
      (c) => c.id == id,
      orElse: () => _companies.isNotEmpty
          ? _companies.first
          : const CompanyAccount(id: 'default-company', name: 'Default Company'),
    );
    companyId = found.id;
    _currentRole = Role.fromString(found.roleLabel);
    notifyListeners();
  }

  /// Debug helper: authenticate as a role (for testing)
  /// If not authenticated: calls loginMock(role: role)
  /// If already authenticated: just sets role
  Future<void> debugAuthenticateAs(Role role) async {
    if (!isAuthenticated) {
      await loginMock(role: role);
    } else {
      setRole(role);
    }
  }

  /// Debug helper: logout and reset role to employee
  Future<void> debugLogoutAndResetRole() async {
    logout();
  }

  /// Recheck onboarding cache (for debug harness)
  Future<void> recheckOnboardingCache() async {
    _hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
    notifyListeners();
  }

  List<CompanyAccount> _mockCompanies() {
    if (_forceSingleCompany) {
      return const [
        CompanyAccount(
          id: 'company-1',
          name: 'S&S Tech Services',
          roleLabel: 'Admin',
        ),
      ];
    }

    return const [
      CompanyAccount(
        id: 'company-1',
        name: 'S&S Tech Services',
        roleLabel: 'Admin',
      ),
      CompanyAccount(
        id: 'company-2',
        name: 'S&S Consulting',
        roleLabel: 'Employee',
      ),
    ];
  }
}
