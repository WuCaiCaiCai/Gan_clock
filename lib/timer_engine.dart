import 'dart:math' as math;

import 'models.dart';

class TimerTickResult {
  const TimerTickResult({
    required this.data,
    required this.changed,
    this.completedMode,
  });

  final TomatoData data;
  final bool changed;
  final TimerMode? completedMode;
}

class TomatoTimerEngine {
  const TomatoTimerEngine();

  TimerSnapshot snapshotForMode(TimerMode mode, AppSettings settings) {
    final seconds = mode.durationSeconds(settings);
    return TimerSnapshot(
      mode: mode,
      phase: TimerPhase.idle,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );
  }

  TomatoData start(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final ticked = tick(data, at: now).data;
    final current = ticked.timer;
    if (current.phase == TimerPhase.running) {
      return ticked;
    }

    final total = current.totalSeconds > 0
        ? current.totalSeconds
        : current.mode.durationSeconds(ticked.settings);
    final remaining = current.phase == TimerPhase.paused
        ? current.remainingSeconds.clamp(1, total)
        : total;

    return ticked.copyWith(
      timer: TimerSnapshot(
        mode: current.mode,
        phase: TimerPhase.running,
        totalSeconds: total,
        remainingSeconds: remaining,
        startedAt: current.startedAt ?? now,
        endsAt: now.add(Duration(seconds: remaining)),
      ),
      updatedAt: now,
    );
  }

  TomatoData pause(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final ticked = tick(data, at: now).data;
    final current = ticked.timer;
    if (current.phase != TimerPhase.running) {
      return ticked;
    }

    final remaining = _remainingSeconds(current, now);
    return ticked.copyWith(
      timer: current.copyWith(
        phase: TimerPhase.paused,
        remainingSeconds: remaining,
        pausedAt: now,
        clearEndsAt: true,
      ),
      updatedAt: now,
    );
  }

  TomatoData reset(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return data.copyWith(
      timer: snapshotForMode(data.timer.mode, data.settings),
      updatedAt: now,
    );
  }

  TomatoData stop(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final ticked = tick(data, at: now).data;
    final current = ticked.timer;
    if (current.phase == TimerPhase.idle) {
      return ticked.copyWith(
        timer: snapshotForMode(current.mode, ticked.settings),
        updatedAt: now,
      );
    }

    final stopped = _recordStoppedFocus(ticked, current, now);
    return stopped.copyWith(
      timer: snapshotForMode(current.mode, stopped.settings),
      updatedAt: now,
    );
  }

  TomatoData selectMode(TomatoData data, TimerMode mode, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return data.copyWith(
      timer: snapshotForMode(mode, data.settings),
      updatedAt: now,
    );
  }

  TomatoData skip(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final ticked = tick(data, at: now).data;
    final nextMode = _nextModeAfter(ticked.timer.mode, ticked);
    return ticked.copyWith(
      timer: snapshotForMode(nextMode, ticked.settings),
      updatedAt: now,
    );
  }

  TimerTickResult tick(TomatoData data, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final current = data.timer;
    if (current.phase != TimerPhase.running) {
      return TimerTickResult(data: data, changed: false);
    }

    final remaining = _remainingSeconds(current, now);
    if (remaining > 0) {
      if (remaining == current.remainingSeconds) {
        return TimerTickResult(data: data, changed: false);
      }
      return TimerTickResult(
        data: data.copyWith(
          timer: current.copyWith(remainingSeconds: remaining),
          updatedAt: now,
        ),
        changed: true,
      );
    }

    final completedMode = current.mode;
    return TimerTickResult(
      data: _completeCurrent(data, now),
      changed: true,
      completedMode: completedMode,
    );
  }

  TomatoData applySettings(
    TomatoData data,
    AppSettings settings, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final current = data.timer;
    final updatedTotal = current.mode.durationSeconds(settings);
    final timer = current.phase == TimerPhase.idle
        ? TimerSnapshot(
            mode: current.mode,
            phase: TimerPhase.idle,
            totalSeconds: updatedTotal,
            remainingSeconds: updatedTotal,
          )
        : current;

    return data.copyWith(settings: settings, timer: timer, updatedAt: now);
  }

  TomatoData _completeCurrent(TomatoData data, DateTime now) {
    final current = data.timer;
    final sessions = [...data.sessions];
    var cycleCount = data.focusCycleCount;
    var nextMode = TimerMode.focus;

    if (current.mode == TimerMode.focus) {
      final focusedSeconds = current.totalSeconds;
      if (focusedSeconds >= FocusSession.minimumRecordedSeconds) {
        cycleCount += 1;
        sessions.insert(
          0,
          FocusSession(
            id: 'focus-${now.microsecondsSinceEpoch}',
            startedAt:
                current.startedAt ??
                now.subtract(Duration(seconds: current.totalSeconds)),
            endedAt: now,
            plannedSeconds: current.totalSeconds,
            focusedSeconds: focusedSeconds,
            completed: true,
          ),
        );
        nextMode = _nextBreakMode(cycleCount, data.settings);
      } else {
        nextMode = TimerMode.shortBreak;
      }
    }

    return data.copyWith(
      sessions: sessions,
      timer: snapshotForMode(nextMode, data.settings),
      focusCycleCount: cycleCount,
      updatedAt: now,
    );
  }

  TomatoData _recordStoppedFocus(
    TomatoData data,
    TimerSnapshot current,
    DateTime now,
  ) {
    if (current.mode != TimerMode.focus) {
      return data;
    }
    final focusedSeconds = (current.totalSeconds - current.remainingSeconds)
        .clamp(0, current.totalSeconds);
    if (focusedSeconds < FocusSession.minimumRecordedSeconds) {
      return data;
    }

    final startedAt =
        current.startedAt ?? now.subtract(Duration(seconds: focusedSeconds));
    return data.copyWith(
      sessions: [
        FocusSession(
          id: 'focus-stop-${now.microsecondsSinceEpoch}',
          startedAt: startedAt,
          endedAt: now,
          plannedSeconds: current.totalSeconds,
          focusedSeconds: focusedSeconds,
          completed: false,
        ),
        ...data.sessions,
      ],
      updatedAt: now,
    );
  }

  TimerMode _nextModeAfter(TimerMode mode, TomatoData data) {
    if (mode != TimerMode.focus) {
      return TimerMode.focus;
    }
    return _nextBreakMode(data.focusCycleCount + 1, data.settings);
  }

  TimerMode _nextBreakMode(int completedFocusCount, AppSettings settings) {
    if (completedFocusCount % settings.roundsBeforeLongBreak == 0) {
      return TimerMode.longBreak;
    }
    return TimerMode.shortBreak;
  }

  int _remainingSeconds(TimerSnapshot snapshot, DateTime now) {
    final endsAt = snapshot.endsAt;
    if (endsAt == null) {
      return snapshot.remainingSeconds;
    }
    final millis = endsAt.difference(now).inMilliseconds;
    final seconds = (millis / Duration.millisecondsPerSecond).ceil();
    return math.max(0, math.min(seconds, snapshot.totalSeconds));
  }
}
