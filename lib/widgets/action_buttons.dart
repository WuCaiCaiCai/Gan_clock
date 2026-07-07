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
    required this.hapticsEnabled,
    required this.pictureInPictureEnabled,
    required this.onOpenSettings,
    required this.onOpenStats,
    required this.onToggleKeepScreenOn,
    required this.onTogglePictureInPicture,
    required this.onUiHaptic,
    super.key,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool keepScreenOn;
  final bool hapticsEnabled;
  final bool pictureInPictureEnabled;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenStats;
  final VoidCallback onToggleKeepScreenOn;
  final ValueChanged<bool> onTogglePictureInPicture;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final paused = phase == TimerPhase.paused;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FnBtn(
                  icon: pictureInPictureEnabled
                      ? Icons.picture_in_picture_alt
                      : Icons.picture_in_picture_alt_outlined,
                  tooltip: '画中画',
                  selected: pictureInPictureEnabled,
                  onPressed: () =>
                      onTogglePictureInPicture(!pictureInPictureEnabled),
                ),
                const SizedBox(width: 8),
                _FnBtn(
                  icon: keepScreenOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  tooltip: keepScreenOn ? '关闭常亮' : '屏幕常亮',
                  selected: keepScreenOn,
                  onPressed: onToggleKeepScreenOn,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FnBtn(
                  icon: Icons.bar_chart_outlined,
                  tooltip: '统计',
                  onPressed: onOpenStats,
                ),
                const SizedBox(width: 8),
                _FnBtn(
                  icon: Icons.settings_outlined,
                  tooltip: '设置',
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onLongPress: () {
            if (phase != TimerPhase.idle) {
              if (hapticsEnabled) unawaited(onUiHaptic());
              controller.stop();
            }
          },
          child: SizedBox(
            width: 80,
            height: 80,
            child: Material(
              color: running ? scheme.primary : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: running
                    ? controller.pause
                    : () {
                        if (hapticsEnabled) unawaited(onUiHaptic());
                        controller.start();
                      },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    key: ValueKey(running),
                    children: [
                      Icon(
                        running ? Icons.pause : Icons.play_arrow,
                        size: 28,
                        color: running
                            ? scheme.onPrimary
                            : scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        running
                            ? '暂停'
                            : (paused ? '继续' : '开始'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: running
                              ? scheme.onPrimary
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FnBtn extends StatelessWidget {
  const _FnBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: selected
              ? scheme.primary.withAlpha(20)
              : scheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: Icon(
              icon,
              size: 22,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
