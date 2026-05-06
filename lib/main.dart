import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'heatmap.dart';
import 'models.dart';

void main() {
  runApp(const TomatoApp());
}

class TomatoApp extends StatefulWidget {
  const TomatoApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<TomatoApp> createState() => _TomatoAppState();
}

class _TomatoAppState extends State<TomatoApp> {
  late final AppController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppScope(
          controller: _controller,
          child: MaterialApp(
            title: 'TomatoClock',
            debugShowCheckedModeBanner: false,
            theme: _buildAppTheme(Brightness.light),
            darkTheme: _buildAppTheme(Brightness.dark),
            themeMode: _flutterThemeMode(_controller.data.settings.themeMode),
            home: const TomatoHomePage(),
          ),
        );
      },
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFD1493F),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF12110F)
        : const Color(0xFFF8F5F1),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1C1A18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF1C1A18) : Colors.white,
    ),
  );
}

ThemeMode _flutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }

  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}

class TomatoHomePage extends StatefulWidget {
  const TomatoHomePage({super.key});

  @override
  State<TomatoHomePage> createState() => _TomatoHomePageState();
}

class _TomatoHomePageState extends State<TomatoHomePage> {
  AppController? _controller;
  Timer? _idleChromeTimer;
  int _selectedIndex = 0;
  bool _chromeHidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.watch(context);
    if (_controller == next) {
      return;
    }
    _controller?.removeListener(_handleControllerChanged);
    _controller = next;
    _controller?.addListener(_handleControllerChanged);
    _syncIdleChrome();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    _idleChromeTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    _showControllerMessage();
    _syncIdleChrome();
  }

  void _showControllerMessage() {
    final message = _controller?.takeMessage();
    if (message == null || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final data = controller.data;
    final hideChrome =
        _chromeHidden &&
        _selectedIndex == 0 &&
        data.timer.phase == TimerPhase.running;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      onPointerSignal: (_) => _handleUserActivity(),
      child: Scaffold(
        appBar: hideChrome ? null : AppBar(title: Text(_pageTitle)),
        body: SafeArea(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _TimerPage(
                      controller: controller,
                      data: data,
                      quiet: hideChrome,
                    ),
                    _StatsPage(data: data),
                    _SettingsPage(
                      controller: controller,
                      settings: data.settings,
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: hideChrome
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                    _chromeHidden = false;
                  });
                  _syncIdleChrome();
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.timer_outlined),
                    selectedIcon: Icon(Icons.timer),
                    label: '番茄钟',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: '统计',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
      ),
    );
  }

  void _handleUserActivity() {
    if (_chromeHidden) {
      setState(() {
        _chromeHidden = false;
      });
    }
    _syncIdleChrome(restart: true);
  }

  void _syncIdleChrome({bool restart = false}) {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final settings = controller.data.settings;
    final eligible =
        _selectedIndex == 0 &&
        controller.data.timer.phase == TimerPhase.running &&
        !controller.loading;

    if (!eligible) {
      _idleChromeTimer?.cancel();
      _idleChromeTimer = null;
      if (_chromeHidden) {
        setState(() {
          _chromeHidden = false;
        });
      }
      return;
    }

    if (_chromeHidden) {
      return;
    }

    if (!restart && _idleChromeTimer != null) {
      return;
    }
    _idleChromeTimer?.cancel();
    _idleChromeTimer = Timer(Duration(seconds: settings.idleFocusSeconds), () {
      if (!mounted) {
        return;
      }
      final latest = _controller?.data;
      if (_selectedIndex == 0 && latest?.timer.phase == TimerPhase.running) {
        setState(() {
          _chromeHidden = true;
        });
        _idleChromeTimer = null;
      }
    });
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 0:
        return '番茄钟';
      case 1:
        return '统计';
      case 2:
        return '设置';
      default:
        return 'TomatoClock';
    }
  }
}

class _TimerPage extends StatelessWidget {
  const _TimerPage({
    required this.controller,
    required this.data,
    required this.quiet,
  });

