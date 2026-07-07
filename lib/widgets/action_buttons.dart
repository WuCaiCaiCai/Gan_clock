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
    required this.onOpenSettings,
    required this.onOpenStats,
    required this.onToggleKeepScreenOn,
    required this.onUiHaptic,
    super.key,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool keepScreenOn;
  final bool hapticsEnabled;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenStats;
  final VoidCallback onToggleKeepScreenOn;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final canStop = phase != TimerPhase.idle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canStop)
              _IconBtn(
                icon: Icons.stop,
                tooltip: '停止',
                onPressed: () {
                  if (hapticsEnabled) unawaited(onUiHaptic());
                  controller.stop();
                },
              ),
            if (canStop) const SizedBox(width: 20),
            _IconBtn(
              icon: keepScreenOn ? Icons.lightbulb : Icons.lightbulb_outline,
              tooltip: keepScreenOn ? '关闭常亮' : '屏幕常亮',
              selected: keepScreenOn,
              onPressed: onToggleKeepScreenOn,
            ),
            const SizedBox(width: 20),
            _IconBtn(
              icon: Icons.bar_chart_outlined,
              tooltip: '统计',
              onPressed: onOpenStats,
            ),
            const SizedBox(width: 20),
            _IconBtn(
              icon: Icons.settings_outlined,
              tooltip: '设置',
              onPressed: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: running
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: running
                  ? controller.pause
                  : () {
                      if (hapticsEnabled) unawaited(onUiHaptic());
                      controller.start();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    key: ValueKey(running),
                    children: [
                      Icon(
                        running ? Icons.pause : Icons.play_arrow,
                        size: 24,
                        color: running
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        running
                            ? '暂停'
                            : phase == TimerPhase.paused
                                ? '继续'
                                : '开始',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: running
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({
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
      child: IconButton(
        icon: Icon(icon, size: 22),
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.all(8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
