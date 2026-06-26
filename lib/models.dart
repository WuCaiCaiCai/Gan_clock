import 'dart:convert';

enum TimerMode { focus, shortBreak, longBreak }

enum TimerPhase { idle, running, paused }

enum HeatmapScope { month, year }

enum AppThemeMode { system, light, dark }

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

AppThemeMode appThemeModeFromJson(Object? value, {bool? legacyDarkMode}) {
  for (final mode in AppThemeMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  if (legacyDarkMode != null) {
    return legacyDarkMode ? AppThemeMode.dark : AppThemeMode.light;
  }
  return AppThemeMode.system;
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

extension AppThemeModeLabels on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.dark:
        return '夜间';
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
    this.focusCyclesPerRun = 4,
    this.idleFocusSeconds = 30,
    this.themeMode = AppThemeMode.system,
    this.keepScreenOnEnabled = false,
    this.pictureInPictureEnabled = true,
    this.completionSoundEnabled = false,
    this.completionHapticsEnabled = true,
    this.backupAutoSyncEnabled = true,
    this.backupAutoSyncIntervalMinutes = 30,
    this.localBackupDirectory = '',
    this.localBackupAutoEnabled = false,
    this.localBackupAutoIntervalMinutes = 60,
    this.localBackupKeepCount = 5,
    this.webDav = const WebDavSettings(),
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsBeforeLongBreak;
  final int focusCyclesPerRun;
  final int idleFocusSeconds;
  final AppThemeMode themeMode;
  final bool keepScreenOnEnabled;
  final bool pictureInPictureEnabled;
  final bool completionSoundEnabled;
  final bool completionHapticsEnabled;
  final bool backupAutoSyncEnabled;
  final int backupAutoSyncIntervalMinutes;
  final String localBackupDirectory;
  final bool localBackupAutoEnabled;
  final int localBackupAutoIntervalMinutes;
  final int localBackupKeepCount;
  final WebDavSettings webDav;

  AppSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    int? focusCyclesPerRun,
    int? idleFocusSeconds,
    AppThemeMode? themeMode,
    bool? keepScreenOnEnabled,
    bool? pictureInPictureEnabled,
    bool? completionSoundEnabled,
    bool? completionHapticsEnabled,
    bool? backupAutoSyncEnabled,
    int? backupAutoSyncIntervalMinutes,
    String? localBackupDirectory,
    bool? localBackupAutoEnabled,
    int? localBackupAutoIntervalMinutes,
    int? localBackupKeepCount,
    WebDavSettings? webDav,
  }) {
    return AppSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      roundsBeforeLongBreak:
          roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
      focusCyclesPerRun: focusCyclesPerRun ?? this.focusCyclesPerRun,
      idleFocusSeconds: idleFocusSeconds ?? this.idleFocusSeconds,
      themeMode: themeMode ?? this.themeMode,
      keepScreenOnEnabled: keepScreenOnEnabled ?? this.keepScreenOnEnabled,
      pictureInPictureEnabled:
          pictureInPictureEnabled ?? this.pictureInPictureEnabled,
      completionSoundEnabled:
          completionSoundEnabled ?? this.completionSoundEnabled,
      completionHapticsEnabled:
          completionHapticsEnabled ?? this.completionHapticsEnabled,
      backupAutoSyncEnabled:
          backupAutoSyncEnabled ?? this.backupAutoSyncEnabled,
      backupAutoSyncIntervalMinutes:
          backupAutoSyncIntervalMinutes ?? this.backupAutoSyncIntervalMinutes,
      localBackupDirectory: localBackupDirectory ?? this.localBackupDirectory,
      localBackupAutoEnabled:
          localBackupAutoEnabled ?? this.localBackupAutoEnabled,
      localBackupAutoIntervalMinutes:
          localBackupAutoIntervalMinutes ?? this.localBackupAutoIntervalMinutes,
      localBackupKeepCount: localBackupKeepCount ?? this.localBackupKeepCount,
      webDav: webDav ?? this.webDav,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'focusMinutes': focusMinutes,
      'shortBreakMinutes': shortBreakMinutes,
      'longBreakMinutes': longBreakMinutes,
      'roundsBeforeLongBreak': roundsBeforeLongBreak,
      'focusCyclesPerRun': focusCyclesPerRun,
      'idleFocusSeconds': idleFocusSeconds,
      'themeMode': themeMode.name,
      'keepScreenOnEnabled': keepScreenOnEnabled,
      'pictureInPictureEnabled': pictureInPictureEnabled,
      'completionSoundEnabled': completionSoundEnabled,
      'completionHapticsEnabled': completionHapticsEnabled,
      'backupAutoSyncEnabled': backupAutoSyncEnabled,
      'backupAutoSyncIntervalMinutes': backupAutoSyncIntervalMinutes,
      'localBackupDirectory': localBackupDirectory,
      'localBackupAutoEnabled': localBackupAutoEnabled,
      'localBackupAutoIntervalMinutes': localBackupAutoIntervalMinutes,
      'localBackupKeepCount': localBackupKeepCount,
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
      focusCyclesPerRun: _boundedInt(value['focusCyclesPerRun'], 1, 48, 4),
      idleFocusSeconds: _boundedInt(value['idleFocusSeconds'], 5, 600, 30),
      themeMode: appThemeModeFromJson(
        value['themeMode'],
        legacyDarkMode: value['darkModeEnabled'] as bool?,
      ),
      keepScreenOnEnabled: value['keepScreenOnEnabled'] as bool? ?? false,
      pictureInPictureEnabled:
          value['pictureInPictureEnabled'] as bool? ?? true,
      completionSoundEnabled: value['completionSoundEnabled'] as bool? ?? false,
      completionHapticsEnabled:
          value['completionHapticsEnabled'] as bool? ?? true,
      backupAutoSyncEnabled: value['backupAutoSyncEnabled'] as bool? ?? true,
      backupAutoSyncIntervalMinutes: _boundedInt(
        value['backupAutoSyncIntervalMinutes'],
        5,
        1440,
        30,
      ),
      localBackupDirectory: value['localBackupDirectory'] as String? ?? '',
      localBackupAutoEnabled: value['localBackupAutoEnabled'] as bool? ?? false,
      localBackupAutoIntervalMinutes: _boundedInt(
        value['localBackupAutoIntervalMinutes'],
        5,
        1440,
        60,
      ),
      localBackupKeepCount: _boundedInt(
        value['localBackupKeepCount'],
        1,
        50,
        5,
      ),
      webDav: WebDavSettings.fromJson(value['webDav']),
    );
  }
}

