import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../hitokoto_service.dart';
import '../models.dart';
import '../utils.dart';
import '../weather_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/chrome_fade.dart';
import '../widgets/timer_ring.dart';

class TimerPage extends StatelessWidget {
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
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
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
  final ValueChanged<bool> onTogglePictureInPicture;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final timer = data.timer;
    if (inPictureInPicture) {
      return PipTimerBox(snapshot: timer);
    }

    final settings = data.settings;
    final pureDisplay = quiet || oledMode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsBottom = 28.0 + MediaQuery.paddingOf(context).bottom;
        final bottomReserve = controlsBottom + 104;
        // ponytail: small top margin so chip doesn't touch screen edge
        final ambientTop = 14.0;
        final quoteTop = (constraints.maxHeight * 0.072).clamp(42.0, 76.0);
        final maxRingDimension =
            math.min(
              344.0,
              math.max(216.0, constraints.maxHeight - quoteTop - bottomReserve),
            ) *
            0.94;
        final centerY = constraints.maxHeight / 2;
        final statusTop = math
            .min(
              centerY + maxRingDimension / 2 + 14,
              constraints.maxHeight - controlsBottom - 58,
            )
            .clamp(quoteTop + 76, constraints.maxHeight - controlsBottom - 58)
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRequestQuiet,
          child: Stack(
            children: [
              Positioned(
                left: 22,
                right: 22,
                top: ambientTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  child: const _AmbientInfoLine(),
                ),
              ),
              Center(
                child: GestureDetector(
                  // ponytail: tap ring to open stats when not running
                  onTap: () {
                    if (timer.phase != TimerPhase.running) {
                      onOpenStats();
                    }
                  },
                  child: _PipReturnScale(
                  active: expandFromPictureInPicture,
                  child: _TimerFace(
                    oledMode: oledMode,
                    child: TimerProgressRing(
                      snapshot: timer,
                      maxDimension: maxRingDimension,
                      showInnerStatus: false,
                      oledMode: oledMode,
                    ),
                  ),
                ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: quoteTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  slideOffset: const Offset(0, -0.08),
                  child: _HitokotoLine(mode: timer.mode),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: statusTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  slideOffset: const Offset(0, 0.10),
                  scale: 0.98,
                  child: Center(
                    child: _PhasePill(
                      mode: timer.mode,
                      phase: timer.phase,
                      maxWidth: math.min(320, constraints.maxWidth - 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: controlsBottom,
                child: ChromeFade(
                  hidden: pureDisplay,
                  slideOffset: const Offset(0, 0.18),
                  scale: 0.96,
                  child: TimerActions(
                    controller: controller,
                    mode: timer.mode,
                    phase: timer.phase,
                    keepScreenOn: settings.keepScreenOnEnabled,
                    pictureInPictureEnabled: settings.pictureInPictureEnabled,
                    hapticsEnabled: settings.completionHapticsEnabled,
                    onOpenSettings: onOpenSettings,
                    onToggleKeepScreenOn: onToggleKeepScreenOn,
                    onTogglePictureInPicture: onTogglePictureInPicture,
                    onUiHaptic: onUiHaptic,
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

class _AmbientInfoLine extends StatefulWidget {
  const _AmbientInfoLine();

  @override
  State<_AmbientInfoLine> createState() => _AmbientInfoLineState();
}

class _AmbientInfoLineState extends State<_AmbientInfoLine> {
  static const _weatherService = WeatherService();

  WeatherSnapshot? _weather;
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
    unawaited(_loadWeather());
  }

  Future<void> _loadWeather() async {
    final weather = await _weatherService.fetch();
    if (!mounted || weather == null) {
      return;
    }
    setState(() {
      _weather = weather;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      color: scheme.onSurfaceVariant.withAlpha(210),
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    return Row(
      children: [
        _AmbientChip(
          icon: Icons.schedule,
          label: _formatTime(_now),
          iconSize: 18,
          style: labelStyle,
        ),
        const Spacer(),
        if (AppScope.read(context).data.settings.weatherEnabled)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: _AmbientChip(
                icon: _weatherIcon(_weather?.condition),
                label: _weather == null ? '--' : '${_weather!.temperatureC}°',
                iconSize: 18,
                style: labelStyle,
              ),
            ),
          ),
      ],
    );
  }
}

class _AmbientChip extends StatelessWidget {
  const _AmbientChip({
    required this.icon,
    required this.label,
    required this.style,
    this.iconSize = 15,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha(118),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

IconData _weatherIcon(String? condition) {
  return switch (condition) {
    '晴' => Icons.wb_sunny_outlined,
    '少云' => Icons.filter_drama_outlined,
    '多云' => Icons.cloud_outlined,
    '雾' => Icons.foggy,
    '雪' || '阵雪' => Icons.ac_unit,
    '雷雨' => Icons.thunderstorm_outlined,
    '雨' || '阵雨' || '毛毛雨' => Icons.water_drop_outlined,
    _ => Icons.wb_cloudy_outlined,
  };
}

class _TimerFace extends StatelessWidget {
  const _TimerFace({required this.oledMode, required this.child});

  final bool oledMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!oledMode) {
      return child;
    }
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
        ),
      ),
      child: child,
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({
    required this.mode,
    required this.phase,
    required this.maxWidth,
  });

  final TimerMode mode;
  final TimerPhase phase;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = modePalette(mode);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface.withAlpha(220),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.accent.withAlpha(90)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon(mode), size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Text('${mode.label} · ${phaseLabel(phase)}'),
            ],
          ),
        ),
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
