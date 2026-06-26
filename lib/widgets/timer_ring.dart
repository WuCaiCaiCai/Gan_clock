import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class TimerProgressRing extends StatefulWidget {
  const TimerProgressRing({
    required this.snapshot,
    required this.maxDimension,
    this.compact = false,
    this.showInnerStatus = true,
    this.surfaceKey,
    super.key,
  });

  final TimerSnapshot snapshot;
  final double maxDimension;
  final bool compact;
  final bool showInnerStatus;
  final Key? surfaceKey;

  @override
  State<TimerProgressRing> createState() => _TimerProgressRingState();
}

class _TimerProgressRingState extends State<TimerProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _startPulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _haloAnimation;

  @override
  void initState() {
    super.initState();
    _startPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.028,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.028,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 58,
      ),
    ]).animate(_startPulseController);
    _haloAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 66,
      ),
    ]).animate(_startPulseController);
  }

  @override
  void didUpdateWidget(covariant TimerProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final started =
        oldWidget.snapshot.phase != TimerPhase.running &&
        widget.snapshot.phase == TimerPhase.running;
    if (started) {
      _startPulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _startPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.snapshot.totalSeconds);
    final elapsed = (total - widget.snapshot.remainingSeconds).clamp(0, total);
    final progress = elapsed / total;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final palette = modePalette(widget.snapshot.mode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final edgeReserve = widget.compact ? 0.0 : 48.0;
        final minDimension = widget.compact ? 84.0 : 180.0;
        final available = math.max(minDimension, shortest - edgeReserve);
        final dimension = math.min(widget.maxDimension, available);
        final stroke = widget.compact
            ? (dimension * 0.072).clamp(7.0, 13.0).toDouble()
            : 18.0;
        final centerPadding = widget.compact
            ? (dimension * 0.24).clamp(22.0, 42.0).toDouble()
            : 42.0;
        final clockSize = widget.compact
            ? (dimension *
                      (widget.snapshot.remainingSeconds >= 3600 ? 0.16 : 0.21))
                  .clamp(18.0, 42.0)
                  .toDouble()
            : null;
        final compactTextColor = contrastOnColor(
          palette.backgroundFor(context),
        );

        return Center(
          child: AnimatedBuilder(
            animation: _startPulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: widget.snapshot.phase == TimerPhase.running
                  ? const Duration(milliseconds: 680)
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return SizedBox.square(
                  key: widget.surfaceKey,
                  dimension: dimension,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedBuilder(
                        animation: _startPulseController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _RingPainter(
                              progress: value,
                              color: palette.accent,
                              trackColor: palette.accent.withAlpha(
                                scheme.brightness == Brightness.dark ? 76 : 52,
                              ),
                              haloOpacity: _haloAnimation.value,
                              strokeWidth: stroke,
                            ),
                          );
                        },
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(centerPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!widget.compact &&
                                  widget.showInnerStatus) ...[
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    modeIcon(widget.snapshot.mode),
                                    key: ValueKey(widget.snapshot.mode),
                                    color: palette.accent,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatClock(widget.snapshot.remainingSeconds),
                                  textAlign: TextAlign.center,
                                  softWrap: false,
                                  style: textTheme.displayMedium?.copyWith(
                                    height: 0.96,
                                    letterSpacing: 0,
                                    fontSize: clockSize,
                                    fontWeight: FontWeight.w800,
                                    color: widget.compact
                                        ? compactTextColor
                                        : scheme.onSurface,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              if (!widget.compact &&
                                  widget.showInnerStatus) ...[
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    phaseLabel(widget.snapshot.phase),
                                    key: ValueKey(widget.snapshot.phase),
                                    style: textTheme.titleSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.haloOpacity,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double haloOpacity;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokeWidth;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.16
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha(36)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.55
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha((haloOpacity * 36).round());

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, shadow);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (haloOpacity > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, halo);
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.haloOpacity != haloOpacity ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class PipTimerBox extends StatelessWidget {
  const PipTimerBox({required this.snapshot, super.key});

  final TimerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = modePalette(snapshot.mode);
    final background = palette.backgroundFor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 240,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 240,
        );
        final safeShortest = math.max(96.0, shortest);
        final outerPadding = (safeShortest * 0.07).clamp(8.0, 18.0).toDouble();
        final ringDimension = (safeShortest * 0.64)
            .clamp(86.0, 220.0)
            .toDouble();

        return ColoredBox(
          color: background,
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Center(
              child: TimerProgressRing(
                snapshot: snapshot,
                maxDimension: ringDimension,
                compact: true,
                surfaceKey: const ValueKey('pip_timer_ring_surface'),
              ),
            ),
          ),
        );
      },
    );
  }
}
