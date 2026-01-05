import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for managing onboarding persistence
class OnboardingStorage {
  OnboardingStorage._();

  static const String _key = 'onboarding_seen_v2';

  /// Check if user has seen onboarding
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Alias for hasSeenOnboarding (for consistency)
  static Future<bool> isSeen() async {
    return hasSeenOnboarding();
  }

  /// Mark onboarding as seen
  /// If [value] is not provided, defaults to true
  static Future<void> setSeen({bool value = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Clear onboarding flag (reset to false)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}


