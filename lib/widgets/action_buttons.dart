import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';

class TimerActions extends StatelessWidget {
  const TimerActions({
    required this.controller,
    required this.mode,
    required this.phase,
    required this.keepScreenOn,
    required this.pictureInPictureEnabled,
    required this.hapticsEnabled,
    required this.onOpenSettings,
    required this.onToggleKeepScreenOn,
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
    super.key,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool keepScreenOn;
  final bool pictureInPictureEnabled;
  final bool hapticsEnabled;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleKeepScreenOn;
  final ValueChanged<bool> onTogglePictureInPicture;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final canSkip = running && mode != TimerMode.focus;
    final scheme = Theme.of(context).colorScheme;
    final accent = running ? scheme.primary : scheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final iconSize = compact ? 38.0 : 42.0;
        final buttonPadding = EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
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
            constraints: const BoxConstraints(maxWidth: 470),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: scheme.surface.withAlpha(running ? 226 : 214),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withAlpha(running ? 46 : 34)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withAlpha(running ? 26 : 14),
                    blurRadius: running ? 18 : 10,
                    offset: Offset(0, running ? 7 : 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canSkip) ...[
                      FilledButton.icon(
                        style: buttonStyle,
                        onPressed: controller.skip,
                        icon: const Icon(Icons.skip_next, size: 20),
                        label: const Text('跳过休息'),
                      ),
                      const SizedBox(width: 7),
                      _ActionIconButton(
                        size: iconSize,
                        tooltip: '暂停',
                        onPressed: controller.pause,
                        icon: Icons.pause,
                      ),
                    ] else
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
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            running ? Icons.pause : Icons.play_arrow,
                            key: ValueKey(running),
                            size: 20,
                          ),
                        ),
                        label: Text(running ? '暂停' : '开始'),
                      ),
                    const SizedBox(width: 6),
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
                      tooltip: pictureInPictureEnabled ? '关闭小窗播放' : '开启小窗播放',
                      selected: pictureInPictureEnabled,
                      onPressed: () =>
                          onTogglePictureInPicture(!pictureInPictureEnabled),
                      icon: pictureInPictureEnabled
                          ? Icons.picture_in_picture_alt
                          : Icons.picture_in_picture_alt_outlined,
                    ),
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      size: iconSize,
                      tooltip: '设置',
                      onPressed: onOpenSettings,
                      icon: Icons.settings_outlined,
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
