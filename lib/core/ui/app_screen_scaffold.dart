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
/// - Support for drawer navigation
///
/// Example usage:
/// ```dart
/// AppScreenScaffold(
///   title: 'Dashboard',
///   actions: [IconButton(icon: Icon(Icons.settings), onPressed: () {})],
///   child: YourContent(),
/// )
/// ```
///
/// When used inside a shell (AdminShell/EmployeeShell), use `skipScaffold: true`:
/// ```dart
/// AppScreenScaffold(
///   skipScaffold: true,
///   child: YourContent(),
/// )
/// ```
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    this.title,
    this.actions,
    this.showBack = false,
    this.skipScaffold = false,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.leading,
  });

  /// Optional screen title (shows AppBar if provided)
  final String? title;

  /// Optional action buttons in app bar
  final List<Widget>? actions;

  /// Show back button (default: false)
  final bool showBack;

  /// Skip creating Scaffold (use when already inside a Scaffold, e.g., in shells)
  final bool skipScaffold;

  /// Main content widget
  final Widget child;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Optional bottom navigation bar
  final Widget? bottomNavigationBar;

  /// Optional drawer widget
  final Widget? drawer;

  /// Optional leading widget (e.g., hamburger menu icon)
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // When skipScaffold is true, don't apply horizontal padding
    // (used when content should extend to edges, e.g., TabBar)
    final content = skipScaffold
        ? SafeArea(child: child)
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
          );

    if (skipScaffold) {
      // When used inside a shell, wrap content with FAB if provided
      if (floatingActionButton != null) {
        return Stack(
          children: [
            content,
            Positioned(
              right: 16,
              bottom: 16,
              child: floatingActionButton!,
            ),
          ],
        );
      }
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (title == null &&
        !showBack &&
        leading == null &&
        (actions == null || actions!.isEmpty)) {
      return null;
    }

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: leading ??
          (showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                )
              : null),
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
