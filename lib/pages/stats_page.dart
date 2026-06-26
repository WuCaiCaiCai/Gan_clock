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
        .where((session) => session.isRecordable)
        .take(8)
        .toList();

    return PopScope<void>(
      canPop: _selectedSession == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedSession != null) {
          _closeSession();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 60),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
                      children: [
                        _TodayStats(data: widget.data),
                        const SizedBox(height: 16),
                        FocusHeatmap(
                          focusSecondsByDay: widget.data.focusSecondsByDay(),
                        ),
                        const SizedBox(height: 16),
                        _RecentSessions(
                          sessions: sessions,
                          onTap: _openSession,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_outlined,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  formatDateTime(session.endedAt),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Icon(
                                session.completed
                                    ? Icons.check_circle_outline
                                    : Icons.stop_circle_outlined,
                                color: session.completed
                                    ? _completedColor
                                    : scheme.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.timer_outlined,
                            label: '专注时长',
                            value: formatHours(session.focusedSeconds),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.schedule,
                            label: '计划时长',
                            value: formatHours(session.plannedSeconds),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.play_arrow_outlined,
                            label: '开始时间',
                            value: formatDateTime(session.startedAt),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.stop_outlined,
                            label: '结束时间',
                            value: formatDateTime(session.endedAt),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.check_outlined,
                            label: '状态',
                            value: session.completed ? '完成' : '已停止',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: '今日专注',
            value: formatHours(todaySeconds),
            detail: '累计时长',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.all_inclusive,
            label: '总专注',
            value: formatHours(totalSeconds),
            detail: '历史累计',
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
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: Text(
                      value,
                      key: ValueKey(value),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.sessions, this.onTap});

  final List<FocusSession> sessions;
  final ValueChanged<FocusSession>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近专注', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          const Text('还没有完成的专注记录')
        else
          for (final session in sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(formatDateTime(session.endedAt)),
              subtitle: Text(
                '${formatHours(session.focusedSeconds)} · ${session.completed ? '完成' : '已停止'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTap != null ? () => onTap!(session) : null,
            ),
      ],
    );
  }
}
