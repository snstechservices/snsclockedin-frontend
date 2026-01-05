import 'package:flutter/material.dart';

/// Motion system for consistent animations across the app
class Motion {
  Motion._();

  // Duration tokens - optimized for snappy feel
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration base = Duration(milliseconds: 150);
  static const Duration slow = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 200); // Reduced from 260ms

  // Curve tokens
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Check if animations should be reduced
  static bool reducedMotion(BuildContext context) {
    // Use MediaQuery.disableAnimations if available (Flutter 3.16+)
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) {
      // Check for disableAnimations property
      try {
        // Access via reflection or direct property if available
        // For now, check accessibility features
        final accessibleFeatures = mediaQuery.accessibleNavigation;
        // If accessible navigation is enabled, likely reduced motion is too
        if (accessibleFeatures) {
          return true;
        }
      } catch (_) {
        // Property might not exist in older Flutter versions
      }
    }
    return false;
  }

  /// Get duration, returning zero if reduced motion is enabled
  static Duration duration(
    BuildContext context,
    Duration baseDuration,
  ) {
    if (reducedMotion(context)) {
      return Duration.zero;
    }
    return baseDuration;
  }

  /// Get curve, returning linear if reduced motion is enabled
  static Curve curve(BuildContext context, Curve baseCurve) {
    if (reducedMotion(context)) {
      return Curves.linear;
    }
    return baseCurve;
  }
}
