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
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'TomatoClock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD1493F),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F5F1),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        home: const TomatoHomePage(),
      ),
    );
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.watch(context);
    if (_controller == next) {
      return;
    }
    _controller?.removeListener(_showControllerMessage);
    _controller = next;
    _controller?.addListener(_showControllerMessage);
  }

  @override
  void dispose() {
    _controller?.removeListener(_showControllerMessage);
    super.dispose();
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
    final timer = data.timer;
    final settings = data.settings;
    final color = _modeColor(timer.mode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TomatoClock'),
        actions: [
          IconButton(
            tooltip: '同步',
            onPressed: settings.webDav.isConfigured && !controller.syncing
                ? controller.syncNow
                : null,
            icon: controller.syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _ModeSelector(
                        selected: timer.mode,
                        enabled: timer.phase != TimerPhase.running,
                        onChanged: controller.selectMode,
                      ),
                      const SizedBox(height: 26),
                      TimerProgressRing(snapshot: timer, color: color),
                      const SizedBox(height: 24),
                      _TimerActions(controller: controller, phase: timer.phase),
                      const SizedBox(height: 28),
                      _TodayStats(data: data),
                      const SizedBox(height: 16),
                      FocusHeatmap(focusSecondsByDay: data.focusSecondsByDay()),
                      const SizedBox(height: 16),
                      _RecentSessions(sessions: data.sessions.take(5).toList()),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SettingsSheet(),
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

class TimerProgressRing extends StatelessWidget {
  const TimerProgressRing({
    required this.snapshot,
    required this.color,
    super.key,
  });

  final TimerSnapshot snapshot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, snapshot.totalSeconds);
    final elapsed = (total - snapshot.remainingSeconds).clamp(0, total);
    final progress = elapsed / total;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SizedBox.square(
        dimension: 284,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingPainter(progress: progress, color: color),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_modeIcon(snapshot.mode), color: color, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    formatClock(snapshot.remainingSeconds),
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _phaseLabel(snapshot.phase),
                    style: textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF5F656B),
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

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

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
      ..color = const Color(0xFFE5DFD8);
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, 0, math.pi * 2, false, background);
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
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({required this.controller, required this.phase});

  final AppController controller;
  final TimerPhase phase;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
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
          onPressed: controller.reset,
          icon: const Icon(Icons.replay),
          label: const Text('重置'),
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
        .where((session) => session.completed && session.dayKey == today)
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
      color: Colors.white,
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
                      color: const Color(0xFF6A7178),
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

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
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
          Text('设置', style: Theme.of(context).textTheme.titleLarge),
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
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('完成音效'),
            value: settings.completionSoundEnabled,
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(completionSoundEnabled: value),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration),
            title: const Text('完成触感'),
            value: settings.completionHapticsEnabled,
            onChanged: (value) {
              controller.updateSettings(
                settings.copyWith(completionHapticsEnabled: value),
              );
            },
          ),
          const Divider(height: 28),
          Text('WebDAV', style: Theme.of(context).textTheme.titleMedium),
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
