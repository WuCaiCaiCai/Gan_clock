import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'heatmap.dart';
import 'models.dart';
import 'platform_controls.dart';

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
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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

const _shelfSeedColor = Color(0xFF7B5A44);
const _wenKaiFontFamily = 'LXGW WenKai';
const _wenKaiFontFallback = <String>[
  '霞鹜文楷',
  '霞骛文楷',
  'LXGW WenKai Screen',
  'serif',
];

ThemeData _buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _shelfSeedColor,
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF15120F)
        : const Color(0xFFF6F0E8),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF211D18) : const Color(0xFFFFFBF6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF211D18) : const Color(0xFFFFFBF6),
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

void _syncSystemUi(BuildContext context, TimerMode mode) {
  final background = _modePalette(mode).backgroundFor(context);
  final backgroundBrightness = ThemeData.estimateBrightnessForColor(background);
  final iconBrightness = backgroundBrightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: background,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: backgroundBrightness,
      systemNavigationBarIconBrightness: iconBrightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
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

class _TomatoHomePageState extends State<TomatoHomePage>
    with WidgetsBindingObserver {
  AppController? _controller;
  Timer? _idleChromeTimer;
  int _selectedIndex = 0;
  bool _chromeHidden = false;
  bool _inPictureInPicture = false;
  bool _ignoreNextQuietTap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PlatformControls.setEventHandlers(
      onPictureInPictureChanged: _handlePictureInPictureChanged,
      onKeepScreenOnChanged: _handlePlatformKeepScreenOnChanged,
    );
  }

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
    _syncPlatformControls();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_handleControllerChanged);
    _idleChromeTimer?.cancel();
    unawaited(PlatformControls.setKeepScreenOn(false));
    unawaited(
      PlatformControls.setPipState(
        enabled: false,
        title: '',
        subtitle: '',
        keepScreenOn: false,
      ),
    );
    PlatformControls.clearEventHandlers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _requestQuiet();
      unawaited(PlatformControls.enterPictureInPicture());
    } else if (state == AppLifecycleState.resumed && _inPictureInPicture) {
      setState(() {
        _inPictureInPicture = false;
        _chromeHidden = false;
      });
      _syncIdleChrome(restart: true);
    }
  }

  void _handleControllerChanged() {
    _showControllerMessage();
    _syncIdleChrome();
    _syncPlatformControls();
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
    _syncSystemUi(context, timer.mode);
    final hideChrome =
        (_chromeHidden || _inPictureInPicture) &&
        _selectedIndex == 0 &&
        timer.phase == TimerPhase.running;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      onPointerSignal: (_) => _handleUserActivity(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        color: _modePalette(timer.mode).backgroundFor(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(
                      child: SafeArea(
                        bottom: false,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final position = Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: position,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_selectedIndex),
                            child: _pageFor(
                              controller: controller,
                              data: data,
                              quiet: hideChrome,
                              inPictureInPicture: _inPictureInPicture,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _FloatingDock(
                      hidden: hideChrome,
                      selectedIndex: _selectedIndex,
                      onSelected: _selectPage,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pageFor({
    required AppController controller,
    required TomatoData data,
    required bool quiet,
    required bool inPictureInPicture,
  }) {
    switch (_selectedIndex) {
      case 0:
        return _TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          inPictureInPicture: inPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onEnterPictureInPicture: _enterPictureInPicture,
        );
      case 1:
        return _StatsPage(data: data);
      case 2:
        return _SettingsPage(controller: controller, settings: data.settings);
      default:
        return _TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          inPictureInPicture: inPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onEnterPictureInPicture: _enterPictureInPicture,
        );
    }
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
      _chromeHidden = false;
    });
    _syncIdleChrome();
  }

  void _requestQuiet() {
    if (_ignoreNextQuietTap) {
      _ignoreNextQuietTap = false;
      return;
    }
    final controller = _controller;
    if (controller == null ||
        _selectedIndex != 0 ||
        controller.data.timer.phase != TimerPhase.running ||
        _chromeHidden) {
      return;
    }
    _idleChromeTimer?.cancel();
    _idleChromeTimer = null;
    setState(() {
      _chromeHidden = true;
    });
  }

  void _enterPictureInPicture() {
    _requestQuiet();
    unawaited(PlatformControls.enterPictureInPicture());
  }

  void _handleUserActivity() {
    if (_inPictureInPicture) {
      return;
    }
    if (_chromeHidden) {
      setState(() {
        _chromeHidden = false;
      });
      _ignoreNextQuietTap = true;
    }
    _syncIdleChrome(restart: true);
  }

  void _syncIdleChrome({bool restart = false}) {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    if (_inPictureInPicture) {
      _idleChromeTimer?.cancel();
      _idleChromeTimer = null;
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

  void _syncPlatformControls() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final timer = controller.data.timer;
    unawaited(
      PlatformControls.setKeepScreenOn(
        controller.data.settings.keepScreenOnEnabled,
      ),
    );
    unawaited(
      PlatformControls.setPipState(
        enabled: timer.phase == TimerPhase.running,
        title: formatClock(timer.remainingSeconds),
        subtitle: timer.mode.label,
        keepScreenOn: controller.data.settings.keepScreenOnEnabled,
      ),
    );
  }

  void _handlePictureInPictureChanged(bool enabled) {
    if (!mounted || _inPictureInPicture == enabled) {
      return;
    }
    setState(() {
      _inPictureInPicture = enabled;
      if (enabled) {
        _selectedIndex = 0;
        _chromeHidden = true;
      } else {
        _chromeHidden = false;
      }
    });
    _syncIdleChrome(restart: true);
  }

  void _handlePlatformKeepScreenOnChanged(bool enabled) {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    final settings = controller.data.settings;
    if (settings.keepScreenOnEnabled == enabled) {
      return;
    }
    unawaited(
      controller.updateSettings(
        settings.copyWith(keepScreenOnEnabled: enabled),
      ),
    );
  }
}

class _TimerPage extends StatelessWidget {
  const _TimerPage({
    required this.controller,
    required this.data,
    required this.quiet,
    required this.inPictureInPicture,
    required this.onRequestQuiet,
    required this.onEnterPictureInPicture,
  });

  final AppController controller;
  final TomatoData data;
  final bool quiet;
  final bool inPictureInPicture;
  final VoidCallback onRequestQuiet;
  final VoidCallback onEnterPictureInPicture;

  @override
  Widget build(BuildContext context) {
    final timer = data.timer;
    final settings = data.settings;
    if (inPictureInPicture) {
      return Center(
        child: PipTimerCapsule(
          snapshot: timer,
          keepScreenOn: settings.keepScreenOnEnabled,
          onToggleKeepScreenOn: () {
            controller.updateSettings(
              settings.copyWith(
                keepScreenOnEnabled: !settings.keepScreenOnEnabled,
              ),
            );
          },
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRequestQuiet,
      child: Stack(
        children: [
          Center(child: TimerProgressRing(snapshot: timer)),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -204),
              child: _ChromeFade(
                hidden: quiet,
                child: _HitokotoLine(mode: timer.mode),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 116 + MediaQuery.paddingOf(context).bottom,
            child: _ChromeFade(
              hidden: quiet,
              slideOffset: const Offset(0, 0.14),
              child: _TimerActions(
                controller: controller,
                mode: timer.mode,
                phase: timer.phase,
                keepScreenOn: settings.keepScreenOnEnabled,
                onToggleKeepScreenOn: () {
                  controller.updateSettings(
                    settings.copyWith(
                      keepScreenOnEnabled: !settings.keepScreenOnEnabled,
                    ),
                  );
                },
                onEnterPictureInPicture: onEnterPictureInPicture,
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 16,
            child: _ChromeFade(
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
  }
}

class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.hidden,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool hidden;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 20 + MediaQuery.paddingOf(context).bottom,
      child: _ChromeFade(
        hidden: hidden,
        slideOffset: const Offset(0, 0.18),
        child: Material(
          elevation: 10,
          shadowColor: Colors.black.withAlpha(36),
          color: Theme.of(context).colorScheme.surface.withAlpha(238),
          borderRadius: BorderRadius.circular(28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 64,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
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
        ),
      ),
    );
  }
}

class _ChromeFade extends StatelessWidget {
  const _ChromeFade({
    required this.hidden,
    required this.child,
    this.slideOffset = Offset.zero,
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
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: hidden ? slideOffset : Offset.zero,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
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
    final palette = _modePalette(mode);
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
          Icon(_modeIcon(mode), size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Text('${mode.label} · ${_phaseLabel(phase)}'),
        ],
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
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
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

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
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontFamily: _wenKaiFontFamily,
          fontFamilyFallback: _wenKaiFontFallback,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class TimerProgressRing extends StatefulWidget {
  const TimerProgressRing({required this.snapshot, super.key});

  final TimerSnapshot snapshot;

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
    final palette = _modePalette(widget.snapshot.mode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final available = math.max(180.0, shortest - 48);
        final dimension = math.min(318.0, available);

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
                            ),
                          );
                        },
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(42),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  _modeIcon(widget.snapshot.mode),
                                  key: ValueKey(widget.snapshot.mode),
                                  color: palette.accent,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatClock(widget.snapshot.remainingSeconds),
                                  textAlign: TextAlign.center,
                                  softWrap: false,
                                  style: textTheme.displayMedium?.copyWith(
                                    height: 0.96,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  _phaseLabel(widget.snapshot.phase),
                                  key: ValueKey(widget.snapshot.phase),
                                  style: textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
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
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double haloOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
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
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha((haloOpacity * 36).round());

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
        oldDelegate.haloOpacity != haloOpacity;
  }
}

class PipTimerCapsule extends StatelessWidget {
  const PipTimerCapsule({
    required this.snapshot,
    required this.keepScreenOn,
    required this.onToggleKeepScreenOn,
    super.key,
  });

  final TimerSnapshot snapshot;
  final bool keepScreenOn;
  final VoidCallback onToggleKeepScreenOn;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, snapshot.totalSeconds);
    final remaining = snapshot.remainingSeconds.clamp(0, total);
    final remainingProgress = remaining / total;
    final palette = _modePalette(snapshot.mode);
    final capsuleColor = palette.accent;
    final onCapsule = _contrastOn(capsuleColor);
    final textStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      height: 0.95,
      letterSpacing: 0,
      fontWeight: FontWeight.w800,
      color: onCapsule,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 260 || constraints.maxHeight < 120;
        final horizontalPadding = compact ? 14.0 : 18.0;
        final verticalPadding = compact ? 8.0 : 12.0;
        final side = compact ? 34.0 : 40.0;

        return Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: FractionallySizedBox(
            widthFactor: 0.92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Material(
                color: capsuleColor,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: remainingProgress.clamp(0.0, 1.0),
                        child: ColoredBox(
                          color: onCapsule.withAlpha(
                            Theme.of(context).colorScheme.brightness ==
                                    Brightness.dark
                                ? 30
                                : 24,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: side,
                            child: Center(
                              child: Icon(
                                _modeIcon(snapshot.mode),
                                size: compact ? 18 : 20,
                                color: onCapsule,
                              ),
                            ),
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatClock(snapshot.remainingSeconds),
                                textAlign: TextAlign.center,
                                softWrap: false,
                                style:
                                    textStyle ??
                                    TextStyle(
                                      fontSize: compact ? 34 : 42,
                                      color: onCapsule,
                                    ),
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: side,
                            child: IconButton(
                              tooltip: keepScreenOn ? '关闭屏幕常亮' : '开启屏幕常亮',
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: onCapsule.withAlpha(28),
                                foregroundColor: onCapsule,
                              ),
                              iconSize: compact ? 18 : 20,
                              onPressed: onToggleKeepScreenOn,
                              icon: Icon(
                                keepScreenOn
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({
    required this.controller,
    required this.mode,
    required this.phase,
    required this.keepScreenOn,
    required this.onToggleKeepScreenOn,
    required this.onEnterPictureInPicture,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool keepScreenOn;
  final VoidCallback onToggleKeepScreenOn;
  final VoidCallback onEnterPictureInPicture;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final canStop = phase != TimerPhase.idle;
    final canSkip = running && mode != TimerMode.focus;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        elevation: 10,
        shadowColor: Colors.black.withAlpha(34),
        color: scheme.surface.withAlpha(236),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: running
                    ? controller.pause
                    : () {
                        unawaited(HapticFeedback.mediumImpact());
                        controller.start();
                      },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    running ? Icons.pause : Icons.play_arrow,
                    key: ValueKey(running),
                  ),
                ),
                label: Text(running ? '暂停' : '开始'),
              ),
              OutlinedButton.icon(
                onPressed: canStop
                    ? () {
                        unawaited(HapticFeedback.heavyImpact());
                        controller.stop();
                      }
                    : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止'),
              ),
              IconButton.filledTonal(
                tooltip: keepScreenOn ? '关闭屏幕常亮' : '开启屏幕常亮',
                isSelected: keepScreenOn,
                onPressed: onToggleKeepScreenOn,
                icon: Icon(
                  keepScreenOn ? Icons.lightbulb : Icons.lightbulb_outline,
                ),
              ),
              IconButton.filledTonal(
                tooltip: '进入画中画',
                onPressed: phase == TimerPhase.running
                    ? onEnterPictureInPicture
                    : null,
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
              ),
              IconButton.filledTonal(
                tooltip: '跳过休息',
                onPressed: canSkip ? controller.skip : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.data});

  final TomatoData data;

  @override
  Widget build(BuildContext context) {
    final today = dateKey(DateTime.now());
    final todayFocusSessions = data.sessions
        .where((session) => session.isRecordable && session.dayKey == today)
        .toList();
    final todayCompletedSessions = todayFocusSessions
        .where((session) => session.isCompletedPomodoro)
        .toList();
    final todaySeconds = todayFocusSessions.fold<int>(
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
            value: '${todayCompletedSessions.length}',
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
              subtitle: Text(
                '${formatHours(session.focusedSeconds)} · ${session.completed ? '完成' : '已停止'}',
              ),
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

class _StagePalette {
  const _StagePalette({
    required this.accent,
    required this.lightBackground,
    required this.darkBackground,
  });

  final Color accent;
  final Color lightBackground;
  final Color darkBackground;

  Color backgroundFor(BuildContext context) {
    return Theme.of(context).colorScheme.brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }
}

Color _contrastOn(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

_StagePalette _modePalette(TimerMode mode) {
  switch (mode) {
    case TimerMode.focus:
      return const _StagePalette(
        accent: Color(0xFF8E3F2E),
        lightBackground: Color(0xFFF6EDE7),
        darkBackground: Color(0xFF241713),
      );
    case TimerMode.shortBreak:
      return const _StagePalette(
        accent: Color(0xFF2F7D57),
        lightBackground: Color(0xFFEAF4ED),
        darkBackground: Color(0xFF102117),
      );
    case TimerMode.longBreak:
      return const _StagePalette(
        accent: Color(0xFF236A91),
        lightBackground: Color(0xFFE8F1F7),
        darkBackground: Color(0xFF0F1D27),
      );
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
