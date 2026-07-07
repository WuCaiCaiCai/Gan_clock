import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models.dart';
import '../platform_controls.dart';
import '../weather_service.dart';
import '../widgets/duration_picker.dart';
import '../widgets/int_wheel_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.controller,
    required this.settings,
    required this.onSubPageOpenChanged,
    super.key,
  });

  final AppController controller;
  final AppSettings settings;
  final ValueChanged<bool> onSubPageOpenChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _subPage = 0;

  static const _pages = ['', '计时与待机', '备份', '天气'];

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
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey('settings-$_subPage'),
          child: _subPage == 0 ? _buildMain() : _buildSubPage(),
        ),
      ),
    );
  }

  void _goBack() {
    if (_subPage != 0) {
      _setPageState(() {
        _subPage = 0;
      });
    }
  }

  void _openSubPage(int page) {
    _setPageState(() {
      _subPage = page;
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
    final phaseSummary =
        '${settings.focusMinutes}/${settings.shortBreakMinutes}/${settings.longBreakMinutes} 分钟';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
          children: [
            _SettingsSection(
              icon: Icons.spa_outlined,
              title: '专注体验',
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('计时与待机'),
                  subtitle: Text(
                    '$phaseSummary · ${settings.focusCyclesPerRun} 次循环 · 待机 ${settings.idleFocusSeconds} 秒',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(1),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                  secondary: const Icon(Icons.vibration),
                  title: const Text('切换震动'),
                  value: settings.completionHapticsEnabled,
                  onChanged: (value) {
                    controller.updateSettings(
                      settings.copyWith(completionHapticsEnabled: value),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 20,
                        color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('主题', style: Theme.of(context).textTheme.bodyLarge),
                      const Spacer(),
                      SegmentedButton<AppThemeMode>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: AppThemeMode.values
                            .map((mode) => ButtonSegment<AppThemeMode>(
                                  value: mode,
                                  label: Text(mode.label, style: const TextStyle(fontSize: 12)),
                                ))
                            .toList(),
                        selected: {settings.themeMode},
                        onSelectionChanged: (values) {
                          controller.updateSettings(
                            settings.copyWith(themeMode: values.single),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              icon: Icons.folder_copy_outlined,
              title: '数据',
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('备份'),
                  subtitle: const Text('本地备份与恢复'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              icon: Icons.cloud_outlined,
              title: '天气',
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('天气显示'),
                  subtitle: Text(settings.weatherEnabled ? '已开启' : '已关闭'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSubPage(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPage() {
    final title = _pages[_subPage];
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
        return const _TimerSettingsContent();
      case 2:
        return const _BackupContent();
      case 3:
        return const _WeatherSettingsContent();
      default:
        return const SizedBox.shrink();
    }
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

class _SettingsNote extends StatelessWidget {
  const _SettingsNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupContent extends StatelessWidget {
  const _BackupContent();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        _LocalBackupCard(controller: controller, settings: settings),
      ],
    );
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
          content: const Text('将用所选备份文件覆盖当前数据，是否继续？'),
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
        ..showSnackBar(const SnackBar(content: Text('读取备份文件失败')));
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
                    '本地备份',
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
              title: const Text('定时本地备份'),
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

class _TimerSettingsContent extends StatelessWidget {
  const _TimerSettingsContent();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.read(context);
    final settings = controller.data.settings;

    return _SettingsSubPageScaffold(
      children: [
        DurationPicker(
          icon: Icons.psychology_alt_outlined,
          label: '专注时长',
          valueMinutes: settings.focusMinutes,
          minMinutes: 5,
          maxMinutes: 240,
          onChanged: (value) {
            controller.updateSettings(
              settings.copyWith(focusMinutes: value),
            );
          },
        ),
        DurationPicker(
          icon: Icons.coffee_outlined,
          label: '短休息',
          valueMinutes: settings.shortBreakMinutes,
          minMinutes: 5,
          maxMinutes: 120,
          onChanged: (value) {
            controller.updateSettings(
              settings.copyWith(shortBreakMinutes: value),
            );
          },
        ),
        DurationPicker(
          icon: Icons.weekend_outlined,
          label: '长休息',
          valueMinutes: settings.longBreakMinutes,
          minMinutes: 5,
          maxMinutes: 240,
          onChanged: (value) {
            controller.updateSettings(
              settings.copyWith(longBreakMinutes: value),
            );
          },
        ),
        IntWheelPicker(
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
        IntWheelPicker(
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
        const _SettingsNote(
          icon: Icons.dark_mode_outlined,
          text: '计时页长时间无操作后先进入纯净模式；再经过同样的延时，背景转为 OLED 黑底防烧显示。',
        ),
        IntWheelPicker(
          icon: Icons.visibility_off_outlined,
          label: '待机延时',
          value: settings.idleFocusSeconds,
          min: 5,
          max: 600,
          step: 5,
          suffix: '秒',
          onChanged: (value) {
            controller.updateSettings(
              settings.copyWith(idleFocusSeconds: value),
            );
          },
        ),
      ],
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

class _WeatherSettingsContent extends StatefulWidget {
  const _WeatherSettingsContent();

  @override
  State<_WeatherSettingsContent> createState() => _WeatherSettingsContentState();
}

class _WeatherSettingsContentState extends State<_WeatherSettingsContent> {
  static const _weatherService = WeatherService();

  late final TextEditingController _cityController;
  late final TextEditingController _apiKeyController;
  Timer? _debounce;
  List<CityResult> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final settings = AppScope.read(context).data.settings;
    _cityController = TextEditingController(text: settings.weatherCity);
    _apiKeyController = TextEditingController(text: settings.weatherApiKey);
    _cityController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityController
      ..removeListener(_onTextChanged)
      ..dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _cityController.text.trim();
    _debounce?.cancel();
    if (text.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      final settings = AppScope.read(context).data.settings;
      final results = await _weatherService.search(text, apiKey: settings.weatherApiKey);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  void _selectCity(CityResult city) {
    _cityController.text = city.fullName;
    setState(() => _suggestions = []);
    final controller = AppScope.read(context);
    controller.updateSettings(
      controller.data.settings.copyWith(
        weatherCity: city.fullName,
        weatherLocationId: city.id,
      ),
    );
  }

  void _clearCity() {
    _cityController.clear();
    setState(() => _suggestions = []);
    final controller = AppScope.read(context);
    controller.updateSettings(
      controller.data.settings.copyWith(
        weatherCity: '',
        weatherLocationId: '',
      ),
    );
  }

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    AppScope.read(context).updateSettings(
      AppScope.read(context).data.settings.copyWith(weatherApiKey: key),
    );
  }

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
                secondary: const Icon(Icons.wb_sunny_outlined),
                title: const Text('显示天气'),
                subtitle: const Text('在计时页顶部显示当前温度'),
                value: settings.weatherEnabled,
                onChanged: (value) {
                  controller.updateSettings(
                    settings.copyWith(weatherEnabled: value),
                  );
                },
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('和风天气 API Key',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('在 dev.qweather.com 免费注册获取',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    hintText: '输入 API Key',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveApiKey(),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('固定城市',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: '输入城市名搜索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _cityController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clearCity,
                          )
                        : _loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ..._suggestions.map((city) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, size: 18),
                    title: Text(city.fullName, style: const TextStyle(fontSize: 14)),
                    onTap: () => _selectCity(city),
                  )),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('定位权限'),
                subtitle: const Text('未设置固定城市时，自动通过 IP 获取位置'),
                trailing: FilledButton.tonalIcon(
                  onPressed: () async {
                    final granted =
                        await PlatformControls.requestLocationPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              granted ? '定位权限已获取' : '定位权限被拒绝',
                            ),
                          ),
                        );
                      if (!granted) {
                        await PlatformControls.openLocationSettings();
                      }
                    }
                  },
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('请求权限'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
