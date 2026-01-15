import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';

/// Loading placeholder list with optional pulsating shimmer.
///
/// Displays animated skeleton placeholders while content is loading.
/// Provides better UX than simple loading indicators.
///
/// Example usage:
/// ```dart
/// ListSkeleton(
///   items: 5,
///   itemHeight: 100,
///   shimmer: true,
/// )
/// ```
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({
    super.key,
    this.items = 4,
    this.itemHeight = 94,
    this.shimmer = true,
    this.padding,
  });

  final int items;
  final double itemHeight;
  final bool shimmer;
  final EdgeInsetsGeometry? padding;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.textSecondary.withValues(alpha: 0.07);
    final highlightColor = AppColors.textSecondary.withValues(alpha: 0.14);

    return ListView.builder(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
      itemCount: widget.items,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final color = widget.shimmer
                  ? Color.lerp(baseColor, highlightColor, _controller.value)!
                  : baseColor;
              return Container(
                height: widget.itemHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.mediumAll,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

