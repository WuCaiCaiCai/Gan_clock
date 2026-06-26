import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class FocusEdgeNav extends StatelessWidget {
  const FocusEdgeNav({
    required this.open,
    required this.visualHidden,
    required this.selectedIndex,
    required this.settings,
    required this.timer,
    required this.onOpen,
    required this.onClose,
    required this.onSelected,
    required this.onToggleKeepScreenOn,
    required this.onTogglePictureInPicture,
    super.key,
  });

  final bool open;
  final bool visualHidden;
  final int selectedIndex;
  final AppSettings settings;
  final TimerSnapshot timer;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleKeepScreenOn;
  final ValueChanged<bool> onTogglePictureInPicture;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 280);
    final curve = Curves.easeOutCubic;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: Offstage(
            offstage: !open,
            child: IgnorePointer(
              ignoring: !open,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: duration,
                curve: curve,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: ColoredBox(color: Colors.black.withAlpha(34)),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Offstage(
            offstage: !open,
            child: IgnorePointer(
              ignoring: !open,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth
                      .clamp(280.0, 340.0)
                      .toDouble();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedSlide(
                      offset: open ? Offset.zero : const Offset(1.04, 0),
                      duration: duration,
                      curve: curve,
                      child: AnimatedOpacity(
                        opacity: open ? 1 : 0,
                        duration: duration,
                        curve: curve,
                        child: SizedBox(
                          key: const ValueKey('focus_nav_panel'),
                          width: width,
                          height: double.infinity,
                          child: SafeArea(
                            left: false,
                            child: _NavPanel(
                              selectedIndex: selectedIndex,
                              settings: settings,
                              timer: timer,
                              onSelected: onSelected,
                              onToggleKeepScreenOn: onToggleKeepScreenOn,
                              onTogglePictureInPicture:
                                  onTogglePictureInPicture,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            key: const ValueKey('focus_edge_handle'),
            behavior: HitTestBehavior.translucent,
            onTap: onOpen,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < 220) {
                onOpen();
              }
            },
            child: SizedBox(
              width: 44 + MediaQuery.paddingOf(context).right,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: visualHidden || open ? 0 : 1,
                  duration: duration,
                  curve: curve,
                  child: Container(
                    width: 3,
                    height: 72,
                    margin: EdgeInsets.only(
                      right: 7 + MediaQuery.paddingOf(context).right,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withAlpha(58),
                      borderRadius: BorderRadius.circular(99),
                    ),
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

class _NavPanel extends StatelessWidget {
  const _NavPanel({
    required this.selectedIndex,
    required this.settings,
    required this.timer,
    required this.onSelected,
    required this.onToggleKeepScreenOn,
    required this.onTogglePictureInPicture,
  });

  final int selectedIndex;
  final AppSettings settings;
  final TimerSnapshot timer;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleKeepScreenOn;
  final ValueChanged<bool> onTogglePictureInPicture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = modePalette(timer.mode);
    final pipLabel = usesPersistentTray ? '托盘常驻' : '画中画';
    final pipIcon = usesPersistentTray
        ? (settings.pictureInPictureEnabled
              ? Icons.notifications_active
              : Icons.notifications_none)
        : (settings.pictureInPictureEnabled
              ? Icons.picture_in_picture_alt
              : Icons.picture_in_picture_alt_outlined);

    return Material(
      color: scheme.surface.withAlpha(244),
      elevation: 14,
      shadowColor: Colors.black.withAlpha(34),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimerStatusHeader(timer: timer, accent: palette.accent),
            const SizedBox(height: 22),
            _NavItem(
              icon: Icons.timer_outlined,
              selectedIcon: Icons.timer,
              label: '番茄钟',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: '统计',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: '设置',
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            const Spacer(),
            Row(
              children: [
                _AuxButton(
                  tooltip: settings.keepScreenOnEnabled ? '关闭屏幕常亮' : '开启屏幕常亮',
                  label: '常亮',
                  selected: settings.keepScreenOnEnabled,
                  icon: settings.keepScreenOnEnabled
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                  onPressed: onToggleKeepScreenOn,
                ),
                const SizedBox(width: 10),
                _AuxButton(
                  tooltip: settings.pictureInPictureEnabled
                      ? '关闭$pipLabel'
                      : '开启$pipLabel',
                  label: pipLabel,
                  selected: settings.pictureInPictureEnabled,
                  icon: pipIcon,
                  onPressed: timer.phase == TimerPhase.running
                      ? () => onTogglePictureInPicture(
                          !settings.pictureInPictureEnabled,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerStatusHeader extends StatelessWidget {
  const _TimerStatusHeader({required this.timer, required this.accent});

  final TimerSnapshot timer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatClock(timer.remainingSeconds),
              style: theme.textTheme.displaySmall?.copyWith(
                height: 0.98,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(modeIcon(timer.mode), size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  '${timer.mode.label} · ${phaseLabel(timer.phase)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? scheme.primary.withAlpha(22) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuxButton extends StatelessWidget {
  const _AuxButton({
    required this.tooltip,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: selected
                ? scheme.primary
                : scheme.onSurfaceVariant,
            backgroundColor: selected
                ? scheme.primary.withAlpha(18)
                : scheme.surfaceContainerHighest.withAlpha(128),
            side: BorderSide(
              color: selected
                  ? scheme.primary.withAlpha(56)
                  : scheme.outlineVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
