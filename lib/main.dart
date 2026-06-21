import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'heatmap.dart';
import 'hitokoto_service.dart';
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
  AppThemeMode _themeMode = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
    _controller.addListener(_onAppConfigChanged);
    _themeMode = _controller.data.settings.themeMode;
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

  void _onAppConfigChanged() {
    final newThemeMode = _controller.data.settings.themeMode;
    if (newThemeMode != _themeMode) {
      setState(() {
        _themeMode = newThemeMode;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAppConfigChanged);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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
        title: '苷',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(Brightness.light),
        darkTheme: _buildAppTheme(Brightness.dark),
        themeMode: _flutterThemeMode(_themeMode),
        home: const TomatoHomePage(),
      ),
    );
  }
}

const _shelfSeedColor = Color(0xFF646464);
const _dockHeight = 58.0;
const _dockBottomMargin = 14.0;
const _dockHorizontalMargin = 24.0;
const _actionDockGap = 12.0;

double _dockBottom(BuildContext context) {
  return _dockBottomMargin + MediaQuery.paddingOf(context).bottom;
}

double _actionsBottom(BuildContext context) {
  return _dockBottom(context) + _dockHeight + _actionDockGap;
}

const _localBackupSuccessMessageToken = 'LOCAL_BACKUP_SUCCESS';
const _localRestoreSuccessMessageToken = 'LOCAL_RESTORE_SUCCESS';
const _cloudRestoreSuccessMessageToken = 'CLOUD_RESTORE_SUCCESS';

bool get _usesLinuxPersistentNotification =>
    defaultTargetPlatform == TargetPlatform.linux;

ThemeData _buildAppTheme(Brightness brightness) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: _shelfSeedColor,
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  final scheme = baseScheme.copyWith(
    primary: dark ? const Color(0xFFD0D0D0) : const Color(0xFF4C4C4C),
    onPrimary: dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
    primaryContainer: dark ? const Color(0xFF3A3A3A) : const Color(0xFFDADADA),
    onPrimaryContainer: dark
        ? const Color(0xFFECECEC)
        : const Color(0xFF2A2A2A),
    secondary: dark ? const Color(0xFFBDBDBD) : const Color(0xFF5B5B5B),
    onSecondary: dark ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF),
    surface: dark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7),
    surfaceContainerHighest: dark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFE7E7E7),
    onSurfaceVariant: dark ? const Color(0xFFBFBFBF) : const Color(0xFF555555),
    outlineVariant: dark ? const Color(0xFF444444) : const Color(0xFFC8C8C8),
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF151515)
        : const Color(0xFFF1F1F1),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1F1F1F) : const Color(0xFFFAFAFA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF1F1F1F) : const Color(0xFFFAFAFA),
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

void _syncSystemUi(
  BuildContext context,
  Color background, {
  required bool immersive,
}) {
  final backgroundBrightness = ThemeData.estimateBrightnessForColor(background);
  final iconBrightness = backgroundBrightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  unawaited(
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    ),
  );
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

