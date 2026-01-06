import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Reusable screen scaffold with consistent styling
///
/// Provides:
/// - Consistent background (AppColors.background)
/// - SafeArea handling
/// - Optional AppBar with title and actions
/// - Default horizontal padding (24px)
/// - Support for floatingActionButton and bottomNavigationBar
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    this.title,
    this.actions,
    this.showBack = false,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  /// Optional screen title (shows AppBar if provided)
  final String? title;

  /// Optional action buttons in app bar
  final List<Widget>? actions;

  /// Show back button (default: false)
  final bool showBack;

  /// Main content widget
  final Widget child;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Optional bottom navigation bar
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (title == null && !showBack && (actions == null || actions!.isEmpty)) {
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
      title: title != null
          ? Text(
              title!,
              style: AppTypography.lightTextTheme.headlineMedium,
            )
          : null,
      actions: actions,
    );
  }
}