  final AppController controller;
  final TomatoData data;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final timer = data.timer;
    if (quiet) {
      return Center(
        child: TimerProgressRing(
          snapshot: timer,
          color: _modeColor(timer.mode),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            _ModeSelector(
              selected: timer.mode,
              enabled: timer.phase != TimerPhase.running,
              onChanged: controller.selectMode,
            ),
            const SizedBox(height: 34),
            TimerProgressRing(snapshot: timer, color: _modeColor(timer.mode)),
            const SizedBox(height: 18),
            _HitokotoLine(mode: timer.mode),
            const SizedBox(height: 24),
            _TimerActions(controller: controller, phase: timer.phase),
          ],
        ),
      ),
    );
  }
}

class _StatsPage extends StatelessWidget {
  const _StatsPage({required this.data});

  final TomatoData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _TodayStats(data: data),
            const SizedBox(height: 16),
            FocusHeatmap(focusSecondsByDay: data.focusSecondsByDay()),
            const SizedBox(height: 16),
            _RecentSessions(
              sessions: data.sessions
                  .where((session) => session.isRecordable)
                  .take(8)
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller, required this.settings});

  final AppController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('计时设置'),
                    subtitle: Text(
                      '专注 ${settings.focusMinutes} 分钟 · 短休 ${settings.shortBreakMinutes} 分钟 · 长休 ${settings.longBreakMinutes} 分钟 · 静默 ${settings.idleFocusSeconds} 秒',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openTimerSettings(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(_themeModeIcon(settings.themeMode)),
                    title: const Text('外观'),
                    subtitle: Text(settings.themeMode.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openAppearanceSettings(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.vibration),
                    title: const Text('切换提醒'),
                    subtitle: Text(
                      '${settings.completionHapticsEnabled ? '震动开启' : '震动关闭'} · ${settings.completionSoundEnabled ? '音效开启' : '音效关闭'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openFeedbackSettings(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('WebDAV 同步'),
                    subtitle: Text(
                      settings.webDav.isConfigured ? '已配置远端备份' : '未配置',
                    ),
                    trailing: controller.syncing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: controller.syncing
                        ? null
                        : () => _openWebDavSettings(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTimerSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _TimerSettingsSheet(),
    );
  }

  void _openFeedbackSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _FeedbackSettingsSheet(),
    );
  }

  void _openAppearanceSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AppearanceSettingsSheet(),
    );
  }

  void _openWebDavSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _WebDavSettingsSheet(),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final TimerMode selected;
  final bool enabled;
  final ValueChanged<TimerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<TimerMode>(
        showSelectedIcon: false,
        segments: TimerMode.values
            .map(
              (mode) => ButtonSegment<TimerMode>(
                value: mode,
                icon: Icon(_modeIcon(mode)),
                label: Text(mode.label),
              ),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: enabled
            ? (values) {
                onChanged(values.single);
              }
            : null,
      ),
    );
  }
}

