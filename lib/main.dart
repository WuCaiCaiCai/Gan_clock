import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'models.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'pages/timer_page.dart';
import 'platform_controls.dart';
import 'utils.dart';
import 'widgets/focus_edge_nav.dart';

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
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
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

const localBackupSuccessMessageToken = 'LOCAL_BACKUP_SUCCESS';
const localRestoreSuccessMessageToken = 'LOCAL_RESTORE_SUCCESS';
const cloudRestoreSuccessMessageToken = 'CLOUD_RESTORE_SUCCESS';

ThemeData _buildAppTheme(Brightness brightness) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: shelfSeedColor,
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
    splashFactory: InkRipple.splashFactory,
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
    return modePalette(timerMode).backgroundFor(context);
  }
  return Theme.of(context).scaffoldBackgroundColor;
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
  Timer? _oledIdleTimer;
  Timer? _pipChromeRestoreTimer;
  Timer? _pipReturnTimer;
  int _selectedIndex = 0;
  bool _settingsSubPageOpen = false;
  bool _statsSubPageOpen = false;
  bool _navigationOpen = false;
  bool _chromeHidden = false;
  bool _oledMode = false;
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
    _oledIdleTimer?.cancel();
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
    if (message == localBackupSuccessMessageToken) {
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
    if (message == localRestoreSuccessMessageToken) {
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
    if (message == cloudRestoreSuccessMessageToken) {
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
        !_navigationOpen &&
        (_chromeHidden || _oledMode || pipPreview) &&
        _selectedIndex == 0 &&
        !controller.loading;
    final normalPageBackground = _pageBackground(
      context: context,
      selectedIndex: _selectedIndex,
      timerMode: timer.mode,
    );
    final pageBackground = _oledMode && _selectedIndex == 0
        ? Colors.black
        : normalPageBackground;
    _syncSystemUi(
      context,
      pageBackground,
      immersive: hideChrome || _selectedIndex == 0,
    );

    return PopScope<void>(
      canPop:
          !_navigationOpen &&
          (_selectedIndex == 0 || _settingsSubPageOpen || _statsSubPageOpen),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_navigationOpen) {
          _closeNavigation();
          return;
        }
        if (_settingsSubPageOpen || _statsSubPageOpen) {
          return;
        }
        if (_selectedIndex != 0) {
          _selectPage(0);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _handleUserActivity(),
        onPointerMove: (_) => _handleUserActivity(),
        onPointerSignal: (_) => _handleUserActivity(),
        child: AnimatedContainer(
          key: const ValueKey('app_background'),
          duration: const Duration(milliseconds: 360),
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
                                oledMode: false,
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
                                  oledMode: _oledMode,
                                  inPictureInPicture: false,
                                  expandFromPictureInPicture:
                                      _returningFromPictureInPicture,
                                ),
                              ),
                      ),
                      if (!pipPreview)
                        FocusEdgeNav(
                          open: _navigationOpen,
                          visualHidden: hideChrome,
                          selectedIndex: _selectedIndex,
                          settings: data.settings,
                          timer: timer,
                          onOpen: _openNavigation,
                          onClose: _closeNavigation,
                          onSelected: _selectPage,
                          onToggleKeepScreenOn: _toggleKeepScreenOn,
                          onTogglePictureInPicture: _togglePictureInPicture,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pageTransition({
    required AppController controller,
    required TomatoData data,
    required bool quiet,
    required bool oledMode,
    required bool inPictureInPicture,
    required bool expandFromPictureInPicture,
  }) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey('$_selectedIndex-$inPictureInPicture'),
        child: _pageFor(
          controller: controller,
          data: data,
          quiet: quiet,
          oledMode: oledMode,
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
    required bool oledMode,
    required bool inPictureInPicture,
    required bool expandFromPictureInPicture,
  }) {
    switch (_selectedIndex) {
      case 0:
        return TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          oledMode: oledMode,
          inPictureInPicture: inPictureInPicture,
          expandFromPictureInPicture: expandFromPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onOpenStats: () => _selectPage(1),
          onOpenSettings: () => _selectPage(2),
          onToggleKeepScreenOn: _toggleKeepScreenOn,
          onTogglePictureInPicture: _togglePictureInPicture,
          onUiHaptic: _emitUiHaptic,
        );
      case 1:
        return StatsPage(
          data: data,
          onSubPageOpenChanged: _handleStatsSubPageChanged,
        );
      case 2:
        return SettingsPage(
          controller: controller,
          settings: data.settings,
          onSubPageOpenChanged: _handleSettingsSubPageChanged,
        );
      default:
        return TimerPage(
          controller: controller,
          data: data,
          quiet: quiet,
          oledMode: oledMode,
          inPictureInPicture: inPictureInPicture,
          expandFromPictureInPicture: expandFromPictureInPicture,
          onRequestQuiet: _requestQuiet,
          onOpenStats: () => _selectPage(1),
          onOpenSettings: () => _selectPage(2),
          onToggleKeepScreenOn: _toggleKeepScreenOn,
          onTogglePictureInPicture: _togglePictureInPicture,
          onUiHaptic: _emitUiHaptic,
        );
    }
  }

  void _selectPage(int index) {
    if (_selectedIndex == index && !_navigationOpen) {
      return;
    }
    _emitUiHaptic();
    setState(() {
      _selectedIndex = index;
      _navigationOpen = false;
      _oledMode = false;
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

  void _openNavigation() {
    if (_navigationOpen) {
      return;
    }
    _emitUiHaptic();
    setState(() {
      _navigationOpen = true;
      _chromeHidden = false;
      _oledMode = false;
    });
    _syncIdleChrome(restart: true);
  }

  void _closeNavigation() {
    if (!_navigationOpen) {
      return;
    }
    setState(() {
      _navigationOpen = false;
    });
    _syncIdleChrome(restart: true);
  }

  void _toggleKeepScreenOn() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final settings = controller.data.settings;
    unawaited(
      controller.updateSettings(
        settings.copyWith(keepScreenOnEnabled: !settings.keepScreenOnEnabled),
      ),
    );
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
        _navigationOpen ||
        _selectedIndex != 0 ||
        _chromeHidden) {
      return;
    }
    _idleChromeTimer?.cancel();
    _idleChromeTimer = null;
    _oledIdleTimer?.cancel();
    _oledIdleTimer = null;
    setState(() {
      _chromeHidden = true;
      _oledMode = false;
    });
    _scheduleOledMode();
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
    _oledIdleTimer?.cancel();
    _oledIdleTimer = null;
    _pipChromeRestoreTimer?.cancel();
    _pipReturnTimer?.cancel();
    if (_selectedIndex == 0 && _chromeHidden && _pipTransitioning) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _chromeHidden = true;
      _oledMode = false;
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
    if (_navigationOpen) {
      return;
    }
    if (_chromeHidden || _oledMode) {
      setState(() {
        _chromeHidden = false;
        _oledMode = false;
      });
      _ignoreNextQuietTap = true;
    }
    _oledIdleTimer?.cancel();
    _oledIdleTimer = null;
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
      _oledIdleTimer?.cancel();
      _oledIdleTimer = null;
      return;
    }
    if (_navigationOpen) {
      _idleChromeTimer?.cancel();
      _idleChromeTimer = null;
      _oledIdleTimer?.cancel();
      _oledIdleTimer = null;
      return;
    }
    final settings = controller.data.settings;
    final eligible = _selectedIndex == 0 && !controller.loading;

    if (!eligible) {
      _idleChromeTimer?.cancel();
      _idleChromeTimer = null;
      _oledIdleTimer?.cancel();
      _oledIdleTimer = null;
      if (_chromeHidden || _oledMode) {
        setState(() {
          _chromeHidden = false;
          _oledMode = false;
        });
      }
      return;
    }

    if (_chromeHidden) {
      _scheduleOledMode();
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
      if (_selectedIndex == 0 && latest != null) {
        setState(() {
          _chromeHidden = true;
          _oledMode = false;
        });
        _idleChromeTimer = null;
        _scheduleOledMode();
      }
    });
  }

  void _scheduleOledMode() {
    if (_oledIdleTimer != null || _oledMode || _selectedIndex != 0) {
      return;
    }
    _oledIdleTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || _selectedIndex != 0 || !_chromeHidden) {
        return;
      }
      setState(() {
        _oledMode = true;
      });
      _oledIdleTimer = null;
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
    final linuxPersistentNotification = usesPersistentTray;
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
