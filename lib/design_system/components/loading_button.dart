import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Button with loading state indicator
///
/// Shows a loading spinner when isLoading is true and disables the button.
/// Provides consistent styling and behavior across the app.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  /// Callback when button is pressed (disabled when loading)
  final VoidCallback? onPressed;

  /// Button label text
  final String label;

  /// Whether button is in loading state
  final bool isLoading;

  /// Whether to use outlined style
  final bool isOutlined;

  /// Optional icon to display before label
  final IconData? icon;

  /// Optional width constraint
  final double? width;

  @override
  Widget build(BuildContext context) {
    final button = isOutlined
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : icon != null
                    ? Icon(icon, size: 18)
                    : const SizedBox.shrink(),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              padding: AppSpacing.buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.mediumAll,
              ),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
          )
        : ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : icon != null
                    ? Icon(icon, size: 18)
                    : const SizedBox.shrink(),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              padding: AppSpacing.buttonPadding,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.mediumAll,
              ),
            ),
          );

    if (width != null) {
      return SizedBox(width: width, child: button);
    }

    return button;
  }
}