class _HitokotoLine extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final messages = _lines[mode]!;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final dayIndex = day.difference(DateTime(now.year)).inDays;
    final message = messages[(dayIndex + mode.index * 2) % messages.length];
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Text(
        message,
        key: ValueKey('${mode.name}-$message'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

class TimerProgressRing extends StatefulWidget {
  const TimerProgressRing({
    required this.snapshot,
    required this.color,
    super.key,
  });

  final TimerSnapshot snapshot;
  final Color color;

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
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 72,
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

    return Center(
      child: AnimatedBuilder(
        animation: _startPulseController,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress),
          duration: widget.snapshot.phase == TimerPhase.running
              ? const Duration(milliseconds: 680)
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, child) {
            return AnimatedBuilder(
              animation: _startPulseController,
              builder: (context, _) {
                return SizedBox.square(
                  dimension: 284,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _RingPainter(
                          progress: animatedProgress,
                          color: widget.color,
                          trackColor: scheme.surfaceContainerHighest,
                          haloOpacity: _haloAnimation.value,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: Icon(
                                _modeIcon(widget.snapshot.mode),
                                key: ValueKey(widget.snapshot.mode),
                                color: widget.color,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              formatClock(widget.snapshot.remainingSeconds),
                              style: textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                _phaseLabel(widget.snapshot.phase),
                                key: ValueKey(widget.snapshot.phase),
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.haloOpacity,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double haloOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 18.0;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha((haloOpacity * 34).round());

    canvas.drawArc(rect, 0, math.pi * 2, false, background);
    if (haloOpacity > 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, halo);
    }
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.haloOpacity != haloOpacity;
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({required this.controller, required this.phase});

  final AppController controller;
  final TimerPhase phase;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final canStop = phase != TimerPhase.idle;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: running ? controller.pause : controller.start,
          icon: Icon(running ? Icons.pause : Icons.play_arrow),
          label: Text(running ? '暂停' : '开始'),
        ),
        OutlinedButton.icon(
          onPressed: canStop ? controller.stop : null,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('停止'),
        ),
        OutlinedButton.icon(
          onPressed: controller.skip,
          icon: const Icon(Icons.skip_next),
          label: const Text('跳过'),
        ),
      ],
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.data});

  final TomatoData data;

  @override
  Widget build(BuildContext context) {
    final today = dateKey(DateTime.now());
    final todaySessions = data.sessions
        .where((session) => session.isRecordable && session.dayKey == today)
        .toList();
    final todaySeconds = todaySessions.fold<int>(
      0,
      (total, session) => total + session.focusedSeconds,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final cards = [
          _StatCard(
            icon: Icons.check_circle_outline,
            label: '今日番茄',
            value: '${todaySessions.length}',
            detail: '已完成',
          ),
          _StatCard(
            icon: Icons.timer_outlined,
            label: '今日专注',
            value: formatHours(todaySeconds),
            detail: '累计时长',
          ),
          _StatCard(
            icon: Icons.all_inclusive,
            label: '总专注',
            value: formatHours(data.totalFocusSeconds),
            detail: '历史累计',
          ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                cards[index],
                if (index != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.sessions});

  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近专注', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          const Text('还没有完成的专注记录')
        else
          for (final session in sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(formatDateTime(session.endedAt)),
              subtitle: Text(formatHours(session.focusedSeconds)),
              trailing: const Icon(Icons.chevron_right),
            ),
      ],
    );
  }
}

class _TimerSettingsSheet extends StatelessWidget {
  const _TimerSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        shrinkWrap: true,
        children: [
          Text('计时设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          NumberStepper(
            icon: Icons.psychology_alt_outlined,
            label: '专注时长',
            value: settings.focusMinutes,
            min: 1,
            max: 240,
            suffix: '分钟',
            onChanged: (value) {
              controller.updateSettings(settings.copyWith(focusMinutes: value));
            },
          ),
          NumberStepper(
            icon: Icons.coffee_outlined,
            label: '短休息',
            value: settings.shortBreakMinutes,
            min: 1,
            max: 120,
            suffix: '分钟',
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(shortBreakMinutes: value),
              );
            },
          ),
          NumberStepper(
            icon: Icons.weekend_outlined,
            label: '长休息',
            value: settings.longBreakMinutes,
            min: 1,
            max: 240,
            suffix: '分钟',
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(longBreakMinutes: value),
              );
            },
          ),
          NumberStepper(
            icon: Icons.repeat,
            label: '长休间隔',
            value: settings.roundsBeforeLongBreak,
            min: 1,
            max: 12,
            suffix: '轮',
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(roundsBeforeLongBreak: value),
              );
            },
          ),
          NumberStepper(
            icon: Icons.visibility_off_outlined,
            label: '静默显示',
            value: settings.idleFocusSeconds,
            min: 5,
            max: 600,
            suffix: '秒',
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(idleFocusSeconds: value),
              );
            },
          ),
          const Divider(height: 28),
        ],
      ),
    );
  }
}

