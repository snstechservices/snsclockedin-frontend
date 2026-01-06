import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';

/// Reusable card widget with consistent styling
///
/// Provides:
/// - White background (AppColors.surface)
/// - Rounded corners (AppRadius.mediumAll)
/// - Soft shadow
/// - Optional tap handling with InkWell
/// - Optional width constraint
/// - Optional padding and margin
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.onTap,
  });

  /// Content widget
  final Widget child;

  /// Internal padding (default: none, let child handle padding)
  final EdgeInsets? padding;

  /// External margin
  final EdgeInsets? margin;

  /// Optional width constraint
  final double? width;

  /// Optional tap callback (enables InkWell with ripple effect)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: padding != null
          ? Padding(
              padding: padding!,
              child: child,
            )
          : child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumAll,
        child: card,
      );
    }

    return card;
  }
}

