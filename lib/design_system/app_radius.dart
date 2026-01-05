import 'package:flutter/material.dart';

/// Border radius constants based on UI_UX_DESIGN_SYSTEM.md
class AppRadius {
  AppRadius._();

  // Border Radius Scale
  static const double sm = 8; // Chips, small buttons
  static const double md = 12; // Cards, buttons, inputs
  static const double lg = 16; // Dialogs, large cards

  // Legacy aliases for backward compatibility
  static const double small = sm;
  static const double medium = md;
  static const double large = lg;

  // BorderRadius objects
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  // Legacy aliases
  static const BorderRadius smallAll = smAll;
  static const BorderRadius mediumAll = mdAll;
  static const BorderRadius largeAll = lgAll;
}