class FocusSession {
  static const minimumRecordedSeconds = 60;

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

  bool get isRecordable => focusedSeconds >= minimumRecordedSeconds;

  bool get isCompletedPomodoro => completed && isRecordable;

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
    this.completedFocusCycles = 0,
    this.startedAt,
    this.endsAt,
    this.pausedAt,
  });

  final TimerMode mode;
  final TimerPhase phase;
  final int totalSeconds;
  final int remainingSeconds;
  final int completedFocusCycles;
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
    int? completedFocusCycles,
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
      completedFocusCycles: completedFocusCycles ?? this.completedFocusCycles,
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
      'completedFocusCycles': completedFocusCycles,
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
    final total = _boundedIntOrFallback(
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
      completedFocusCycles: _boundedInt(
        value['completedFocusCycles'],
        0,
        1000,
        0,
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
        .where((session) => session.isRecordable)
        .fold<int>(0, (total, session) => total + session.focusedSeconds);
  }

  Map<String, int> focusSecondsByDay() {
    final result = <String, int>{};
    for (final session in sessions.where((item) => item.isRecordable)) {
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

  static const currentSchemaVersion = 1;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
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
    final data = _migrateSchema(value);
    final settings = AppSettings.fromJson(data['settings']);
    final sessionsById = <String, FocusSession>{};
    final rawSessions = data['sessions'];
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
      timer: TimerSnapshot.fromJson(data['timer'], settings),
      focusCycleCount: _boundedInt(data['focusCycleCount'], 0, 1000000, 0),
      updatedAt: _dateTimeOrNull(data['updatedAt']) ?? DateTime.now(),
    );
  }
}

Map<String, Object?> _migrateSchema(Map<String, Object?> raw) {
  final version = switch (raw['schemaVersion']) {
    int v => v,
    _ => 0, // ponytail: pre-versioning data, compatible with v1
  };
  if (version >= TomatoData.currentSchemaVersion) {
    return raw;
  }
  // ponytail: add schema migrations here when fields change
  // e.g. if (version < 2) { raw['newField'] = defaultValueFromOldField }
  return raw;
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

int _boundedIntOrFallback(Object? value, int min, int max, int fallback) {
  final number = switch (value) {
    int item => item,
    double item => item.round(),
    String item => int.tryParse(item),
    _ => null,
  };
  if (number == null || number < min || number > max) {
    return fallback;
  }
  return number;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
