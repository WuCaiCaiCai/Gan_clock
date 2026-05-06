import 'dart:convert';

enum TimerMode { focus, shortBreak, longBreak }

enum TimerPhase { idle, running, paused }

enum HeatmapScope { month, year }

String dateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

TimerMode timerModeFromJson(Object? value) {
  return TimerMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => TimerMode.focus,
  );
}

TimerPhase timerPhaseFromJson(Object? value) {
  return TimerPhase.values.firstWhere(
    (phase) => phase.name == value,
    orElse: () => TimerPhase.idle,
  );
}

extension TimerModeLabels on TimerMode {
  String get label {
    switch (this) {
      case TimerMode.focus:
        return '专注';
      case TimerMode.shortBreak:
        return '短休息';
      case TimerMode.longBreak:
        return '长休息';
    }
  }

  int durationSeconds(AppSettings settings) {
    switch (this) {
      case TimerMode.focus:
        return settings.focusMinutes * 60;
      case TimerMode.shortBreak:
        return settings.shortBreakMinutes * 60;
      case TimerMode.longBreak:
        return settings.longBreakMinutes * 60;
    }
  }
}

class WebDavSettings {
  const WebDavSettings({
    this.endpoint = '',
    this.username = '',
    this.password = '',
    this.remotePath = 'tomato_clock/backup.json',
  });

  final String endpoint;
  final String username;
  final String password;
  final String remotePath;

  bool get isConfigured => endpoint.trim().isNotEmpty;

  WebDavSettings copyWith({
    String? endpoint,
    String? username,
    String? password,
    String? remotePath,
  }) {
    return WebDavSettings(
      endpoint: endpoint ?? this.endpoint,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'endpoint': endpoint,
      'username': username,
      'password': password,
      'remotePath': remotePath,
    };
  }

  factory WebDavSettings.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const WebDavSettings();
    }
    return WebDavSettings(
      endpoint: value['endpoint'] as String? ?? '',
      username: value['username'] as String? ?? '',
      password: value['password'] as String? ?? '',
      remotePath: value['remotePath'] as String? ?? 'tomato_clock/backup.json',
    );
  }
}

class AppSettings {
  const AppSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsBeforeLongBreak = 4,
    this.completionSoundEnabled = true,
    this.completionHapticsEnabled = true,
    this.webDav = const WebDavSettings(),
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsBeforeLongBreak;
  final bool completionSoundEnabled;
  final bool completionHapticsEnabled;
  final WebDavSettings webDav;

  AppSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    bool? completionSoundEnabled,
    bool? completionHapticsEnabled,
    WebDavSettings? webDav,
  }) {
    return AppSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      roundsBeforeLongBreak:
          roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
      completionSoundEnabled:
          completionSoundEnabled ?? this.completionSoundEnabled,
      completionHapticsEnabled:
          completionHapticsEnabled ?? this.completionHapticsEnabled,
      webDav: webDav ?? this.webDav,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'focusMinutes': focusMinutes,
      'shortBreakMinutes': shortBreakMinutes,
      'longBreakMinutes': longBreakMinutes,
      'roundsBeforeLongBreak': roundsBeforeLongBreak,
      'completionSoundEnabled': completionSoundEnabled,
      'completionHapticsEnabled': completionHapticsEnabled,
      'webDav': webDav.toJson(),
    };
  }

  factory AppSettings.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const AppSettings();
    }
    return AppSettings(
      focusMinutes: _boundedInt(value['focusMinutes'], 1, 240, 25),
      shortBreakMinutes: _boundedInt(value['shortBreakMinutes'], 1, 120, 5),
      longBreakMinutes: _boundedInt(value['longBreakMinutes'], 1, 240, 15),
      roundsBeforeLongBreak: _boundedInt(
        value['roundsBeforeLongBreak'],
        1,
        12,
        4,
      ),
      completionSoundEnabled: value['completionSoundEnabled'] as bool? ?? true,
      completionHapticsEnabled:
          value['completionHapticsEnabled'] as bool? ?? true,
      webDav: WebDavSettings.fromJson(value['webDav']),
    );
  }
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.completed,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int focusedSeconds;
  final bool completed;

  String get dayKey => dateKey(endedAt);

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'plannedSeconds': plannedSeconds,
      'focusedSeconds': focusedSeconds,
      'completed': completed,
    };
  }

  factory FocusSession.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid focus session');
    }
    return FocusSession(
      id: value['id'] as String? ?? '',
      startedAt: DateTime.parse(value['startedAt'] as String).toLocal(),
      endedAt: DateTime.parse(value['endedAt'] as String).toLocal(),
      plannedSeconds: _boundedInt(value['plannedSeconds'], 1, 24 * 3600, 1500),
      focusedSeconds: _boundedInt(value['focusedSeconds'], 1, 24 * 3600, 1500),
      completed: value['completed'] as bool? ?? true,
    );
  }
}

class TimerSnapshot {
  const TimerSnapshot({
    required this.mode,
    required this.phase,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.startedAt,
    this.endsAt,
    this.pausedAt,
  });

  final TimerMode mode;
  final TimerPhase phase;
  final int totalSeconds;
  final int remainingSeconds;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? pausedAt;

  bool get isActive =>
      phase == TimerPhase.running || phase == TimerPhase.paused;

