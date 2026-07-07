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

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  TimerMode? _displayMode;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _displayMode = widget.data.timer.mode;
  }

  @override
  void didUpdateWidget(covariant TimerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.timer.mode != _displayMode && !_flipController.isAnimating) {
      _displayMode = widget.data.timer.mode;
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleMode(TimerMode target) {
    if (widget.data.timer.phase == TimerPhase.running) return;
    if (_flipController.isAnimating) return;
    final current = _displayMode == TimerMode.focus ||
            _displayMode == TimerMode.shortBreak ||
            _displayMode == TimerMode.longBreak
        ? TimerMode.focus
        : TimerMode.countUp;
    final next = target == TimerMode.focus ? TimerMode.focus : TimerMode.countUp;
    if (current == next) return;

    final realTarget = next == TimerMode.countUp
        ? TimerMode.countUp
        : TimerMode.focus;

    _flipController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => _displayMode = realTarget);
      widget.controller.selectMode(realTarget);
    });
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.data.timer;
    if (widget.inPictureInPicture) {
      return PipTimerBox(snapshot: timer);
    }

    final settings = widget.data.settings;
    final pureDisplay = widget.quiet || widget.oledMode;
    final showMode = _displayMode ?? timer.mode;
    final isCountUpMode = showMode == TimerMode.countUp;

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsBottom = 20.0 + MediaQuery.paddingOf(context).bottom;
        final infoTop = (constraints.maxHeight * 0.20).clamp(28.0, 60.0);
        final quoteTop = (constraints.maxHeight * 0.30).clamp(70.0, 120.0);
        final bottomReserve = controlsBottom + 100;
        final maxRingDimension = math.min(
          344.0,
          math.max(216.0, constraints.maxHeight - quoteTop - bottomReserve),
        ) * 0.90;

        final progress = _flipController.value;
        final flipScale = progress <= 0.5
            ? 1.0 - (progress * 2)
            : (progress - 0.5) * 2;

        final ringWidget = Center(
          child: GestureDetector(
            onTap: () {
              if (timer.phase != TimerPhase.running) {
                _toggleMode(
                  isCountUpMode ? TimerMode.focus : TimerMode.countUp,
                );
              }
            },
            child: _PipReturnScale(
              active: widget.expandFromPictureInPicture,
              child: _TimerFace(
                oledMode: widget.oledMode,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scaleByDouble(flipScale.clamp(0.0, 1.0), 1.0, 1.0, 1.0),
                  child: TimerProgressRing(
                    snapshot: timer,
                    maxDimension: maxRingDimension,
                    showInnerStatus: false,
                    oledMode: widget.oledMode,
                  ),
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
              Positioned(
                left: 16,
                right: 16,
                top: infoTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  child: const _AmbientInfoRow(),
                ),
              ),
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
                top: quoteTop + 54,
                child: ChromeFade(
                  hidden: pureDisplay || timer.phase == TimerPhase.running,
                  slideOffset: const Offset(0, -0.04),
                  child: Center(
                    child: SegmentedButton<TimerMode>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: TimerMode.focus,
                          label: Text('番茄钟', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: TimerMode.countUp,
                          label: Text('正计时', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {isCountUpMode ? TimerMode.countUp : TimerMode.focus},
                      onSelectionChanged: (values) => _toggleMode(values.single),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: controlsBottom,
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -200) {
                      widget.onSwipeStats();
                    }
                  },
                  child: ChromeFade(
                  hidden: pureDisplay,
                  slideOffset: const Offset(0, 0.18),
                  scale: 0.96,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const _CompactAmbientInfo(),
                      const Spacer(),
                      TimerActions(
                        controller: widget.controller,
                        mode: timer.mode,
                        phase: timer.phase,
                        keepScreenOn: settings.keepScreenOnEnabled,
                        hapticsEnabled: settings.completionHapticsEnabled,
                        onOpenSettings: widget.onOpenSettings,
                        onOpenStats: widget.onOpenStats,
                        onToggleKeepScreenOn: widget.onToggleKeepScreenOn,
                        onUiHaptic: widget.onUiHaptic,
                      ),
                    ],
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

class _AmbientInfoRow extends StatefulWidget {
  const _AmbientInfoRow();

  @override
  State<_AmbientInfoRow> createState() => _AmbientInfoRowState();
}

class _AmbientInfoRowState extends State<_AmbientInfoRow> {
  static const _weatherService = WeatherService();

  WeatherSnapshot? _weather;
  late DateTime _now;
  Timer? _clockTimer;
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!mounted) return;
      unawaited(_loadWeather());
    });
    unawaited(_loadWeather());
  }

  Future<void> _loadWeather() async {
    final settings = AppScope.read(context).data.settings;
    final weather = await _weatherService.fetch(
      locationId: settings.weatherLocationId,
      apiKey: settings.weatherApiKey,
    );
    if (!mounted || weather == null) return;
    setState(() => _weather = weather);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _weatherTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = _formatTime(_now);
    final weatherStr = _weather == null
        ? '--'
        : '${_weather!.place} ${_weather!.temperatureC}°';

    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          timeStr,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        if (AppScope.read(context).data.settings.weatherEnabled) ...[
          Icon(_weatherIcon(_weather?.condition), size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            weatherStr,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactAmbientInfo extends StatelessWidget {
  const _CompactAmbientInfo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = context.findAncestorStateOfType<_AmbientInfoRowState>();
    if (state == null) return const SizedBox.shrink();
    final now = state._now;
    final weather = state._weather;
    final settings = AppScope.read(context).data.settings;
    final timeStr = _formatTime(now);
    final weatherStr = weather == null
        ? '--'
        : '${weather.place} ${weather.temperatureC}°';

    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (settings.weatherEnabled) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_weatherIcon(weather?.condition), size: 14,
                  color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    weatherStr,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      letterSpacing: 0,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
    if (_quote == null && _cachedQuote != null) {
      _quote = _cachedQuote;
    }
  }

  void _loadQuote() {
    if (_cachedQuote != null) return;
    final pending = _pendingQuote ??= _service.fetch();
    unawaited(
      pending.then((quote) {
        if (quote == null) return;
        _cachedQuote = quote;
        if (!mounted) return;
        setState(() => _quote = quote);
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
    if (!active) return child;
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
