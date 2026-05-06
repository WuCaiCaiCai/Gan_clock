import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/timer_engine.dart';

void main() {
  const engine = TomatoTimerEngine();

  test('settings default to vibration only for phase changes', () {
    const settings = AppSettings();

    expect(settings.completionSoundEnabled, isFalse);
    expect(settings.completionHapticsEnabled, isTrue);
    expect(settings.idleFocusSeconds, 30);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.keepScreenOnEnabled, isFalse);
    expect(settings.pictureInPictureEnabled, isTrue);
    expect(settings.backupAutoSyncEnabled, isTrue);
    expect(settings.backupAutoSyncIntervalMinutes, 30);
    expect(settings.focusCyclesPerRun, 4);
    expect(AppSettings.fromJson(const {}).completionSoundEnabled, isFalse);
    expect(AppSettings.fromJson(const {}).completionHapticsEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).idleFocusSeconds, 30);
    expect(AppSettings.fromJson(const {}).themeMode, AppThemeMode.system);
    expect(AppSettings.fromJson(const {}).keepScreenOnEnabled, isFalse);
    expect(AppSettings.fromJson(const {}).pictureInPictureEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).backupAutoSyncEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).backupAutoSyncIntervalMinutes, 30);
    expect(AppSettings.fromJson(const {}).focusCyclesPerRun, 4);
    expect(
      AppSettings.fromJson(const {'darkModeEnabled': true}).themeMode,
      AppThemeMode.dark,
    );
  });

  test('completes focus session and continues into short break', () {
    final start = DateTime(2026, 1, 1, 9);
    final completedAt = start.add(const Duration(seconds: 2));
    final data = TomatoData.initial().copyWith(
      timer:
          const TimerSnapshot(
            mode: TimerMode.focus,
            phase: TimerPhase.running,
            totalSeconds: 1500,
            remainingSeconds: 1,
            startedAt: null,
            endsAt: null,
          ).copyWith(
            startedAt: start,
            endsAt: start.add(const Duration(seconds: 1)),
          ),
    );

    final result = engine.tick(data, at: completedAt);

    expect(result.completedMode, TimerMode.focus);
    expect(result.data.timer.mode, TimerMode.shortBreak);
    expect(result.data.timer.phase, TimerPhase.running);
    expect(result.data.timer.remainingSeconds, 300);
    expect(result.data.timer.startedAt, completedAt);
    expect(
      result.data.timer.endsAt,
      completedAt.add(const Duration(minutes: 5)),
    );
    expect(result.data.focusCycleCount, 1);
    expect(result.data.sessions, hasLength(1));
    expect(result.data.sessions.single.completed, isTrue);
  });

  test('completes break and continues into focus', () {
    final start = DateTime(2026, 1, 1, 9);
    final completedAt = start.add(const Duration(seconds: 2));
    final data = TomatoData.initial().copyWith(
      timer:
          const TimerSnapshot(
            mode: TimerMode.shortBreak,
            phase: TimerPhase.running,
            totalSeconds: 300,
            remainingSeconds: 1,
          ).copyWith(
            startedAt: start,
            endsAt: start.add(const Duration(seconds: 1)),
          ),
    );

    final result = engine.tick(data, at: completedAt);

    expect(result.completedMode, TimerMode.shortBreak);
    expect(result.data.timer.mode, TimerMode.focus);
    expect(result.data.timer.phase, TimerPhase.running);
    expect(result.data.timer.remainingSeconds, 1500);
    expect(
      result.data.timer.endsAt,
      completedAt.add(const Duration(minutes: 25)),
    );
  });

  test('pause keeps remaining seconds and resume creates a new end time', () {
    final start = DateTime(2026, 1, 1, 9);
    final running = engine.start(TomatoData.initial(), at: start);
    final paused = engine.pause(
      running,
      at: start.add(const Duration(minutes: 5)),
    );

    expect(paused.timer.phase, TimerPhase.paused);
    expect(paused.timer.remainingSeconds, 1200);
    expect(paused.timer.endsAt, isNull);

    final resumed = engine.start(
      paused,
      at: start.add(const Duration(minutes: 10)),
    );

    expect(resumed.timer.phase, TimerPhase.running);
    expect(resumed.timer.remainingSeconds, 1200);
    expect(resumed.timer.endsAt, start.add(const Duration(minutes: 30)));
  });

  test('skip only moves a running break back into a running focus', () {
    final start = DateTime(2026, 1, 1, 9);
    final breakReady = TomatoData.initial().copyWith(
      timer: engine.snapshotForMode(TimerMode.shortBreak, const AppSettings()),
    );
    final runningBreak = engine.start(breakReady, at: start);

    final skipped = engine.skip(
      runningBreak,
      at: start.add(const Duration(minutes: 2)),
    );

    expect(skipped.timer.mode, TimerMode.focus);
    expect(skipped.timer.phase, TimerPhase.running);
    expect(skipped.timer.remainingSeconds, 1500);
    expect(skipped.timer.endsAt, start.add(const Duration(minutes: 27)));
  });

  test('skip does not skip a running focus session', () {
    final start = DateTime(2026, 1, 1, 9);
    final runningFocus = engine.start(TomatoData.initial(), at: start);

    final skipped = engine.skip(
      runningFocus,
      at: start.add(const Duration(minutes: 2)),
    );

    expect(skipped.timer.mode, TimerMode.focus);
    expect(skipped.timer.phase, TimerPhase.running);
    expect(skipped.timer.remainingSeconds, 1380);
    expect(skipped.sessions, isEmpty);
  });

  test(
    'stop records focused time after one minute without completing tomato',
    () {
      final start = DateTime(2026, 1, 1, 9);
      final running = engine.start(TomatoData.initial(), at: start);

      final stopped = engine.stop(
        running,
        at: start.add(const Duration(minutes: 5)),
      );

      expect(stopped.timer.phase, TimerPhase.idle);
      expect(stopped.timer.mode, TimerMode.focus);
      expect(stopped.timer.remainingSeconds, 1500);
      expect(stopped.timer.startedAt, isNull);
      expect(stopped.timer.endsAt, isNull);
      expect(stopped.sessions, hasLength(1));
      expect(stopped.sessions.single.focusedSeconds, 300);
      expect(stopped.sessions.single.completed, isFalse);
      expect(stopped.totalFocusSeconds, 300);
    },
  );

  test('stop under one minute does not record focused time', () {
    final start = DateTime(2026, 1, 1, 9);
    final running = engine.start(TomatoData.initial(), at: start);

    final stopped = engine.stop(
      running,
      at: start.add(const Duration(seconds: 30)),
    );

    expect(stopped.sessions, isEmpty);
    expect(stopped.totalFocusSeconds, 0);
  });

  test('stop during break resets to a new focus round', () {
    final start = DateTime(2026, 1, 1, 9);
    final breakReady = TomatoData.initial().copyWith(
      timer: engine.snapshotForMode(TimerMode.longBreak, const AppSettings()),
    );
    final runningBreak = engine.start(breakReady, at: start);

    final stopped = engine.stop(
      runningBreak,
      at: start.add(const Duration(minutes: 2)),
    );

    expect(stopped.timer.mode, TimerMode.focus);
    expect(stopped.timer.phase, TimerPhase.idle);
    expect(stopped.timer.remainingSeconds, 1500);
    expect(stopped.sessions, isEmpty);
  });

  test('completed focus shorter than one minute is not recorded', () {
    final start = DateTime(2026, 1, 1, 9);
    final data = TomatoData.initial().copyWith(
      timer:
          const TimerSnapshot(
            mode: TimerMode.focus,
            phase: TimerPhase.running,
            totalSeconds: 30,
            remainingSeconds: 1,
          ).copyWith(
            startedAt: start,
            endsAt: start.add(const Duration(seconds: 1)),
          ),
    );

    final result = engine.tick(data, at: start.add(const Duration(seconds: 2)));

    expect(result.completedMode, TimerMode.focus);
    expect(result.data.timer.mode, TimerMode.shortBreak);
    expect(result.data.timer.phase, TimerPhase.running);
    expect(result.data.focusCycleCount, 0);
    expect(result.data.sessions, isEmpty);
    expect(result.data.totalFocusSeconds, 0);
    expect(result.data.focusSecondsByDay(), isEmpty);
  });

  test('stats ignore imported sessions shorter than one minute', () {
    final now = DateTime(2026, 1, 1, 9);
    final data = TomatoData.initial().copyWith(
      sessions: [
        FocusSession(
          id: 'short',
          startedAt: now,
          endedAt: now.add(const Duration(seconds: 30)),
          plannedSeconds: 30,
          focusedSeconds: 30,
          completed: true,
        ),
        FocusSession(
          id: 'valid',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 1)),
          plannedSeconds: 60,
          focusedSeconds: 60,
          completed: false,
        ),
      ],
    );

    expect(data.totalFocusSeconds, 60);
    expect(data.focusSecondsByDay(), {dateKey(now): 60});
  });

  test('settings serialize completion feedback switches', () {
    final settings = const AppSettings(
      idleFocusSeconds: 75,
      focusCyclesPerRun: 6,
      themeMode: AppThemeMode.dark,
      keepScreenOnEnabled: true,
      pictureInPictureEnabled: false,
      completionSoundEnabled: false,
      completionHapticsEnabled: false,
      backupAutoSyncEnabled: false,
      backupAutoSyncIntervalMinutes: 45,
      localBackupDirectory: '/tmp/gan_backups',
    );

    final decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.idleFocusSeconds, 75);
    expect(decoded.focusCyclesPerRun, 6);
    expect(decoded.themeMode, AppThemeMode.dark);
    expect(decoded.pictureInPictureEnabled, isFalse);
    expect(decoded.keepScreenOnEnabled, isTrue);
    expect(decoded.completionSoundEnabled, isFalse);
    expect(decoded.completionHapticsEnabled, isFalse);
    expect(decoded.backupAutoSyncEnabled, isFalse);
    expect(decoded.backupAutoSyncIntervalMinutes, 45);
    expect(decoded.localBackupDirectory, '/tmp/gan_backups');
  });

  test('stops automatically after reaching configured focus cycles', () {
    final start = DateTime(2026, 1, 1, 9);
    final settings = const AppSettings(focusCyclesPerRun: 1);
    final data = TomatoData.initial().copyWith(
      settings: settings,
      timer:
          const TimerSnapshot(
            mode: TimerMode.focus,
            phase: TimerPhase.running,
            totalSeconds: 1500,
            remainingSeconds: 1,
          ).copyWith(
            startedAt: start,
            endsAt: start.add(const Duration(seconds: 1)),
          ),
    );

    final result = engine.tick(data, at: start.add(const Duration(seconds: 2)));

    expect(result.completedMode, TimerMode.focus);
    expect(result.data.timer.mode, TimerMode.focus);
    expect(result.data.timer.phase, TimerPhase.idle);
    expect(result.data.timer.remainingSeconds, 1500);
    expect(result.data.timer.completedFocusCycles, 0);
    expect(result.data.sessions, hasLength(1));
  });
}
