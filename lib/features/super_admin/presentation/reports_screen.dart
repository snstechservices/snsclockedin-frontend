import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Super admin reports screen
class SuperAdminReportsScreen extends StatelessWidget {
  const SuperAdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      title: 'System Reports',
      body: _buildComingSoonPlaceholder(
        context,
        Icons.assessment_outlined,
      ),
    );
  }

  Widget _buildComingSoonPlaceholder(BuildContext context, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Coming soon',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

