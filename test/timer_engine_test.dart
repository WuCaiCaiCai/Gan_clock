import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/timer_engine.dart';

void main() {
  const engine = TomatoTimerEngine();

  test('settings default to vibration only for phase changes', () {
    const settings = AppSettings();

    expect(settings.completionSoundEnabled, isFalse);
    expect(settings.completionHapticsEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).completionSoundEnabled, isFalse);
    expect(AppSettings.fromJson(const {}).completionHapticsEnabled, isTrue);
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

  test('settings serialize completion feedback switches', () {
    final settings = const AppSettings(
      completionSoundEnabled: false,
      completionHapticsEnabled: false,
    );

    final decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.completionSoundEnabled, isFalse);
    expect(decoded.completionHapticsEnabled, isFalse);
  });
}
