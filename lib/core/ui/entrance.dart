import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';

/// A widget that provides fade + slide up entrance animation
/// Disabled entirely when reduced motion is enabled
class Entrance extends StatefulWidget {
  const Entrance({
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 12.0,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double slideOffset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default duration - will be updated in didChangeDependencies
    _controller = AnimationController(
      duration: Motion.page,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      // Now we can safely access MediaQuery
      _controller.duration = Motion.duration(context, Motion.page);

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Motion.curve(context, Motion.standard),
        ),
      );

      // Reduce slide distance by 50% for faster, less noticeable animation
      _slideAnimation = Tween<Offset>(
        begin: Offset(0, widget.slideOffset / 200),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Motion.curve(context, Motion.standard),
        ),
      );

      // Start animation after delay - use microtask for faster execution
      if (widget.delay == Duration.zero) {
        // Use microtask to ensure it runs after current frame
        Future.microtask(() {
          if (mounted) {
            _controller.forward();
          }
        });
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If reduced motion, show child immediately without animation
    if (Motion.reducedMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
