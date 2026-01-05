import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';

/// Primary button component with consistent styling
/// Based on UI_UX_DESIGN_SYSTEM.md specifications
class AppButton extends StatelessWidget {
  const AppButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isOutlined = false,
    this.minSize = const Size(48, 48), // WCAG minimum touch target
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isOutlined;
  final Size minSize;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
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
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          elevation: 1.5, // Low elevation per design system
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(label),
      ),
    );
  }
}
