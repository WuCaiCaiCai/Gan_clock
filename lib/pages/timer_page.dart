import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../hitokoto_service.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/action_buttons.dart';
import '../widgets/chrome_fade.dart';
import '../widgets/timer_ring.dart';

class TimerPage extends StatelessWidget {
  const TimerPage({
    required this.controller,
    required this.data,
    required this.quiet,
    required this.inPictureInPicture,
    required this.expandFromPictureInPicture,
    required this.onRequestQuiet,
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
    super.key,
  });

  final AppController controller;
  final TomatoData data;
  final bool quiet;
  final bool inPictureInPicture;
  final bool expandFromPictureInPicture;
  final VoidCallback onRequestQuiet;
  final ValueChanged<bool> onTogglePictureInPicture;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final timer = data.timer;
    if (inPictureInPicture) {
      return PipTimerBox(snapshot: timer);
    }

    final settings = data.settings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomReserve = actionsBottom(context) + 72;
        final quoteTop = (constraints.maxHeight * 0.10).clamp(54.0, 92.0);
        final contentOffset = (constraints.maxHeight * -0.04).clamp(
          -42.0,
          -26.0,
        );
        final maxRingDimension =
            math.min(
              318.0,
              math.max(216.0, constraints.maxHeight - quoteTop - bottomReserve),
            ) *
            0.9;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRequestQuiet,
          child: Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, contentOffset),
                  child: _PipReturnScale(
                    active: expandFromPictureInPicture,
                    child: TimerProgressRing(
                      snapshot: timer,
                      maxDimension: maxRingDimension,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: quoteTop,
                child: ChromeFade(
                  hidden: false,
                  slideOffset: const Offset(0, -0.08),
                  child: _HitokotoLine(mode: timer.mode),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: actionsBottom(context),
                child: ChromeFade(
                  hidden: quiet,
                  slideOffset: const Offset(0, 0.14),
                  child: TimerActions(
                    controller: controller,
                    mode: timer.mode,
                    phase: timer.phase,
                    keepScreenOn: settings.keepScreenOnEnabled,
                    pictureInPictureEnabled: settings.pictureInPictureEnabled,
                    hapticsEnabled: settings.completionHapticsEnabled,
                    onToggleKeepScreenOn: () {
                      controller.updateSettings(
                        settings.copyWith(
                          keepScreenOnEnabled: !settings.keepScreenOnEnabled,
                        ),
                      );
                    },
                    onTogglePictureInPicture: onTogglePictureInPicture,
                    onUiHaptic: onUiHaptic,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 16,
                child: ChromeFade(
                  hidden: quiet,
                  slideOffset: const Offset(0, -0.08),
                  child: Center(
                    child: _PhasePill(mode: timer.mode, phase: timer.phase),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.mode, required this.phase});

  final TimerMode mode;
  final TimerPhase phase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = modePalette(mode);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accent.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(modeIcon(mode), size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Text('${mode.label} · ${phaseLabel(phase)}'),
        ],
      ),
    );
  }
}

class _HitokotoLine extends StatefulWidget {
  const _HitokotoLine({required this.mode});

  final TimerMode mode;

  static const _lines = <TimerMode, List<String>>{
    TimerMode.focus: [
      '只处理眼前这一件事。',
      '把注意力收回来，时间会变清楚。',
      '慢一点，但不要停在原地。',
      '先完成一小段，再判断下一步。',
    ],
    TimerMode.shortBreak: [
      '起身，喝水，看看远处。',
      '短暂离开屏幕，也是在继续。',
      '让眼睛休息一下。',
      '五分钟足够重新换一口气。',
    ],
    TimerMode.longBreak: [
      '长休息不是中断，是恢复。',
      '走动一下，让身体接上节奏。',
      '把刚才完成的事放下片刻。',
      '休息之后，再回到清楚的开始。',
    ],
  };

  static String fallbackFor(TimerMode mode, {DateTime? at}) {
    final messages = _lines[mode]!;
    final now = at ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final dayIndex = day.difference(DateTime(now.year)).inDays;
    return messages[(dayIndex + mode.index * 2) % messages.length];
  }

  @override
  State<_HitokotoLine> createState() => _HitokotoLineState();
}

class _HitokotoLineState extends State<_HitokotoLine> {
  static const _service = HitokotoService();
  static HitokotoQuote? _cachedQuote;
  static Future<HitokotoQuote?>? _pendingQuote;

  HitokotoQuote? _quote;

  @override
  void initState() {
    super.initState();
    _quote = _cachedQuote;
    _loadQuote();
  }

  @override
  void didUpdateWidget(covariant _HitokotoLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_quote == null && _cachedQuote != null) {
      _quote = _cachedQuote;
    }
  }

  void _loadQuote() {
    if (_cachedQuote != null) {
      return;
    }
    final pending = _pendingQuote ??= _service.fetch();
    unawaited(
      pending.then((quote) {
        if (quote == null) {
          return;
        }
        _cachedQuote = quote;
        if (!mounted) {
          return;
        }
        setState(() {
          _quote = quote;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = _quote?.text ?? _HitokotoLine.fallbackFor(widget.mode);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = modePalette(widget.mode);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey('${widget.mode.name}-$message'),
        constraints: const BoxConstraints(maxWidth: 342),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface.withAlpha(190),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.accent.withAlpha(72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.format_quote, size: 18, color: palette.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipReturnScale extends StatelessWidget {
  const _PipReturnScale({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.62, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