  TimerSnapshot copyWith({
    TimerMode? mode,
    TimerPhase? phase,
    int? totalSeconds,
    int? remainingSeconds,
    DateTime? startedAt,
    DateTime? endsAt,
    DateTime? pausedAt,
    bool clearEndsAt = false,
    bool clearPausedAt = false,
  }) {
    return TimerSnapshot(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      startedAt: startedAt ?? this.startedAt,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'mode': mode.name,
      'phase': phase.name,
      'totalSeconds': totalSeconds,
      'remainingSeconds': remainingSeconds,
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'endsAt': endsAt?.toUtc().toIso8601String(),
      'pausedAt': pausedAt?.toUtc().toIso8601String(),
    };
  }

  factory TimerSnapshot.initial(AppSettings settings) {
    final seconds = TimerMode.focus.durationSeconds(settings);
    return TimerSnapshot(
      mode: TimerMode.focus,
      phase: TimerPhase.idle,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );
  }

  factory TimerSnapshot.fromJson(Object? value, AppSettings settings) {
    if (value is! Map<String, Object?>) {
      return TimerSnapshot.initial(settings);
    }
    final mode = timerModeFromJson(value['mode']);
    final total = _boundedInt(
      value['totalSeconds'],
      1,
      24 * 3600,
      mode.durationSeconds(settings),
    );
    return TimerSnapshot(
      mode: mode,
      phase: timerPhaseFromJson(value['phase']),
      totalSeconds: total,
      remainingSeconds: _boundedInt(
        value['remainingSeconds'],
        0,
        24 * 3600,
        total,
      ),
      startedAt: _dateTimeOrNull(value['startedAt']),
      endsAt: _dateTimeOrNull(value['endsAt']),
      pausedAt: _dateTimeOrNull(value['pausedAt']),
    );
  }
}

class TomatoData {
  const TomatoData({
    required this.settings,
    required this.sessions,
    required this.timer,
    required this.focusCycleCount,
    required this.updatedAt,
  });

  final AppSettings settings;
  final List<FocusSession> sessions;
  final TimerSnapshot timer;
  final int focusCycleCount;
  final DateTime updatedAt;

  TomatoData copyWith({
    AppSettings? settings,
    List<FocusSession>? sessions,
    TimerSnapshot? timer,
    int? focusCycleCount,
    DateTime? updatedAt,
  }) {
    return TomatoData(
      settings: settings ?? this.settings,
      sessions: sessions ?? this.sessions,
      timer: timer ?? this.timer,
      focusCycleCount: focusCycleCount ?? this.focusCycleCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get totalFocusSeconds {
    return sessions
        .where((session) => session.completed)
        .fold<int>(0, (total, session) => total + session.focusedSeconds);
  }

  Map<String, int> focusSecondsByDay() {
    final result = <String, int>{};
    for (final session in sessions.where((item) => item.completed)) {
      result.update(
        session.dayKey,
        (value) => value + session.focusedSeconds,
        ifAbsent: () => session.focusedSeconds,
      );
    }
    return result;
  }

  TomatoData mergeWith(TomatoData remote) {
    final byId = <String, FocusSession>{};
    for (final session in [...sessions, ...remote.sessions]) {
      if (session.id.isNotEmpty) {
        byId[session.id] = session;
      }
    }
    final mergedSessions = byId.values.toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final remoteIsNewer = remote.updatedAt.isAfter(updatedAt);
    final useRemoteTimer =
        remote.timer.isActive && !timer.isActive ||
        (remote.timer.isActive == timer.isActive && remoteIsNewer);
    final mergedTimer = useRemoteTimer ? remote.timer : timer;
    final mergedCycleCount = useRemoteTimer
        ? remote.focusCycleCount
        : focusCycleCount;
    final newestSettings = remoteIsNewer ? remote.settings : settings;
    return copyWith(
      settings: newestSettings,
      sessions: mergedSessions,
      timer: mergedTimer,
      focusCycleCount: mergedCycleCount,
      updatedAt: remoteIsNewer ? remote.updatedAt : updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'settings': settings.toJson(),
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'timer': timer.toJson(),
      'focusCycleCount': focusCycleCount,
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory TomatoData.initial() {
    const settings = AppSettings();
    return TomatoData(
      settings: settings,
      sessions: const [],
      timer: TimerSnapshot.initial(settings),
      focusCycleCount: 0,
      updatedAt: DateTime.now(),
    );
  }

  factory TomatoData.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return TomatoData.initial();
    }
    final settings = AppSettings.fromJson(value['settings']);
    final sessionsById = <String, FocusSession>{};
    final rawSessions = value['sessions'];
    if (rawSessions is List<Object?>) {
      for (final item in rawSessions) {
        try {
          final session = FocusSession.fromJson(item);
          final key = session.id.isEmpty
              ? '${session.endedAt.microsecondsSinceEpoch}'
              : session.id;
          sessionsById[key] = session;
        } on FormatException {
          continue;
        }
      }
    }
    final sessions = sessionsById.values.toList();
    sessions.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return TomatoData(
      settings: settings,
      sessions: sessions,
      timer: TimerSnapshot.fromJson(value['timer'], settings),
      focusCycleCount: _boundedInt(value['focusCycleCount'], 0, 1000000, 0),
      updatedAt: _dateTimeOrNull(value['updatedAt']) ?? DateTime.now(),
    );
  }
}

int _boundedInt(Object? value, int min, int max, int fallback) {
  final number = switch (value) {
    int item => item,
    double item => item.round(),
    String item => int.tryParse(item) ?? fallback,
    _ => fallback,
  };
  return number.clamp(min, max);
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
