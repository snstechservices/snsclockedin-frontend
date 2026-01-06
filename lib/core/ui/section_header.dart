import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Reusable section header widget
///
/// Provides consistent typography and spacing for section titles
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.text, {
    super.key,
  });

  /// Section title text
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.lightTextTheme.labelLarge,
      ),
    );
  }
}

