import 'package:flutter/material.dart';

class ChromeFade extends StatelessWidget {
  const ChromeFade({
    required this.hidden,
    required this.child,
    this.slideOffset = Offset.zero,
    super.key,
  });

  final bool hidden;
  final Widget child;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: hidden ? slideOffset : Offset.zero,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}
