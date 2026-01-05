import 'package:flutter/material.dart';

/// Spacing constants based on UI_UX_DESIGN_SYSTEM.md
class AppSpacing {
  AppSpacing._();

  // Spacing Scale
  static const double xs = 4; // Minimal spacing, icon padding
  static const double sm = 8; // Tight spacing, compact lists
  static const double md = 16; // Standard spacing, input padding
  static const double lg = 24; // Generous spacing, section gaps
  static const double xl = 32; // Extra large spacing

  // Legacy aliases for backward compatibility
  static const double s = sm;
  static const double m = 12; // Keep for input padding
  static const double l = md;

  // Convenience EdgeInsets
  static const EdgeInsets xsAll = EdgeInsets.all(xs);
  static const EdgeInsets smAll = EdgeInsets.all(sm);
  static const EdgeInsets mdAll = EdgeInsets.all(md);
  static const EdgeInsets lgAll = EdgeInsets.all(lg);
  static const EdgeInsets xlAll = EdgeInsets.all(xl);

  // Legacy aliases for backward compatibility
  static const EdgeInsets sAll = smAll;
  static const EdgeInsets mAll = EdgeInsets.all(m);
  static const EdgeInsets lAll = mdAll;

  // Horizontal spacing
  static const EdgeInsets xsHorizontal = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets sHorizontal = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets mHorizontal = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets lHorizontal = EdgeInsets.symmetric(horizontal: l);
  static const EdgeInsets xlHorizontal = EdgeInsets.symmetric(horizontal: xl);

  // Vertical spacing
  static const EdgeInsets xsVertical = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets sVertical = EdgeInsets.symmetric(vertical: s);
  static const EdgeInsets mVertical = EdgeInsets.symmetric(vertical: m);
  static const EdgeInsets lVertical = EdgeInsets.symmetric(vertical: l);
  static const EdgeInsets xlVertical = EdgeInsets.symmetric(vertical: xl);

  // Button padding (16h x 12v)
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: l,
    vertical: m,
  );

  // Input padding (12h x 12v)
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: m,
    vertical: m,
  );

  // Card margins (8dp all sides)
  static const EdgeInsets cardMargin = EdgeInsets.all(s);
}