Color _pageBackground({
  required BuildContext context,
  required int selectedIndex,
  required TimerMode timerMode,
}) {
  if (selectedIndex == 0) {
    return _modePalette(timerMode).backgroundFor(context);
  }
  return Theme.of(context).scaffoldBackgroundColor;
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
  Timer? _pipChromeRestoreTimer;
  Timer? _pipReturnTimer;
  int _selectedIndex = 0;
  bool _settingsSubPageOpen = false;
  bool _statsSubPageOpen = false;
  bool _chromeHidden = false;
  bool _inPictureInPicture = false;
  bool _pipTransitioning = false;
  bool _returningFromPictureInPicture = false;
  bool _ignoreNextQuietTap = false;
  bool _notificationPermissionChecked = false;
  bool _notificationPromptVisible = false;
  bool? _lastKeepScreenOnSent;
  bool? _lastPipEnabledSent;
  String? _lastPipTitleSent;
  String? _lastPipSubtitleSent;
  bool? _lastPipKeepScreenOnSent;
  bool? _lastNotificationEnabledSent;
  String? _lastNotificationTitleSent;
  String? _lastNotificationSubtitleSent;
  int? _lastNotificationTotalSecondsSent;
  int? _lastNotificationRemainingSecondsSent;

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
    _requestNotificationPermissionIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_handleControllerChanged);
    _idleChromeTimer?.cancel();
    _pipChromeRestoreTimer?.cancel();
    _pipReturnTimer?.cancel();
    unawaited(PlatformControls.setKeepScreenOn(false));
    unawaited(
      PlatformControls.setTimerNotification(
        enabled: false,
        title: '',
        subtitle: '',
        totalSeconds: 1,
        remainingSeconds: 1,
      ),
    );
    unawaited(
      PlatformControls.setPipState(
        enabled: false,
        title: '',
        subtitle: '',
        keepScreenOn: false,
        totalSeconds: 1,
        remainingSeconds: 1,
      ),
    );
    PlatformControls.clearEventHandlers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_controller?.syncBeforeBackground() ?? Future<void>.value());
      final controller = _controller;
      if (controller != null &&
          controller.data.settings.pictureInPictureEnabled) {
        _prepareForPictureInPicture();
      }
    } else if (state == AppLifecycleState.resumed &&
        (_inPictureInPicture || _pipTransitioning)) {
      _beginPictureInPictureReturn();
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
    if (message == _localBackupSuccessMessageToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final controller = _controller;
        if (controller == null) {
          return;
        }
        final path = controller.lastLocalBackupPath ?? '';
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('本地同步完成'),
              content: Text(
                path.isEmpty ? '本地同步文件已保存。' : '本地同步文件已保存到：\n$path',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      });
      return;
    }
    if (message == _localRestoreSuccessMessageToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('本地恢复完成，当前数据已替换为同步内容')));
      });
      return;
    }
    if (message == _cloudRestoreSuccessMessageToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('云端恢复完成，当前数据已替换为远端同步内容')),
          );
      });
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

  Future<void> _requestNotificationPermissionIfNeeded() async {
    if (_notificationPermissionChecked || _notificationPromptVisible) {
      return;
    }
    _notificationPermissionChecked = true;
    final granted = await PlatformControls.requestNotificationPermission();
    if (granted || !mounted) {
      return;
    }
    _notificationPromptVisible = true;
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('通知权限未开启'),
          content: const Text('后台进度通知需要通知权限，请在系统设置中允许通知。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
    _notificationPromptVisible = false;
    if (shouldOpenSettings == true) {
      await PlatformControls.openNotificationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final data = controller.data;
    final timer = data.timer;
    final pipPreview = _inPictureInPicture || _pipTransitioning;
    final hideChrome =
        (_chromeHidden || pipPreview) &&
        _selectedIndex == 0 &&
        timer.phase == TimerPhase.running;
    final pageBackground = _pageBackground(
      context: context,
      selectedIndex: _selectedIndex,
      timerMode: timer.mode,
    );
    final settingsSubPageActive = _selectedIndex == 2 && _settingsSubPageOpen;
    final statsSubPageActive = _selectedIndex == 1 && _statsSubPageOpen;
    _syncSystemUi(context, pageBackground, immersive: hideChrome);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      onPointerSignal: (_) => _handleUserActivity(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        color: pageBackground,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(
                      child: pipPreview
                          ? _pageTransition(
                              controller: controller,
                              data: data,
                              quiet: hideChrome,
                              inPictureInPicture: true,
                              expandFromPictureInPicture: false,
                            )
                          : SafeArea(
                              top: true,
                              bottom: false,
                              child: _pageTransition(
                                controller: controller,
                                data: data,
                                quiet: hideChrome,
                                inPictureInPicture: false,
                                expandFromPictureInPicture:
                                    _returningFromPictureInPicture,
                              ),
                            ),
                    ),
                    if (!pipPreview &&
                        !settingsSubPageActive &&
                        !statsSubPageActive)
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

  Widget _pageTransition({
    required AppController controller,
    required TomatoData data,
    required bool quiet,
    required bool inPictureInPicture,
    required bool expandFromPictureInPicture,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 60),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey('$_selectedIndex-$inPictureInPicture'),
        child: _pageFor(
          controller: controller,
          data: data,
          quiet: quiet,
          inPictureInPicture: inPictureInPicture,
          expandFromPictureInPicture: expandFromPictureInPicture,
        ),
      ),
    );
  }

  Widget _pageFor({
    required AppController controller,
    required TomatoData data,
    required bool quiet,
    required bool inPictureInPicture,
    required bool expandFromPictureInPicture,
  }) {
    switch (_selectedIndex) {
      case 0:
        return _TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          inPictureInPicture: inPictureInPicture,
          expandFromPictureInPicture: expandFromPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onTogglePictureInPicture: _togglePictureInPicture,
          onUiHaptic: _emitUiHaptic,
        );
      case 1:
        return _StatsPage(
          data: data,
          onSubPageOpenChanged: _handleStatsSubPageChanged,
        );
      case 2:
        return _SettingsPage(
          controller: controller,
          settings: data.settings,
          onSubPageOpenChanged: _handleSettingsSubPageChanged,
        );
      default:
        return _TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          inPictureInPicture: inPictureInPicture,
          expandFromPictureInPicture: expandFromPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onTogglePictureInPicture: _togglePictureInPicture,
          onUiHaptic: _emitUiHaptic,
        );
    }
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      return;
    }
    _emitUiHaptic();
    setState(() {
      _selectedIndex = index;
      if (index != 2) {
        _settingsSubPageOpen = false;
      }
      if (index != 1) {
        _statsSubPageOpen = false;
      }
      _chromeHidden = false;
    });
    _syncIdleChrome();
  }

  void _handleStatsSubPageChanged(bool open) {
    if (!mounted || _statsSubPageOpen == open) {
      return;
    }
    setState(() {
      _statsSubPageOpen = open;
    });
  }

  void _handleSettingsSubPageChanged(bool open) {
    if (!mounted || _settingsSubPageOpen == open) {
      return;
    }
    setState(() {
      _settingsSubPageOpen = open;
    });
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

  void _prepareForPictureInPicture() {
    final controller = _controller;
    if (controller == null ||
        controller.data.timer.phase != TimerPhase.running ||
        !controller.data.settings.pictureInPictureEnabled ||
        !mounted) {
      return;
    }
    _idleChromeTimer?.cancel();
    _idleChromeTimer = null;
    _pipChromeRestoreTimer?.cancel();
    _pipReturnTimer?.cancel();
    if (_selectedIndex == 0 && _chromeHidden && _pipTransitioning) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _chromeHidden = true;
      _pipTransitioning = true;
      _returningFromPictureInPicture = false;
    });
  }

  void _togglePictureInPicture(bool enabled) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final settings = controller.data.settings;
    if (settings.pictureInPictureEnabled == enabled) {
      return;
    }
    unawaited(
      controller.updateSettings(
        settings.copyWith(pictureInPictureEnabled: enabled),
      ),
    );
    if (!enabled) {
      _pipTransitioning = false;
      _inPictureInPicture = false;
      unawaited(
        PlatformControls.setPipState(
          enabled: false,
          title: '',
          subtitle: '',
          keepScreenOn: settings.keepScreenOnEnabled,
          totalSeconds: 1,
          remainingSeconds: 1,
        ),
      );
    }
  }

  void _handleUserActivity() {
    if (_inPictureInPicture || _pipTransitioning) {
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
    final keepScreenOn = controller.data.settings.keepScreenOnEnabled;
    final pipSwitchEnabled = controller.data.settings.pictureInPictureEnabled;
    if (_lastKeepScreenOnSent != keepScreenOn) {
      _lastKeepScreenOnSent = keepScreenOn;
      unawaited(PlatformControls.setKeepScreenOn(keepScreenOn));
    }

    final pipEnabled = pipSwitchEnabled && timer.phase == TimerPhase.running;
    final pipTitle = formatClock(timer.remainingSeconds);
    final pipSubtitle = timer.mode.label;
    final linuxPersistentNotification = _usesLinuxPersistentNotification;
    final pipNeedsTitleRefresh =
        _inPictureInPicture ||
        _pipTransitioning ||
        (linuxPersistentNotification && pipEnabled);
    final shouldSendPipState =
        _lastPipEnabledSent != pipEnabled ||
        _lastPipSubtitleSent != pipSubtitle ||
        _lastPipKeepScreenOnSent != keepScreenOn ||
        _lastPipTitleSent == null ||
        (pipNeedsTitleRefresh && _lastPipTitleSent != pipTitle);
    if (shouldSendPipState) {
      _lastPipEnabledSent = pipEnabled;
      _lastPipTitleSent = pipTitle;
      _lastPipSubtitleSent = pipSubtitle;
      _lastPipKeepScreenOnSent = keepScreenOn;
      unawaited(
        PlatformControls.setPipState(
          enabled: pipEnabled,
          title: pipTitle,
          subtitle: pipSubtitle,
          keepScreenOn: keepScreenOn,
          totalSeconds: timer.totalSeconds,
          remainingSeconds: timer.remainingSeconds,
        ),
      );
    }

    final notificationEnabled =
        timer.phase == TimerPhase.running &&
        !pipSwitchEnabled &&
        !linuxPersistentNotification;
    final notificationTitle = formatClock(timer.remainingSeconds);
    final notificationSubtitle = timer.mode.label;
    final notificationTotalSeconds = timer.totalSeconds;
    final notificationRemainingSeconds = timer.remainingSeconds;
    final shouldSendNotification =
        _lastNotificationEnabledSent != notificationEnabled ||
        _lastNotificationTitleSent != notificationTitle ||
        _lastNotificationSubtitleSent != notificationSubtitle ||
        _lastNotificationTotalSecondsSent != notificationTotalSeconds ||
        _lastNotificationRemainingSecondsSent != notificationRemainingSeconds;
    if (!shouldSendNotification) {
      return;
    }
    _lastNotificationEnabledSent = notificationEnabled;
    _lastNotificationTitleSent = notificationTitle;
    _lastNotificationSubtitleSent = notificationSubtitle;
    _lastNotificationTotalSecondsSent = notificationTotalSeconds;
    _lastNotificationRemainingSecondsSent = notificationRemainingSeconds;
    unawaited(
      PlatformControls.setTimerNotification(
        enabled: notificationEnabled,
        title: notificationTitle,
        subtitle: notificationSubtitle,
        totalSeconds: notificationTotalSeconds,
        remainingSeconds: notificationRemainingSeconds,
      ),
    );
  }

  void _handlePictureInPictureChanged(bool enabled) {
    if (!mounted) {
      return;
    }
    if (_inPictureInPicture == enabled && !(!enabled && _pipTransitioning)) {
      return;
    }
    if (!enabled) {
      _beginPictureInPictureReturn();
      return;
    }
    setState(() {
      _inPictureInPicture = enabled;
      _pipTransitioning = false;
      _returningFromPictureInPicture = false;
      _selectedIndex = 0;
      _chromeHidden = true;
    });
    _syncIdleChrome(restart: true);
  }

  void _beginPictureInPictureReturn() {
    _pipChromeRestoreTimer?.cancel();
    _pipReturnTimer?.cancel();
    setState(() {
      _selectedIndex = 0;
      _inPictureInPicture = false;
      _pipTransitioning = false;
      _chromeHidden = true;
      _returningFromPictureInPicture = true;
    });
    _pipReturnTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _returningFromPictureInPicture = false;
      });
    });
    _restoreChromeAfterPictureInPicture();
    _syncIdleChrome(restart: true);
  }

  void _restoreChromeAfterPictureInPicture() {
    _pipChromeRestoreTimer?.cancel();
    _pipChromeRestoreTimer = Timer(const Duration(milliseconds: 310), () {
      if (!mounted || _selectedIndex != 0 || _controller == null) {
        return;
      }
      if (_controller!.data.timer.phase == TimerPhase.running) {
        setState(() {
          _chromeHidden = false;
        });
      }
      _syncIdleChrome(restart: true);
    });
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

  Future<void> _emitUiHaptic() async {
    final controller = _controller;
    if (controller == null ||
        !controller.data.settings.completionHapticsEnabled) {
      return;
    }
    await PlatformControls.vibrate(durationMs: 30, amplitude: 150);
  }
}

