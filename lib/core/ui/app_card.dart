import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';

/// Reusable card widget with consistent styling
///
/// Provides:
/// - White background (AppColors.surface)
/// - Rounded corners (AppRadius.mediumAll)
/// - Soft shadow with hover elevation (web/desktop)
/// - Optional tap handling with InkWell
/// - Optional width constraint
/// - Optional padding and margin
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
  });

  /// Content widget
  final Widget child;

  /// Internal padding (default: none, let child handle padding)
  final EdgeInsets? padding;

  /// External margin
  final EdgeInsets? margin;

  /// Optional width constraint
  final double? width;

  /// Optional tap callback (enables InkWell with ripple effect)
  final VoidCallback? onTap;

  /// Optional border color
  final Color? borderColor;

  /// Optional border width (default: 1)
  final double borderWidth;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0.06, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final card = AnimatedBuilder(
      animation: _elevationAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mediumAll,
            border: widget.borderColor != null
                ? Border.all(
                    color: widget.borderColor!,
                    width: widget.borderWidth,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _elevationAnimation.value),
                blurRadius: 8 + (_isHovered && isWeb ? 4 : 0),
                offset: Offset(0, 2 + (_isHovered && isWeb ? 2 : 0)),
              ),
            ],
          ),
          child: widget.padding != null
              ? Padding(
                  padding: widget.padding!,
                  child: widget.child,
                )
              : widget.child,
        );
      },
    );

    Widget result = card;

    // Add hover effect for web/desktop
    if (isWeb) {
      result = MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        child: result,
      );
    }

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.mediumAll,
        child: result,
      );
    }

    return result;
  }
}

