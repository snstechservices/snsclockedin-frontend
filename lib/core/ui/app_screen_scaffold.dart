import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';

/// AppScreenScaffold (aka ScreenShell)
///
/// Reusable screen wrapper providing:
/// - consistent background color
/// - safe area handling
/// - responsive centered content with max width
/// - optional header, footer, and enter animation
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    // Backwards compatible: callers may still pass `child`.
    this.child,
    this.header,
    this.body,
    this.footer,
    this.maxWidth = 460.0,
    this.topPadding = AppSpacing.xl,
    this.bottomPadding = AppSpacing.md,
    this.extendBodyBehindAppBar = false,
    this.scroll = true,
    this.centerContent = true,
    this.animate = true,
  }) : assert(body != null || child != null, 'Either body or child must be provided');

  /// Backwards-compatible single child parameter
  final Widget? child;

  /// Optional header pinned above the body
  final Widget? header;

  /// Preferred body widget (use this going forward)
  final Widget? body;

  /// Optional footer pinned near bottom
  final Widget? footer;

  /// Maximum width for centered content
  final double maxWidth;

  /// Top padding added inside SafeArea
  final double topPadding;

  /// Bottom padding added (plus keyboard insets)
  final double bottomPadding;

  /// Whether to extend body behind app bar
  final bool extendBodyBehindAppBar;

  /// If true, the content scrolls when needed
  final bool scroll;

  /// If true, content will be centered horizontally (and vertically via layout)
  final bool centerContent;

  /// Enable entrance motion for the main body
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const baseHorizontal = 24.0;
    final leftPad = baseHorizontal + media.padding.left;
    final rightPad = baseHorizontal + media.padding.right;
    final availableWidth = (media.size.width - leftPad - rightPad).clamp(0.0, double.infinity);
    final contentMaxWidth = availableWidth > maxWidth ? maxWidth : availableWidth;

    final Widget contentWidget = body ?? child!;

    Widget bodyContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth),
      child: contentWidget,
    );

    if (animate && !Motion.reducedMotion(context)) {
      bodyContent = Entrance(child: bodyContent);
    }

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        // allow top area control to caller via header spacing
        top: false,
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.maxHeight;

            return SingleChildScrollView(
              physics: scroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    leftPad,
                    media.padding.top + topPadding,
                    rightPad,
                    media.viewInsets.bottom + bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) header!,

                      // Main content: take remaining space to push footer to bottom
                      Expanded(
                        child: centerContent
                            ? Center(child: bodyContent)
                            : Align(alignment: Alignment.topLeft, child: bodyContent),
                      ),

                      if (footer != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        footer!,
                        SizedBox(height: media.padding.bottom > 0 ? 0 : bottomPadding),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';

/// AppScreenScaffold (aka ScreenShell)
///
/// Reusable screen wrapper providing:
/// - consistent background color
/// - safe area handling
/// - responsive centered content with max width
/// - optional header, footer, and enter animation

/// A reusable scaffold wrapper for clean background screens with centered content.
///
/// Provides:
/// - Clean background (Theme scaffoldBackgroundColor)
/// - SafeArea handling (top: false, left/right: false)
/// - Centered content with maxWidth constraint (default 460)
/// - Scroll-safe behavior with keyboard dismiss
/// - Optional footer widget pinned near bottom
class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    // Backwards compatible: callers may still pass `child`.
    this.child,
    this.header,
    this.body,
    this.footer,
    this.maxWidth = 460.0,
    this.topPadding = AppSpacing.xl,
    this.bottomPadding = AppSpacing.md,
    this.extendBodyBehindAppBar = false,
    this.scroll = true,
    this.centerContent = true,
    this.animate = true,
  }) : assert(body != null || child != null, 'Either body or child must be provided');

  /// Backwards-compatible single child parameter
  final Widget? child;

  /// Optional header pinned above the body
  final Widget? header;

  /// Preferred body widget (use this going forward)
  final Widget? body;

  /// Optional footer pinned near bottom
  final Widget? footer;

  /// Maximum width for centered content
  final double maxWidth;

  /// Top padding added inside SafeArea
  final double topPadding;

  /// Bottom padding added (plus keyboard insets)
  final double bottomPadding;

  /// Whether to extend body behind app bar
  final bool extendBodyBehindAppBar;

  /// If true, the content scrolls when needed
  final bool scroll;

  /// If true, content will be centered horizontally (and vertically via layout)
  final bool centerContent;

  /// Enable entrance motion for the main body
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const baseHorizontal = 24.0;
    final leftPad = baseHorizontal + media.padding.left;
    final rightPad = baseHorizontal + media.padding.right;
    final availableWidth = (media.size.width - leftPad - rightPad).clamp(0.0, double.infinity);
    final contentMaxWidth = availableWidth > maxWidth ? maxWidth : availableWidth;

    final Widget contentWidget = body ?? child!;

    Widget bodyContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth),
      child: contentWidget,
    );

    if (animate && !Motion.reducedMotion(context)) {
      bodyContent = Entrance(child: bodyContent);
    }

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        // allow top area control to caller via header spacing
        top: false,
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.maxHeight;

            return SingleChildScrollView(
              physics: scroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    leftPad,
                    media.padding.top + topPadding,
                    rightPad,
                    media.viewInsets.bottom + bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) header!,

                      // Main content: take remaining space to push footer to bottom
                      Expanded(
                        child: centerContent
                            ? Center(child: bodyContent)
                            : Align(alignment: Alignment.topLeft, child: bodyContent),
                      ),

                      if (footer != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        footer!,
                        SizedBox(height: media.padding.bottom > 0 ? 0 : bottomPadding),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