class _TimerPage extends StatelessWidget {
  const _TimerPage({
    required this.controller,
    required this.data,
    required this.quiet,
    required this.inPictureInPicture,
    required this.expandFromPictureInPicture,
    required this.onRequestQuiet,
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
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
        final actionsBottom = _actionsBottom(context);
        final bottomReserve = actionsBottom + 72;
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
                child: _ChromeFade(
                  hidden: false,
                  slideOffset: const Offset(0, -0.08),
                  child: _HitokotoLine(mode: timer.mode),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: actionsBottom,
                child: _ChromeFade(
                  hidden: quiet,
                  slideOffset: const Offset(0, 0.14),
                  child: _TimerActions(
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
      },
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
      left: _dockHorizontalMargin,
      right: _dockHorizontalMargin,
      bottom: _dockBottom(context),
      child: _ChromeFade(
        hidden: hidden,
        slideOffset: const Offset(0, 0.18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              elevation: 10,
              shadowColor: Colors.black.withAlpha(36),
              color: Theme.of(context).colorScheme.surface.withAlpha(238),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: _dockHeight,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      _DockItem(
                        icon: Icons.timer_outlined,
                        selectedIcon: Icons.timer,
                        label: '番茄钟',
                        selected: selectedIndex == 0,
                        onTap: () => onSelected(0),
                      ),
                      _DockItem(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart,
                        label: '统计',
                        selected: selectedIndex == 1,
                        onTap: () => onSelected(1),
                      ),
                      _DockItem(
                        icon: Icons.settings_outlined,
                        selectedIcon: Icons.settings,
                        label: '设置',
                        selected: selectedIndex == 2,
                        onTap: () => onSelected(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) {
      return;
    }
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.persistentCallbacks ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pressed == value) {
          return;
        }
        setState(() => _pressed = value);
      });
      return;
    }
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.selected) return;
    _setPressed(true);
  }

  void _handleTapUp(TapUpDetails details) {
    _setPressed(false);
  }

  void _handleTapCancel() {
    _setPressed(false);
  }

  void _handleTap() {
    if (widget.selected) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final backgroundAlpha = selected ? 32 : (_pressed ? 18 : 0);
    final borderAlpha = selected ? 70 : (_pressed ? 28 : 0);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: selected ? null : _handleTapDown,
            onTapUp: selected ? null : _handleTapUp,
            onTapCancel: selected ? null : _handleTapCancel,
            onTap: selected ? null : _handleTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(backgroundAlpha),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withAlpha(borderAlpha),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? widget.selectedIcon : widget.icon,
                    size: 20,
                    color: foreground,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
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

class _StatsPage extends StatefulWidget {
  const _StatsPage({required this.data, required this.onSubPageOpenChanged});

  final TomatoData data;
  final ValueChanged<bool> onSubPageOpenChanged;

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  FocusSession? _selectedSession;

  void _openSession(FocusSession session) {
    setState(() => _selectedSession = session);
    widget.onSubPageOpenChanged(true);
  }

  void _closeSession() {
    setState(() => _selectedSession = null);
    widget.onSubPageOpenChanged(false);
  }

  @override
  void dispose() {
    widget.onSubPageOpenChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.data.sessions
        .where((session) => session.isRecordable)
        .take(8)
        .toList();

    return PopScope<void>(
      canPop: _selectedSession == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedSession != null) {
          _closeSession();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 60),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _selectedSession != null
            ? KeyedSubtree(
                key: const ValueKey('session-detail'),
                child: _SessionDetail(
                  session: _selectedSession!,
                  onBack: _closeSession,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('stats-main'),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
                      children: [
                        _TodayStats(data: widget.data),
                        const SizedBox(height: 16),
                        FocusHeatmap(
                          focusSecondsByDay: widget.data.focusSecondsByDay(),
                        ),
                        const SizedBox(height: 16),
                        _RecentSessions(
                          sessions: sessions,
                          onTap: _openSession,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session, required this.onBack});

  final FocusSession session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              Text('专注详情', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_outlined,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  formatDateTime(session.endedAt),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Icon(
                                session.completed
                                    ? Icons.check_circle_outline
                                    : Icons.stop_circle_outlined,
                                color: session.completed
                                    ? const Color(0xFF2F7D57)
                                    : scheme.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.timer_outlined,
                            label: '专注时长',
                            value: formatHours(session.focusedSeconds),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.schedule,
                            label: '计划时长',
                            value: formatHours(session.plannedSeconds),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.play_arrow_outlined,
                            label: '开始时间',
                            value: formatDateTime(session.startedAt),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.stop_outlined,
                            label: '结束时间',
                            value: formatDateTime(session.endedAt),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.check_outlined,
                            label: '状态',
                            value: session.completed ? '完成' : '已停止',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.controller,
    required this.settings,
    required this.onSubPageOpenChanged,
  });

  final AppController controller;
  final AppSettings settings;
  final ValueChanged<bool> onSubPageOpenChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  int _subPage = 0;
  int _syncSubPage = 0; // 0 = sync main, 1 = webdav

  static const _pages = ['', '计时设置', '切换提醒', '外观', '同步'];

  @override
  void dispose() {
    widget.onSubPageOpenChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _subPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBack();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 60),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey('settings-$_subPage-$_syncSubPage'),
          child: _subPage == 0 ? _buildMain() : _buildSubPage(),
        ),
      ),
    );
  }

  void _goBack() {
    if (_subPage == 4 && _syncSubPage == 1) {
      setState(() => _syncSubPage = 0);
      return;
    }
    if (_subPage != 0) {
      _setPageState(() {
        _subPage = 0;
        _syncSubPage = 0;
      });
    }
  }

  void _openSubPage(int page) {
    _setPageState(() {
      _subPage = page;
      _syncSubPage = 0;
    });
  }

  void _openWebDavSubPage() {
    _setPageState(() {
      _subPage = 4;
      _syncSubPage = 1;
    });
  }

  void _setPageState(VoidCallback update) {
    final wasOpen = _subPage != 0;
    setState(update);
    final isOpen = _subPage != 0;
    if (wasOpen != isOpen) {
      widget.onSubPageOpenChanged(isOpen);
    }
  }

  Widget _buildMain() {
    final controller = AppScope.read(context);
    final settings = controller.data.settings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
          children: [
            _SettingsSection(
              icon: Icons.dashboard_customize_outlined,
              title: '基础设置',
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('计时设置'),
                  subtitle: const Text('时长、循环和静默显示'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(1),
                ),
                ListTile(
                  leading: Icon(_themeModeIcon(settings.themeMode)),
                  title: const Text('外观'),
                  subtitle: Text(settings.themeMode.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(3),
                ),
                ListTile(
                  leading: const Icon(Icons.vibration),
                  title: const Text('切换提醒'),
                  subtitle: const Text('震动和音效'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              icon: Icons.sync_alt,
              title: '数据同步',
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('同步'),
                  subtitle: const Text('本地同步与 WebDAV 云端同步'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPage() {
    final title = _syncSubPage == 1 ? 'WebDAV 同步' : _pages[_subPage];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 22),
                  tooltip: '返回',
                  onPressed: _goBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildSubPageContent()),
        ],
      ),
    );
  }

  Widget _buildSubPageContent() {
    switch (_subPage) {
      case 1:
        return _TimerSettingsContent();
      case 2:
        return _FeedbackSettingsContent();
      case 3:
        return _AppearanceSettingsContent();
      case 4:
        return _syncSubPage == 1
            ? _WebDavSettingsContent()
            : _BackupContent(onOpenWebDav: _openWebDavSubPage);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SettingsSubPageScaffold extends StatelessWidget {
  const _SettingsSubPageScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 32 + bottom),
          itemBuilder: (context, index) => children[index],
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemCount: children.length,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  Icon(icon, color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 1, indent: 58),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: children[index],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupContent extends StatelessWidget {
  const _BackupContent({required this.onOpenWebDav});

  final VoidCallback onOpenWebDav;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;
    final scheme = Theme.of(context).colorScheme;
    final lastSyncAt = controller.lastSyncAt;
    final status = controller.syncing
        ? '正在同步'
        : controller.lastSyncError ?? _lastSyncLabel(lastSyncAt);

    return _SettingsSubPageScaffold(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '云端同步',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (controller.syncing)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: controller.lastSyncError == null
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          settings.webDav.isConfigured && !controller.syncing
                          ? controller.syncNow
                          : null,
                      icon: const Icon(Icons.sync),
                      label: const Text('立即同步'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          settings.webDav.isConfigured && !controller.syncing
                          ? () => _confirmCloudRestore(context, controller)
                          : null,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('从云端恢复'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.syncing ? null : onOpenWebDav,
                      icon: const Icon(Icons.settings_backup_restore),
                      label: const Text('WebDAV 设置'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('自动同步'),
                  subtitle: Text(
                    settings.webDav.isConfigured
                        ? '每 ${settings.backupAutoSyncIntervalMinutes} 分钟自动同步'
                        : '配置 WebDAV 后启用',
                  ),
                  value: settings.backupAutoSyncEnabled,
                  onChanged: (value) {
                    controller.updateSettings(
                      settings.copyWith(backupAutoSyncEnabled: value),
                    );
                  },
                ),
                if (settings.backupAutoSyncEnabled)
                  NumberStepper(
                    icon: Icons.schedule,
                    label: '同步间隔',
                    value: settings.backupAutoSyncIntervalMinutes,
                    min: 5,
                    max: 1440,
                    suffix: '分钟',
                    onChanged: (value) {
                      controller.updateSettings(
                        settings.copyWith(backupAutoSyncIntervalMinutes: value),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        _LocalBackupCard(controller: controller, settings: settings),
      ],
    );
  }

  Future<void> _confirmCloudRestore(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('从云端恢复'),
          content: const Text('将用云端同步数据覆盖当前本地数据，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续恢复'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.restoreFromWebDav();
    }
  }
}

class _LocalBackupCard extends StatefulWidget {
  const _LocalBackupCard({required this.controller, required this.settings});

  final AppController controller;
  final AppSettings settings;

  @override
  State<_LocalBackupCard> createState() => _LocalBackupCardState();
}

class _LocalBackupCardState extends State<_LocalBackupCard> {
  late final TextEditingController _directoryController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _directoryController = TextEditingController(
      text: widget.settings.localBackupDirectory,
    );
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _LocalBackupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.settings.localBackupDirectory;
    if (!_focusNode.hasFocus && _directoryController.text != next) {
      _directoryController.text = next;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _directoryController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      unawaited(_saveDirectory());
    }
  }

  Future<void> _saveDirectory() async {
    final directory = _directoryController.text.trim();
    if (directory == widget.controller.data.settings.localBackupDirectory) {
      return;
    }
    await widget.controller.updateSettings(
      widget.controller.data.settings.copyWith(localBackupDirectory: directory),
    );
  }

  Future<void> _createBackup() async {
    final directory = _directoryController.text.trim();
    await widget.controller.updateSettings(
      widget.controller.data.settings.copyWith(localBackupDirectory: directory),
    );
    await widget.controller.createLocalBackup(directory: directory);
  }

  Future<void> _pickDirectory() async {
    final path = await PlatformControls.pickDirectory();
    if (path != null && mounted) {
      _directoryController.text = path;
      await _saveDirectory();
    }
  }

  Future<void> _restoreFromLocalBackup() async {
    final fileUri = await PlatformControls.pickBackupFile();
    if (fileUri == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('从本地恢复'),
          content: const Text('将用所选同步文件覆盖当前数据，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续恢复'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final raw = await PlatformControls.readTextFile(fileUri: fileUri);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('读取同步文件失败')));
      return;
    }
    await widget.controller.restoreFromLocalJson(raw);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final localStatus = widget.controller.localBackupStatusLabel();
    final localStatusColor = widget.controller.lastLocalBackupError == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '本地同步',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              localStatus,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: localStatusColor),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _createBackup,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('立即创建'),
                ),
                OutlinedButton.icon(
                  onPressed: _restoreFromLocalBackup,
                  icon: const Icon(Icons.restore_page_outlined),
                  label: const Text('从文件恢复'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择目录'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _directoryController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: '同步目录',
                hintText: '留空使用应用数据目录',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_saveDirectory()),
            ),
            const SizedBox(height: 6),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.autorenew),
              title: const Text('定时本地同步'),
              subtitle: settings.localBackupAutoEnabled
                  ? Text('每 ${settings.localBackupAutoIntervalMinutes} 分钟同步一次')
                  : const Text('关闭后仅手动同步'),
              value: settings.localBackupAutoEnabled,
              onChanged: (value) {
                widget.controller.updateSettings(
                  settings.copyWith(localBackupAutoEnabled: value),
                );
              },
            ),
            if (settings.localBackupAutoEnabled) ...[
              NumberStepper(
                icon: Icons.schedule,
                label: '同步间隔',
                value: settings.localBackupAutoIntervalMinutes,
                min: 5,
                max: 1440,
                suffix: '分钟',
                onChanged: (value) {
                  widget.controller.updateSettings(
                    settings.copyWith(localBackupAutoIntervalMinutes: value),
                  );
                },
              ),
              NumberStepper(
                icon: Icons.layers_outlined,
                label: '保留份数',
                value: settings.localBackupKeepCount,
                min: 1,
                max: 50,
                suffix: '份',
                onChanged: (value) {
                  widget.controller.updateSettings(
                    settings.copyWith(localBackupKeepCount: value),
                  );
                },
              ),
            ],
          ],
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
    final palette = _modePalette(widget.mode);

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

class TimerProgressRing extends StatefulWidget {
  const TimerProgressRing({
    required this.snapshot,
    required this.maxDimension,
    this.compact = false,
    this.surfaceKey,
    super.key,
  });

  final TimerSnapshot snapshot;
  final double maxDimension;
  final bool compact;
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
    final palette = _modePalette(widget.snapshot.mode);

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
        final compactTextColor = _contrastOn(palette.backgroundFor(context));

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
                              if (!widget.compact) ...[
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
                              if (!widget.compact) ...[
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
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.55
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
        oldDelegate.haloOpacity != haloOpacity ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class PipTimerBox extends StatelessWidget {
  const PipTimerBox({required this.snapshot, super.key});

  final TimerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = _modePalette(snapshot.mode);
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

class _TimerActions extends StatelessWidget {
  const _TimerActions({
    required this.controller,
    required this.mode,
    required this.phase,
    required this.keepScreenOn,
    required this.pictureInPictureEnabled,
    required this.hapticsEnabled,
    required this.onToggleKeepScreenOn,
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool keepScreenOn;
  final bool pictureInPictureEnabled;
  final bool hapticsEnabled;
  final VoidCallback onToggleKeepScreenOn;
  final ValueChanged<bool> onTogglePictureInPicture;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final canStop = phase != TimerPhase.idle;
    final canSkip = running && mode != TimerMode.focus;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final tight = constraints.maxWidth < 330;
        final iconSize = compact ? 38.0 : 42.0;
        final buttonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: 0,
        );
        final buttonStyle = ButtonStyle(
          visualDensity: VisualDensity.compact,
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(buttonPadding),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              elevation: 10,
              shadowColor: Colors.black.withAlpha(34),
              color: scheme.surface.withAlpha(236),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      style: buttonStyle,
                      onPressed: running
                          ? controller.pause
                          : () {
                              if (hapticsEnabled) {
                                unawaited(onUiHaptic());
                              }
                              controller.start();
                            },
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          running ? Icons.pause : Icons.play_arrow,
                          key: ValueKey(running),
                          size: 20,
                        ),
                      ),
                      label: Text(running ? '暂停' : '开始'),
                    ),
                    const SizedBox(width: 7),
                    if (tight)
                      _ActionIconButton(
                        size: iconSize,
                        tooltip: '停止',
                        onPressed: canStop
                            ? () {
                                if (hapticsEnabled) {
                                  unawaited(onUiHaptic());
                                }
                                controller.stop();
                              }
                            : null,
                        icon: Icons.stop_circle_outlined,
                      )
                    else
                      OutlinedButton.icon(
                        style: buttonStyle,
                        onPressed: canStop
                            ? () {
                                if (hapticsEnabled) {
                                  unawaited(onUiHaptic());
                                }
                                controller.stop();
                              }
                            : null,
                        icon: const Icon(Icons.stop_circle_outlined, size: 20),
                        label: const Text('停止'),
                      ),
                    const SizedBox(width: 7),
                    _ActionIconButton(
                      size: iconSize,
                      tooltip: keepScreenOn ? '关闭屏幕常亮' : '开启屏幕常亮',
                      selected: keepScreenOn,
                      onPressed: onToggleKeepScreenOn,
                      icon: keepScreenOn
                          ? Icons.lightbulb
                          : Icons.lightbulb_outline,
                    ),
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      size: iconSize,
                      tooltip: _usesLinuxPersistentNotification
                          ? pictureInPictureEnabled
                                ? '关闭 KDE 托盘常驻'
                                : '开启 KDE 托盘常驻'
                          : pictureInPictureEnabled
                          ? '关闭画中画自动进入'
                          : '开启画中画自动进入',
                      selected: pictureInPictureEnabled,
                      onPressed: phase == TimerPhase.running
                          ? () => onTogglePictureInPicture(
                              !pictureInPictureEnabled,
                            )
                          : null,
                      icon: _usesLinuxPersistentNotification
                          ? pictureInPictureEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_none
                          : pictureInPictureEnabled
                          ? Icons.picture_in_picture_alt
                          : Icons.picture_in_picture_alt_outlined,
                    ),
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      size: iconSize,
                      tooltip: '跳过休息',
                      onPressed: canSkip ? controller.skip : null,
                      icon: Icons.skip_next,
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

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.size,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
  });

  final double size;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      style:
          IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            backgroundColor: scheme.surfaceContainerHighest,
            disabledBackgroundColor: scheme.surfaceContainerHighest.withAlpha(
              128,
            ),
            disabledForegroundColor: scheme.onSurfaceVariant.withAlpha(130),
            overlayColor: scheme.primary.withAlpha(20),
            highlightColor: Colors.transparent,
            splashFactory: InkRipple.splashFactory,
            fixedSize: Size.square(size),
            minimumSize: Size.square(size),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return scheme.surfaceContainerHighest.withAlpha(128);
              }
              if (states.contains(WidgetState.selected)) {
                return scheme.primary.withAlpha(22);
              }
              return scheme.surfaceContainerHighest;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return scheme.onSurfaceVariant.withAlpha(130);
              }
              if (states.contains(WidgetState.selected)) {
                return scheme.primary;
              }
              return scheme.onSurfaceVariant;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return BorderSide(color: scheme.primary.withAlpha(56));
              }
              return BorderSide(color: scheme.outlineVariant.withAlpha(120));
            }),
          ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.data});

  final TomatoData data;

  @override
  Widget build(BuildContext context) {
    final today = dateKey(DateTime.now());
    final byDay = data.focusSecondsByDay();
    final todaySeconds = byDay[today] ?? 0;
    final totalSeconds = data.totalFocusSeconds;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: '今日专注',
            value: formatHours(todaySeconds),
            detail: '累计时长',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.all_inclusive,
            label: '总专注',
            value: formatHours(totalSeconds),
            detail: '历史累计',
          ),
        ),
      ],
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: Text(
                      value,
                      key: ValueKey(value),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
  const _RecentSessions({required this.sessions, this.onTap});

  final List<FocusSession> sessions;
  final ValueChanged<FocusSession>? onTap;

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
              onTap: onTap != null ? () => onTap!(session) : null,
            ),
      ],
    );
  }
}

