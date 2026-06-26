import 'package:flutter/material.dart';

class ChromeFade extends StatelessWidget {
  const ChromeFade({
    required this.hidden,
    required this.child,
    this.slideOffset = Offset.zero,
    this.scale = 1,
    this.duration = const Duration(milliseconds: 240),
    super.key,
  });

  final bool hidden;
  final Widget child;
  final Offset slideOffset;
  final double scale;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 80)
        : duration;
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: effectiveDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: hidden ? slideOffset : Offset.zero,
          duration: effectiveDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: hidden ? scale : 1,
            duration: effectiveDuration,
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
      ),
    );
  }
}
