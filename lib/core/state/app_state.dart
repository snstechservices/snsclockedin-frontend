import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/storage/onboarding_storage.dart';

/// Global app state managing authentication and bootstrap status
class AppState extends ChangeNotifier {
  bool isBootstrapped = false;
  bool isAuthenticated = false;
  String? accessToken;
  String? userId;
  String? companyId;
  bool _hasSeenOnboarding = false;

  /// Cached onboarding status (loaded during bootstrap)
  bool get hasSeenOnboarding => _hasSeenOnboarding;

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
  Future<void> loginMock() async {
    // Update state immediately (synchronous) - router will redirect immediately
    isAuthenticated = true;
    accessToken = 'mock-token';
    notifyListeners(); // Router redirect happens here, no jank
    
    // Simulate network delay separately (non-blocking for UI)
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Logout - clears authentication state
  void logout() {
    isAuthenticated = false;
    accessToken = null;
    userId = null;
    companyId = null;
    notifyListeners();
  }
}