class _TimerSettingsContent extends StatelessWidget {
  const _TimerSettingsContent();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.read(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        _SettingsSection(
          icon: Icons.tune,
          title: '阶段时长',
          children: [
            NumberStepper(
              icon: Icons.psychology_alt_outlined,
              label: '专注时长',
              value: settings.focusMinutes,
              min: 1,
              max: 240,
              suffix: '分钟',
              onChanged: (value) {
                controller.updateSettings(
                  settings.copyWith(focusMinutes: value),
                );
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
          ],
        ),
        _SettingsSection(
          icon: Icons.repeat,
          title: '循环与显示',
          children: [
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
              icon: Icons.autorenew,
              label: '本轮循环次数',
              value: settings.focusCyclesPerRun,
              min: 1,
              max: 48,
              suffix: '次',
              onChanged: (value) {
                controller.updateSettings(
                  settings.copyWith(focusCyclesPerRun: value),
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
          ],
        ),
      ],
    );
  }
}

class _FeedbackSettingsContent extends StatelessWidget {
  const _FeedbackSettingsContent();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.read(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                secondary: const Icon(Icons.vibration),
                title: const Text('切换震动'),
                subtitle: const Text('统一控制 Dock 操作触感与阶段切换振动提醒'),
                value: settings.completionHapticsEnabled,
                onChanged: (value) {
                  controller.updateSettings(
                    settings.copyWith(completionHapticsEnabled: value),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
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
        ),
      ],
    );
  }
}

class _AppearanceSettingsContent extends StatelessWidget {
  const _AppearanceSettingsContent();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.read(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '主题',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WebDavSettingsContent extends StatefulWidget {
  const _WebDavSettingsContent();

  @override
  State<_WebDavSettingsContent> createState() => _WebDavSettingsContentState();
}

class _WebDavSettingsContentState extends State<_WebDavSettingsContent> {
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
    final controller = AppScope.read(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        _SettingsSection(
          icon: Icons.cloud_outlined,
          title: '连接信息',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: TextField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.link),
                  labelText: '服务地址',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.key_outlined),
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
              child: TextField(
                controller: _remotePathController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_outlined),
                  labelText: '远端路径',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _saveWebDav,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存同步设置'),
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
          ),
        ),
      ],
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

class NumberStepper extends StatefulWidget {
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
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _feedbackTimer;
  bool _savedVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commitInput(showFeedback: true);
    }
  }

  void _commitInput({bool showFeedback = false, bool unfocus = false}) {
    final parsed = int.tryParse(_controller.text);
    if (parsed == null) {
      _controller.text = widget.value.toString();
      if (showFeedback) {
        _showInputMessage('请输入 ${widget.min}-${widget.max} 的数字');
      }
      if (unfocus) {
        _focusNode.unfocus();
      }
      return;
    }
    final next = parsed.clamp(widget.min, widget.max).toInt();
    _controller.text = next.toString();
    if (next != widget.value) {
      widget.onChanged(next);
    }
    if (showFeedback) {
      _showSavedFeedback();
      if (parsed != next) {
        _showInputMessage('已调整到 $next ${widget.suffix}');
      }
    }
    if (unfocus) {
      _focusNode.unfocus();
    }
  }

  void _showSavedFeedback() {
    final settings = AppScope.read(context).data.settings;
    if (settings.completionHapticsEnabled) {
      unawaited(PlatformControls.vibrate(durationMs: 24, amplitude: 140));
    }
    _feedbackTimer?.cancel();
    if (mounted) setState(() => _savedVisible = true);
    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _savedVisible = false);
    });
  }

  void _showInputMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(widget.icon),
      title: Text(widget.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 62,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 9,
                ),
                border: const OutlineInputBorder(),
                hintText: '${widget.min}–${widget.max}',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withAlpha(120),
                ),
              ),
              onTap: () => _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              ),
              onSubmitted: (_) =>
                  _commitInput(showFeedback: true, unfocus: true),
            ),
          ),
          const SizedBox(width: 6),
          Text(widget.suffix, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 4),
          AnimatedOpacity(
            opacity: _savedVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 160),
            child: Icon(Icons.check_circle, size: 16, color: scheme.primary),
          ),
        ],
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

String _lastSyncLabel(DateTime? value) {
  if (value == null) {
    return '尚未同步';
  }
  return '上次同步 ${formatDateTime(value)}';
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
        accent: Color(0xFFB15E52),
        lightBackground: Color(0xFFEFEAEC),
        darkBackground: Color(0xFF171416),
      );
    case TimerMode.shortBreak:
      return const _StagePalette(
        accent: Color(0xFF3D8A5D),
        lightBackground: Color(0xFFE9EFEB),
        darkBackground: Color(0xFF141916),
      );
    case TimerMode.longBreak:
      return const _StagePalette(
        accent: Color(0xFF3D79A8),
        lightBackground: Color(0xFFE8ECF2),
        darkBackground: Color(0xFF14191E),
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
