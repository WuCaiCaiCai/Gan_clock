import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class FocusHeatmap extends StatefulWidget {
  const FocusHeatmap({required this.focusSecondsByDay, super.key, this.now});

  final Map<String, int> focusSecondsByDay;
  final DateTime? now;

  @override
  State<FocusHeatmap> createState() => _FocusHeatmapState();
}

class _FocusHeatmapState extends State<FocusHeatmap> {
  HeatmapScope _scope = HeatmapScope.month;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final selectedDate =
        _selectedDate ?? DateTime(now.year, now.month, now.day);
    final cells = _scope == HeatmapScope.month
        ? _monthCells(now, widget.focusSecondsByDay)
        : _yearCells(now, widget.focusSecondsByDay);
    final activeCells = cells.where((cell) => cell.inScope).toList();
    final selectedCell =
        _selectedCell(activeCells, selectedDate) ??
        activeCells.firstWhere(
          (cell) => cell.date != null,
          orElse: () => const _HeatmapCell(),
        );
    final activeDays = activeCells.where((cell) => cell.seconds > 0).length;
    final totalSeconds = activeCells.fold<int>(
      0,
      (total, cell) => total + cell.seconds,
    );
    final heatmapBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scope == HeatmapScope.month
            ? _MonthHeatmap(
                cells: cells,
                selectedDate: selectedCell.date,
                onSelected: _selectDate,
              )
            : _YearHeatmap(
                cells: cells,
                selectedDate: selectedCell.date,
                onSelected: _selectDate,
              ),
        const SizedBox(height: 12),
        const _HeatmapLegend(),
      ],
    );
    final summary = _HeatmapSummary(
      label: _scopeLabel(now, _scope),
      activeDays: activeDays,
      totalSeconds: totalSeconds,
    );

    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '专注热力图',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SegmentedButton<HeatmapScope>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: HeatmapScope.month,
                        icon: Icon(Icons.calendar_view_month),
                        label: Text('月'),
                      ),
                      ButtonSegment(
                        value: HeatmapScope.year,
                        icon: Icon(Icons.calendar_today),
                        label: Text('年'),
                      ),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (values) {
                      setState(() {
                        _scope = values.single;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 560;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: heatmapBody),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 206,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              if (selectedCell.inScope) ...[
                                const SizedBox(height: 12),
                                _SelectedDaySummary(cell: selectedCell),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 14),
                      heatmapBody,
                      if (selectedCell.inScope) ...[
                        const SizedBox(height: 12),
                        _SelectedDaySummary(cell: selectedCell),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }
}

class _HeatmapSummary extends StatelessWidget {
  const _HeatmapSummary({
    required this.label,
    required this.activeDays,
    required this.totalSeconds,
  });

  final String label;
  final int activeDays;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 260;
        final metrics = [
          _HeatmapMetric(
            icon: Icons.date_range_outlined,
            label: label,
            value: '$activeDays 天',
          ),
          _HeatmapMetric(
            icon: Icons.timer_outlined,
            label: '累计',
            value: _formatDuration(totalSeconds),
          ),
        ];
        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [metrics[0], const SizedBox(height: 8), metrics[1]],
          );
        }
        return Row(
          children: [
            Expanded(child: metrics[0]),
            const SizedBox(width: 8),
            Expanded(child: metrics[1]),
          ],
        );
      },
    );
  }
}

class _HeatmapMetric extends StatelessWidget {
  const _HeatmapMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
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

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.cells,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<_HeatmapCell> cells;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final rows = (cells.length / DateTime.daysPerWeek).ceil();
        final tile = math.min(
          42.0,
          (constraints.maxWidth - gap * (DateTime.daysPerWeek - 1)) /
              DateTime.daysPerWeek,
        );
        final width =
            tile * DateTime.daysPerWeek + gap * (DateTime.daysPerWeek - 1);
        final height = tile * rows + gap * (rows - 1);

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: DateTime.daysPerWeek,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
              ),
              itemBuilder: (context, index) {
                return _HeatmapTile(
                  cell: cells[index],
                  compact: false,
                  selected: _isSameDay(cells[index].date, selectedDate),
                  onSelected: onSelected,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({
    required this.cells,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<_HeatmapCell> cells;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final weeks = (cells.length / DateTime.daysPerWeek).ceil();
    final rowMajorCells = <_HeatmapCell>[
      for (var weekday = 0; weekday < DateTime.daysPerWeek; weekday++)
        for (var week = 0; week < weeks; week++)
          cells[math.min(
            week * DateTime.daysPerWeek + weekday,
            cells.length - 1,
          )],
    ];
    const tile = 12.0;
    const gap = 4.0;
    final width = weeks * tile + (weeks - 1) * gap;
    const height =
        DateTime.daysPerWeek * tile + (DateTime.daysPerWeek - 1) * gap;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rowMajorCells.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: weeks,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemBuilder: (context, index) {
            return _HeatmapTile(
              cell: rowMajorCells[index],
              compact: true,
              selected: _isSameDay(rowMajorCells[index].date, selectedDate),
              onSelected: onSelected,
            );
          },
        ),
      ),
    );
  }
}

