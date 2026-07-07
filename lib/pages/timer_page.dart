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
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final controlsBottom = 28.0 + MediaQuery.paddingOf(context).bottom;
        final infoTop = (constraints.maxHeight * 0.20).clamp(28.0, 60.0);
        final quoteTop = (constraints.maxHeight * 0.30).clamp(70.0, 120.0);
        final bottomReserve = controlsBottom + (landscape ? 20 : 104);
        final maxRingDimension = landscape
            ? math.min(280.0, constraints.maxHeight - 48)
            : math.min(
                344.0,
                math.max(216.0, constraints.maxHeight - quoteTop - bottomReserve),
              ) * 0.94;

        final ringWidget = Center(
          child: GestureDetector(
            onTap: () {
              if (timer.phase != TimerPhase.running) _showModeSheet(context);
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
        );

        final rightColumn = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChromeFade(
              hidden: pureDisplay,
              slideOffset: const Offset(0, -0.08),
              child: _HitokotoLine(mode: timer.mode),
            ),
            const Spacer(),
            ChromeFade(
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
          ],
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRequestQuiet,
          child: Stack(
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: infoTop,
                child: ChromeFade(
                  hidden: pureDisplay,
                  child: const _AmbientInfoLine(),
                ),
              ),
              if (landscape)
                Positioned(
                  left: 24,
                  right: 24,
                  top: quoteTop + 24,
                  bottom: controlsBottom,
                  child: Row(
                    children: [
                      Expanded(child: Center(child: ringWidget)),
                      const SizedBox(width: 24),
                      SizedBox(width: math.min(280, constraints.maxWidth * 0.35), child: rightColumn),
                    ],
                  ),
                )
              else ...[
                ringWidget,
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
            ],
          ),
        );
      },
    );
  }

  void _showModeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final ctrl = controller;
        final currentMode = ctrl.data.timer.mode;
        final isPomodoro = currentMode == TimerMode.focus ||
            currentMode == TimerMode.shortBreak ||
            currentMode == TimerMode.longBreak;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text('选择计时模式',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(modeIcon(TimerMode.focus),
                    color: isPomodoro
                        ? modePalette(TimerMode.focus).accent
                        : null),
                  title: const Text('番茄钟'),
                  subtitle: const Text('倒计时专注，自动切换休息'),
                  selected: isPomodoro,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () {
                    ctrl.selectMode(TimerMode.focus);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(modeIcon(TimerMode.countUp),
                    color: currentMode == TimerMode.countUp
                        ? modePalette(TimerMode.countUp).accent
                        : null),
                  title: const Text('正计时'),
                  subtitle: const Text('不设上限，想专注多久就多久'),
                  selected: currentMode == TimerMode.countUp,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () {
                    ctrl.selectMode(TimerMode.countUp);
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
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
    final apiKey = settings.weatherApiKey;
    if (apiKey.trim().isEmpty) return;
    final weather = await _weatherService.fetch(
      locationId: settings.weatherLocationId,
      apiKey: apiKey,
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
                label: _weather == null
                    ? '--'
                    : '${_weather!.place} ${_weather!.temperatureC}°',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
