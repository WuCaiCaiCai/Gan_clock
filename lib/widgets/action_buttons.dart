import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models.dart';

class TimerActions extends StatelessWidget {
  const TimerActions({
    required this.controller,
    required this.mode,
    required this.phase,
    required this.hapticsEnabled,
    required this.onUiHaptic,
    super.key,
  });

  final AppController controller;
  final TimerMode mode;
  final TimerPhase phase;
  final bool hapticsEnabled;
  final Future<void> Function() onUiHaptic;

  @override
  Widget build(BuildContext context) {
    final running = phase == TimerPhase.running;
    final paused = phase == TimerPhase.paused;
    final canStop = phase != TimerPhase.idle;
    final canSkip = running && mode != TimerMode.focus;
    final scheme = Theme.of(context).colorScheme;
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              elevation: 3,
              shadowColor: Colors.black.withAlpha(18),
              color: scheme.surface.withAlpha(218),
              borderRadius: BorderRadius.circular(999),
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
                    if (canStop) ...[
                      const SizedBox(width: 7),
                      _ActionIconButton(
                        size: iconSize,
                        tooltip: paused ? '停止并重置' : '停止',
                        onPressed: () {
                          if (hapticsEnabled) {
                            unawaited(onUiHaptic());
                          }
                          controller.stop();
                        },
                        icon: Icons.stop_circle_outlined,
                      ),
                    ],
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
  });

  final double size;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
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
              return scheme.surfaceContainerHighest;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return scheme.onSurfaceVariant.withAlpha(130);
              }
              return scheme.onSurfaceVariant;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(color: scheme.outlineVariant.withAlpha(120));
            }),
          ),
      icon: Icon(icon, size: 20),
    );
  }
}
