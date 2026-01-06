import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Reusable screen scaffold with title, subtitle, and card-wrapped content
///
/// Provides:
/// - Consistent background (AppColors.background)
/// - SafeArea handling
/// - Title and optional subtitle using design system typography
/// - Content area in white card with shadow and rounded corners
/// - Responsive max width (560px) with center alignment
/// - Optional back button and action buttons
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.showBack = false,
    this.padding = AppSpacing.lgAll,
  });

  /// Screen title
  final String title;

  /// Optional subtitle below title
  final String? subtitle;

  /// Main content widget (wrapped in card)
  final Widget body;

  /// Optional action buttons in app bar
  final List<Widget>? actions;

  /// Show back button (default: false)
  final bool showBack;

  /// Padding for the content card (default: AppSpacing.lgAll)
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: AppSpacing.lgAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title section
                  _buildTitleSection(context),
                  const SizedBox(height: AppSpacing.lg),
                  // Content card
                  _buildContentCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (!showBack && (actions == null || actions!.isEmpty)) {
      return null;
    }

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
          : null,
      actions: actions,
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.lightTextTheme.headlineMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContentCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: body,
      ),
    );
  }
}
