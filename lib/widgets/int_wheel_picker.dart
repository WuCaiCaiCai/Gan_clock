import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntWheelPicker extends StatefulWidget {
  const IntWheelPicker({
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
    required this.label,
    required this.suffix,
    required this.icon,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String label;
  final String suffix;
  final IconData icon;

  @override
  State<IntWheelPicker> createState() => _IntWheelPickerState();
}

class _IntWheelPickerState extends State<IntWheelPicker> {
  late final FixedExtentScrollController _controller;
  late final List<int> _options;
  int _lastNotified = 0;
  int _liveValue = 0;

  @override
  void initState() {
    super.initState();
    _options = [
      for (var i = widget.min; i <= widget.max; i += widget.step) i,
    ];
    final initialIndex = _options
        .indexWhere((v) => v >= widget.value)
        .clamp(0, _options.length - 1);
    _lastNotified = widget.value;
    _liveValue = widget.value;
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(IntWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _liveValue = widget.value;
      final idx = _options
          .indexWhere((v) => v >= widget.value)
          .clamp(0, _options.length - 1);
      if (_controller.selectedItem != idx) {
        _controller.jumpToItem(idx);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const itemExtent = 44.0;

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
                Text(
                  widget.label,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _liveValue.toString(),
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: itemExtent,
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scheme.primary.withAlpha(28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: itemExtent,
                    diameterRatio: 1.3,
                    perspective: 0.002,
                    onSelectedItemChanged: _onChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        final selected = _controller.selectedItem == index;
                        final option = _options[index];
                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option.toString(),
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant.withAlpha(120),
                                  fontSize: selected ? null : 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.suffix,
                                style: textTheme.bodySmall?.copyWith(
                                  color: selected
                                      ? scheme.primary.withAlpha(200)
                                      : scheme.onSurfaceVariant.withAlpha(80),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _options.length,
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

  void _onChanged(int index) {
    final next = _options[index];
    if (next != _liveValue) {
      setState(() => _liveValue = next);
    }
    if (next == _lastNotified) return;
    _lastNotified = next;
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }
}
