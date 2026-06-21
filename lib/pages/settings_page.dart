import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models.dart';
import '../platform_controls.dart';
import '../utils.dart';

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
  int _syncSubPage = 0;

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
        switchOutCurve: Curves.easeInCubic,
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
                  leading: Icon(themeModeIcon(settings.themeMode)),
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
        return const _TimerSettingsContent();
      case 2:
        return const _FeedbackSettingsContent();
      case 3:
        return const _AppearanceSettingsContent();
      case 4:
        return _syncSubPage == 1
            ? const _WebDavSettingsContent()
            : _BackupContent(onOpenWebDav: _openWebDavSubPage);
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
        : controller.lastSyncError ?? lastSyncLabel(lastSyncAt);

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
                            icon: Icon(themeModeIcon(mode)),
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
