import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../utils.dart';
import 'chrome_fade.dart';

class FloatingDock extends StatelessWidget {
  const FloatingDock({
    required this.hidden,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final bool hidden;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: dockHorizontalMargin,
      right: dockHorizontalMargin,
      bottom: dockBottom(context),
      child: ChromeFade(
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
                height: dockHeight,
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