class _HeatmapTile extends StatelessWidget {
  const _HeatmapTile({
    required this.cell,
    required this.compact,
    required this.selected,
    required this.onSelected,
  });

  final _HeatmapCell cell;
  final bool compact;
  final bool selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(compact ? 3 : 5);
    final color = cell.inScope
        ? _heatColor(context, cell.seconds)
        : const Color(0x00FFFFFF);
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: selected ? Border.all(color: scheme.secondary, width: 2) : null,
      ),
      child: compact || !cell.inScope
          ? const SizedBox.expand()
          : Center(
              child: Text(
                '${cell.date!.day}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cell.seconds > 0
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
    );
    if (!cell.inScope) {
      return child;
    }
    return Tooltip(
      message: '${dateKey(cell.date!)} ${_formatDuration(cell.seconds)}',
      child: InkWell(
        borderRadius: radius,
        onTap: () => onSelected(cell.date!),
        child: child,
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({required this.cell});

  final _HeatmapCell cell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: DecoratedBox(
        key: ValueKey(dateKey(cell.date!)),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.event_note_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDate(cell.date!)} · 专注 ${_formatDuration(cell.seconds)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '少',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        for (final seconds in const [
          0,
          15 * 60,
          30 * 60,
          60 * 60,
          90 * 60,
        ]) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: _heatColor(context, seconds),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const SizedBox.square(dimension: 12),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        Text(
          '多',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeatmapCell {
  const _HeatmapCell({this.date, this.seconds = 0});

  final DateTime? date;
  final int seconds;

  bool get inScope => date != null;
}

List<_HeatmapCell> _monthCells(DateTime now, Map<String, int> values) {
  final first = DateTime(now.year, now.month);
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final leading = first.weekday - DateTime.monday;
  final rawCells = <_HeatmapCell>[
    for (var index = 0; index < leading; index++) const _HeatmapCell(),
    for (var day = 1; day <= daysInMonth; day++)
      _cellFor(DateTime(now.year, now.month, day), values),
  ];
  final trailing =
      (DateTime.daysPerWeek - rawCells.length % DateTime.daysPerWeek) %
      DateTime.daysPerWeek;
  return [
    ...rawCells,
    for (var index = 0; index < trailing; index++) const _HeatmapCell(),
  ];
}

List<_HeatmapCell> _yearCells(DateTime now, Map<String, int> values) {
  final first = DateTime(now.year);
  final last = DateTime(now.year, 12, 31);
  final leading = first.weekday - DateTime.monday;
  final rawCells = <_HeatmapCell>[
    for (var index = 0; index < leading; index++) const _HeatmapCell(),
  ];
  for (
    var cursor = first;
    !cursor.isAfter(last);
    cursor = cursor.add(const Duration(days: 1))
  ) {
    rawCells.add(_cellFor(cursor, values));
  }
  final trailing =
      (DateTime.daysPerWeek - rawCells.length % DateTime.daysPerWeek) %
      DateTime.daysPerWeek;
  return [
    ...rawCells,
    for (var index = 0; index < trailing; index++) const _HeatmapCell(),
  ];
}

_HeatmapCell _cellFor(DateTime date, Map<String, int> values) {
  return _HeatmapCell(date: date, seconds: values[dateKey(date)] ?? 0);
}

_HeatmapCell? _selectedCell(List<_HeatmapCell> cells, DateTime selectedDate) {
  for (final cell in cells) {
    if (_isSameDay(cell.date, selectedDate)) {
      return cell;
    }
  }
  return null;
}

bool _isSameDay(DateTime? left, DateTime? right) {
  return left != null &&
      right != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

Color _heatColor(BuildContext context, int seconds) {
  final scheme = Theme.of(context).colorScheme;
  if (seconds <= 0) {
    return scheme.surfaceContainerHighest;
  }
  final progress = (seconds / (90 * 60)).clamp(0.0, 1.0);
  return Color.lerp(
    scheme.primary.withAlpha((0.35 * 255).round()),
    scheme.primary,
    progress,
  )!;
}

String _scopeLabel(DateTime now, HeatmapScope scope) {
  switch (scope) {
    case HeatmapScope.month:
      return '${now.year}.${now.month.toString().padLeft(2, '0')}';
    case HeatmapScope.year:
      return '${now.year}';
  }
}

String _formatDate(DateTime value) {
  return '${value.year}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0 分钟';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    return '$minutes 分钟';
  }
  if (minutes == 0) {
    return '$hours 小时';
  }
  return '$hours 小时 $minutes 分钟';
}
