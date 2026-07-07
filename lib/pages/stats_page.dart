import 'package:flutter/material.dart';

import '../heatmap.dart';
import '../models.dart';
import '../utils.dart';

const _completedColor = Color(0xFF2F7D57);

class StatsPage extends StatefulWidget {
  const StatsPage({
    required this.data,
    required this.onSubPageOpenChanged,
    super.key,
  });

  final TomatoData data;
  final ValueChanged<bool> onSubPageOpenChanged;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  FocusSession? _selectedSession;

  void _openSession(FocusSession session) {
    setState(() => _selectedSession = session);
    widget.onSubPageOpenChanged(true);
  }

  void _closeSession() {
    setState(() => _selectedSession = null);
    widget.onSubPageOpenChanged(false);
  }

  @override
  void dispose() {
    widget.onSubPageOpenChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.data.sessions
        .where((s) => s.isRecordable)
        .take(10)
        .toList();

    return PopScope<void>(
      canPop: _selectedSession == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedSession != null) _closeSession();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _selectedSession != null
            ? KeyedSubtree(
                key: const ValueKey('session-detail'),
                child: _SessionDetail(
                  session: _selectedSession!,
                  onBack: _closeSession,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('stats-main'),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TodayStats(data: widget.data),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: '专注热力图'),
                      const SizedBox(height: 12),
                      FocusHeatmap(
                        focusSecondsByDay: widget.data.focusSecondsByDay(),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: '最近专注'),
                      const SizedBox(height: 10),
                      if (sessions.isEmpty)
                        _EmptyState()
                      else
                        ...sessions.map(
                          (s) => _SessionTile(
                            session: s,
                            onTap: () => _openSession(s),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session, required this.onBack});
  final FocusSession session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              Text('专注详情', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_outlined,
                            color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            formatDateTime(session.endedAt),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        _StatusBadge(completed: session.completed),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(icon: Icons.timer_outlined, label: '专注时长',
                      value: formatHours(session.focusedSeconds)),
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.schedule, label: '计划时长',
                      value: formatHours(session.plannedSeconds)),
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.play_arrow_outlined, label: '开始时间',
                      value: formatDateTime(session.startedAt)),
                    const SizedBox(height: 10),
                    _DetailRow(icon: Icons.stop_outlined, label: '结束时间',
                      value: formatDateTime(session.endedAt)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: completed ? _completedColor.withAlpha(20) : scheme.error.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        completed ? '完成' : '未完成',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: completed ? _completedColor : scheme.error,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.data});
  final TomatoData data;

  @override
  Widget build(BuildContext context) {
    final today = dateKey(DateTime.now());
    final byDay = data.focusSecondsByDay();
    final todaySeconds = byDay[today] ?? 0;
    final totalSeconds = data.totalFocusSeconds;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.today_outlined,
            label: '今日专注',
            value: formatHours(todaySeconds),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.all_inclusive,
            label: '总专注',
            value: formatHours(totalSeconds),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      value,
                      key: ValueKey(value),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});
  final FocusSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_fire_department_outlined, size: 18, color: scheme.primary),
        ),
        title: Text(formatDateTime(session.endedAt),
          style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Row(
          children: [
            Text(formatHours(session.focusedSeconds),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(width: 8),
            _StatusBadge(completed: session.completed),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.self_improvement_outlined, size: 40, color: scheme.outlineVariant),
          const SizedBox(height: 10),
          Text('还没有专注记录',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