class _FeedbackSettingsSheet extends StatelessWidget {
  const _FeedbackSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shrinkWrap: true,
        children: [
          Text('切换提醒', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration),
            title: const Text('切换震动'),
            subtitle: const Text('专注和休息阶段切换时使用手机震动提醒'),
            value: settings.completionHapticsEnabled,
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(completionHapticsEnabled: value),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('切换音效'),
            subtitle: const Text('默认关闭，避免打扰；需要时可手动开启'),
            value: settings.completionSoundEnabled,
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(completionSoundEnabled: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettingsSheet extends StatelessWidget {
  const _AppearanceSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shrinkWrap: true,
        children: [
          Text('外观', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<AppThemeMode>(
            showSelectedIcon: false,
            segments: AppThemeMode.values
                .map(
                  (mode) => ButtonSegment<AppThemeMode>(
                    value: mode,
                    icon: Icon(_themeModeIcon(mode)),
                    label: Text(mode.label),
                  ),
                )
                .toList(),
            selected: {settings.themeMode},
            onSelectionChanged: (values) {
              controller.updateSettings(
                settings.copyWith(themeMode: values.single),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_themeModeIcon(settings.themeMode)),
            title: Text(settings.themeMode.label),
            subtitle: const Text('跟随系统会使用手机当前的浅色或深色设置'),
          ),
        ],
      ),
    );
  }
}

class _WebDavSettingsSheet extends StatefulWidget {
  const _WebDavSettingsSheet();

  @override
  State<_WebDavSettingsSheet> createState() => _WebDavSettingsSheetState();
}

class _WebDavSettingsSheetState extends State<_WebDavSettingsSheet> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _remotePathController;

  @override
  void initState() {
    super.initState();
    final settings = AppScope.read(context).data.settings.webDav;
    _endpointController = TextEditingController(text: settings.endpoint);
    _usernameController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _remotePathController = TextEditingController(text: settings.remotePath);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remotePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        shrinkWrap: true,
        children: [
          Text('WebDAV 同步', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link),
              labelText: '服务地址',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              labelText: '用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.key_outlined),
              labelText: '密码',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remotePathController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.folder_outlined),
              labelText: '远端路径',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _saveWebDav,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
              OutlinedButton.icon(
                onPressed: settings.webDav.isConfigured && !controller.syncing
                    ? controller.syncNow
                    : null,
                icon: controller.syncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('同步'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveWebDav() {
    final controller = AppScope.read(context);
    controller.updateWebDav(
      WebDavSettings(
        endpoint: _endpointController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remotePath: _remotePathController.text.trim().isEmpty
            ? 'tomato_clock/backup.json'
            : _remotePathController.text.trim(),
      ),
    );
  }
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: SizedBox(
        width: 168,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '减少',
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 58,
              child: Text('$value $suffix', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: '增加',
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String formatClock(int seconds) {
  final safe = math.max(0, seconds);
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final rest = safe % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String formatHours(int seconds) {
  if (seconds <= 0) {
    return '0 分钟';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    return '$minutes 分钟';
  }
  if (minutes == 0) {
    return '$hours 小时';
  }
  return '$hours 小时 $minutes 分钟';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _phaseLabel(TimerPhase phase) {
  switch (phase) {
    case TimerPhase.idle:
      return '准备开始';
    case TimerPhase.running:
      return '计时中';
    case TimerPhase.paused:
      return '已暂停';
  }
}

IconData _modeIcon(TimerMode mode) {
  switch (mode) {
    case TimerMode.focus:
      return Icons.radio_button_checked;
    case TimerMode.shortBreak:
      return Icons.local_cafe_outlined;
    case TimerMode.longBreak:
      return Icons.chair_outlined;
  }
}

Color _modeColor(TimerMode mode) {
  switch (mode) {
    case TimerMode.focus:
      return const Color(0xFFD1493F);
    case TimerMode.shortBreak:
      return const Color(0xFF2F855A);
    case TimerMode.longBreak:
      return const Color(0xFF3B6E8F);
  }
}

IconData _themeModeIcon(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return Icons.brightness_auto_outlined;
    case AppThemeMode.light:
      return Icons.light_mode_outlined;
    case AppThemeMode.dark:
      return Icons.dark_mode_outlined;
  }
}
