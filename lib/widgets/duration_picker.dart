import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DurationPicker extends StatefulWidget {
  const DurationPicker({
    required this.valueMinutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.onChanged,
    required this.label,
    required this.icon,
    super.key,
  });

  final int valueMinutes;
  final int minMinutes;
  final int maxMinutes;
  final ValueChanged<int> onChanged;
  final String label;
  final IconData icon;

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  int _liveHours = 0;
  int _liveMinutes = 0;
  Timer? _notifyTimer;

  int get maxHours => widget.maxMinutes ~/ 60;
  int get currentHours => (widget.valueMinutes ~/ 60).clamp(0, maxHours);
  int get currentMinutes => widget.valueMinutes % 60;

  @override
  void initState() {
    super.initState();
    _liveHours = currentHours;
    _liveMinutes = currentMinutes;
    _hourController = FixedExtentScrollController(initialItem: currentHours);
    _minuteController = FixedExtentScrollController(
      initialItem: _minuteIndex(currentMinutes),
    );
  }

  @override
  void didUpdateWidget(DurationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueMinutes != widget.valueMinutes) {
      _liveHours = currentHours;
      _liveMinutes = currentMinutes;
      final h = currentHours;
      final m = _minuteIndex(currentMinutes);
      if (_hourController.selectedItem != h) _hourController.jumpToItem(h);
      if (_minuteController.selectedItem != m) _minuteController.jumpToItem(m);
    }
  }

  int _minuteIndex(int minutes) => (minutes ~/ 5).clamp(0, 11);
  int _minuteValue(int index) => (index * 5).clamp(0, 55);

  void _notifyChange() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final hours = _hourController.selectedItem;
      final minuteIndex = _minuteController.selectedItem;
      final minutes = _minuteValue(minuteIndex);
      if (hours != _liveHours || minutes != _liveMinutes) {
        setState(() {
          _liveHours = hours;
          _liveMinutes = minutes;
        });
      }
      final total = (hours * 60 + minutes).clamp(widget.minMinutes, widget.maxMinutes);
      if (total != widget.valueMinutes) {
        HapticFeedback.selectionClick();
        widget.onChanged(total);
      }
    });
  }

  String _formatDisplay(int hours, int minutes) {
    if (hours == 0) return '$minutes 分钟';
    if (minutes == 0) return '$hours 小时';
    return '$hours 小时 $minutes 分钟';
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const itemExtent = 40.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(widget.label,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDisplay(_liveHours, _liveMinutes),
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: itemExtent * 3,
              child: Row(
                children: [
                  Expanded(
                    child: _WheelColumn(
                      controller: _hourController,
                      itemCount: maxHours + 1,
                      itemExtent: itemExtent,
                      formatLabel: (i) => i.toString(),
                      suffix: '时',
                      onChanged: _notifyChange,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(':', style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withAlpha(180),
                    )),
                  ),
                  Expanded(
                    child: _WheelColumn(
                      controller: _minuteController,
                      itemCount: 12,
                      itemExtent: itemExtent,
                      formatLabel: (i) => _minuteValue(i).toString().padLeft(2, '0'),
                      suffix: '分',
                      onChanged: _notifyChange,
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

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.formatLabel,
    required this.suffix,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double itemExtent;
  final String Function(int) formatLabel;
  final String suffix;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CupertinoPicker(
      scrollController: controller,
      itemExtent: itemExtent,
      backgroundColor: Colors.transparent,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          color: scheme.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.primary.withAlpha(28)),
        ),
      ),
      onSelectedItemChanged: (_) => onChanged(),
      children: [
        for (var i = 0; i < itemCount; i++)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatLabel(i),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
