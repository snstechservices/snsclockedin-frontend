import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/app_surface_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

class CompanySelectionScreen extends StatelessWidget {
  const CompanySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final companies = appState.companies;

    return AppScreenScaffold(
      title: 'Select Company',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a company to continue',
              style: AppTypography.lightTextTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You have access to multiple companies. Pick one to proceed to your dashboard.',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView.separated(
                itemCount: companies.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final company = companies[index];
                  final isSelected = appState.companyId == company.id;
                  return InkWell(
                    onTap: () {
                      appState.selectCompany(company.id);
                      _navigateToHome(context, appState);
                    },
                    borderRadius: AppRadius.mediumAll,
                    child: AppSurfaceCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company.name,
                                  style: AppTypography.lightTextTheme.titleMedium,
                                ),
                                if (company.roleLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    company.roleLabel!,
                                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Allow back to login
                  context.go('/login');
                },
                child: const Text('Back to login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context, AppState appState) {
    final role = appState.currentRole;
    final defaultRoute = Role.defaultRouteForRole(role);
    context.go(defaultRoute);
  }
}
