import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';

/// A widget that provides subtle scale feedback on press
/// Uses Listener to detect pointer events without interfering with button taps
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.scale = 0.98,
    super.key,
  });

  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Motion.base,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Motion.standard,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (Motion.reducedMotion(context)) return;
    _controller.forward();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (Motion.reducedMotion(context)) return;
    _controller.reverse();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (Motion.reducedMotion(context)) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reducedMotion(context)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
