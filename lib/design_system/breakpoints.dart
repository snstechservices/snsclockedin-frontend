import 'package:flutter/material.dart';

/// Breakpoint system for responsive design
///
/// Defines standard breakpoints for mobile, tablet, and desktop layouts
/// Based on Material Design 3 breakpoints
class Breakpoints {
  Breakpoints._();

  /// Mobile breakpoint: < 600dp
  static const double mobile = 600;

  /// Tablet breakpoint: 600 - 1024dp
  static const double tablet = 1024;

  /// Desktop breakpoint: > 1024dp
  static const double desktop = 1024;

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < tablet;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Get current breakpoint type
  static BreakpointType getBreakpointType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) {
      return BreakpointType.mobile;
    } else if (width < tablet) {
      return BreakpointType.tablet;
    } else {
      return BreakpointType.desktop;
    }
  }

  /// Get responsive value based on breakpoint
  ///
  /// Returns different values for mobile, tablet, and desktop
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final type = getBreakpointType(context);
    switch (type) {
      case BreakpointType.mobile:
        return mobile;
      case BreakpointType.tablet:
        return tablet ?? mobile;
      case BreakpointType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Get responsive padding based on breakpoint
  static EdgeInsets responsivePadding(BuildContext context) {
    return responsive<EdgeInsets>(
      context: context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    );
  }

  /// Get responsive column count for grids
  static int responsiveColumns(BuildContext context) {
    return responsive<int>(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }
}

/// Breakpoint type enum
enum BreakpointType {
  mobile,
  tablet,
  desktop,
}
