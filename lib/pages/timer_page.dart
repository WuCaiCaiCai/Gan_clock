import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../hitokoto_service.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/action_buttons.dart';
import '../widgets/chrome_fade.dart';
import '../widgets/timer_ring.dart';

String _fmtTime(DateTime v) {
  final l = v.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

class TimerPage extends StatefulWidget {
  const TimerPage({
    required this.controller,
    required this.data,
    required this.quiet,
    required this.oledMode,
    required this.inPictureInPicture,
    required this.expandFromPictureInPicture,
    required this.onRequestQuiet,
    required this.onOpenStats,
    required this.onOpenSettings,
    required this.onToggleKeepScreenOn,
    required this.onUiHaptic,
    required this.onSwipeStats,
    required this.pictureInPictureEnabled,
    required this.onTogglePictureInPicture,
    super.key,
  });

  final AppController controller;
  final TomatoData data;
  final bool quiet;
  final bool oledMode;
  final bool inPictureInPicture;
  final bool expandFromPictureInPicture;
  final VoidCallback onRequestQuiet;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleKeepScreenOn;
  final Future<void> Function() onUiHaptic;
  final VoidCallback onSwipeStats;
  final bool pictureInPictureEnabled;
  final ValueChanged<bool> onTogglePictureInPicture;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  bool _canSwitch = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _pressScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 1),
    ]).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeInCubic));
    _pressController.addStatusListener(_onPressStatus);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _onPressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _canSwitch) {
      _switchMode();
      _pressController.reverse();
    }
  }

  void _switchMode() {
    final timer = widget.data.timer;
    final isCountUp = timer.mode == TimerMode.countUp;
    final running = timer.phase == TimerPhase.running;
    if (running) return;
    widget.controller.selectMode(isCountUp ? TimerMode.focus : TimerMode.countUp);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pressController.removeStatusListener(_onPressStatus);
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.data.timer;
    if (widget.inPictureInPicture) {
      return PipTimerBox(snapshot: timer);
    }

    final settings = widget.data.settings;
    final pureDisplay = widget.quiet || widget.oledMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsBottom = 14.0 + MediaQuery.paddingOf(context).bottom;
        final quoteTop = (constraints.maxHeight * 0.25).clamp(60.0, 110.0);
        final bottomReserve = controlsBottom + 150;
        final maxRingDimension = math.min(
          344.0,
          math.max(216.0, constraints.maxHeight - quoteTop - bottomReserve),
        ) * 0.90;

        final ringWidget = Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) {
              if (timer.phase == TimerPhase.running) return;
              _canSwitch = true;
              HapticFeedback.heavyImpact();
              _pressController.forward();
            },
            onLongPressEnd: (_) {
              _canSwitch = false;
              if (_pressController.isCompleted) {
                _switchMode();
              }
              _pressController.reverse().then((_) => _canSwitch = false);
            },
            onLongPressCancel: () {
              _canSwitch = false;
              _pressController.reverse();
            },
            child: _PipReturnScale(
              active: widget.expandFromPictureInPicture,
              child: _TimerFace(
                oledMode: widget.oledMode,
                child: AnimatedBuilder(
                  animation: _pressController,
                  builder: (context, child) {
                    final scale = _pressController.isCompleted
                        ? 0.88
                        : _pressScale.value;
                    return Transform.scale(
                      scale: scale,
                      child: TimerProgressRing(
                        snapshot: timer,
                        maxDimension: maxRingDimension,
                        showInnerStatus: false,
                        oledMode: widget.oledMode,
                        idleText: _fmtTime(_now),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onRequestQuiet,
          child: Stack(
            children: [
              ringWidget,
              Positioned(
                left: 16,
                right: 16,
                top: quoteTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  slideOffset: const Offset(0, -0.08),
                  child: _HitokotoLine(mode: timer.mode),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: controlsBottom,
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -300) {
                      widget.onSwipeStats();
                    }
                  },
                  child: ChromeFade(
                    hidden: pureDisplay,
                    slideOffset: const Offset(0, 0.18),
                    scale: 0.96,
                    child: TimerActions(
                          controller: widget.controller,
                          mode: timer.mode,
                          phase: timer.phase,
                          keepScreenOn: settings.keepScreenOnEnabled,
                          hapticsEnabled: settings.completionHapticsEnabled,
                          onOpenSettings: widget.onOpenSettings,
                          onOpenStats: widget.onOpenStats,
                          onToggleKeepScreenOn: widget.onToggleKeepScreenOn,
                          onUiHaptic: widget.onUiHaptic,
                          pictureInPictureEnabled: widget.pictureInPictureEnabled,
                          onTogglePictureInPicture: widget.onTogglePictureInPicture,
                    ),
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

class _TimerFace extends StatelessWidget {
  const _TimerFace({required this.oledMode, required this.child});
  final bool oledMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!oledMode) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurface: const Color(0xFFAAAAAA),
          onSurfaceVariant: const Color(0xFF666666),
        ),
      ),
      child: child,
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
    TimerMode.countUp: [
      '不设限，只关注投入的时间。',
      '让时间自然流动，不被打断。',
      '沉浸进去，多久都可以。',
      '开始就是最好的计时方式。',
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
    if (_quote == null && _cachedQuote != null) _quote = _cachedQuote;
  }

  void _loadQuote() {
    if (_cachedQuote != null) return;
    final pending = _pendingQuote ??= _service.fetch();
    unawaited(pending.then((quote) {
      if (quote == null) return;
      _cachedQuote = quote;
      if (!mounted) return;
      setState(() => _quote = quote);
    }));
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
      child: Padding(
        key: ValueKey('${widget.mode.name}-$message'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Text(message, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: 0,
                )),
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
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.62, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}
