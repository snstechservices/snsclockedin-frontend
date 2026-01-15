import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Prominent primary action button for main actions
///
/// Features:
/// - Primary/purple background color
/// - Icon + label layout
/// - Full-width or constrained width
/// - Elevated shadow for prominence
///
/// Used for main actions like "Submit Admin Leave Request"
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.width,
    this.isLoading = false,
  });

  /// Button label text
  final String label;

  /// Icon to display
  final IconData icon;

  /// Callback when button is tapped
  final VoidCallback onPressed;

  /// Optional width constraint (defaults to full width)
  final double? width;

  /// Whether button is in loading state
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final buttonContent = Padding(
      padding: AppSpacing.lgAll,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          if (!isLoading) const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final button = Container(
      constraints: width != null 
          ? BoxConstraints(maxWidth: width!)
          : null,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: AppRadius.mediumAll,
          child: buttonContent,
        ),
      ),
    );

    return button;
  }
}
