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
    expect(AppSettings.fromJson(const {}).completionSoundEnabled, isFalse);
    expect(AppSettings.fromJson(const {}).completionHapticsEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).idleFocusSeconds, 30);
    expect(AppSettings.fromJson(const {}).themeMode, AppThemeMode.system);
    expect(
      AppSettings.fromJson(const {'darkModeEnabled': true}).themeMode,
      AppThemeMode.dark,
    );
  });

  test('completes focus session and advances to short break', () {
    final start = DateTime(2026, 1, 1, 9);
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

    final result = engine.tick(data, at: start.add(const Duration(seconds: 2)));

    expect(result.completedMode, TimerMode.focus);
    expect(result.data.timer.mode, TimerMode.shortBreak);
    expect(result.data.timer.phase, TimerPhase.idle);
    expect(result.data.focusCycleCount, 1);
    expect(result.data.sessions, hasLength(1));
    expect(result.data.sessions.single.completed, isTrue);
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

  test('stop cancels current timer without recording a session', () {
    final start = DateTime(2026, 1, 1, 9);
    final running = engine.start(TomatoData.initial(), at: start);

    final stopped = engine.stop(
      running,
      at: start.add(const Duration(minutes: 5)),
    );

    expect(stopped.timer.phase, TimerPhase.idle);
    expect(stopped.timer.remainingSeconds, 1500);
    expect(stopped.timer.startedAt, isNull);
    expect(stopped.timer.endsAt, isNull);
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
          completed: true,
        ),
      ],
    );

    expect(data.totalFocusSeconds, 60);
    expect(data.focusSecondsByDay(), {dateKey(now): 60});
  });

  test('settings serialize completion feedback switches', () {
    final settings = const AppSettings(
      idleFocusSeconds: 75,
      themeMode: AppThemeMode.dark,
      completionSoundEnabled: false,
      completionHapticsEnabled: false,
    );

    final decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.idleFocusSeconds, 75);
    expect(decoded.themeMode, AppThemeMode.dark);
    expect(decoded.completionSoundEnabled, isFalse);
    expect(decoded.completionHapticsEnabled, isFalse);
  });
}
