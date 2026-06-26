import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/models.dart';

void main() {
  test('deserializes pre-schemaVersion data (v0) as valid v1', () {
    final now = DateTime(2026, 1, 15, 10, 30);
    final v0Json = {
      'updatedAt': now.toUtc().toIso8601String(),
      'settings': const AppSettings(
        focusMinutes: 30,
        completionHapticsEnabled: false,
        webDav: WebDavSettings(
          endpoint: 'https://dav.example.com',
          username: 'user',
        ),
      ).toJson(),
      'sessions': [
        FocusSession(
          id: 'focus-old',
          startedAt: now.subtract(const Duration(minutes: 30)),
          endedAt: now,
          plannedSeconds: 1800,
          focusedSeconds: 1800,
          completed: true,
        ).toJson(),
      ],
      'timer': const TimerSnapshot(
        mode: TimerMode.focus,
        phase: TimerPhase.idle,
        totalSeconds: 1800,
        remainingSeconds: 1800,
      ).toJson(),
      'focusCycleCount': 3,
    };

    final data = TomatoData.fromJson(v0Json);

    expect(data.settings.focusMinutes, 30);
    expect(data.settings.completionHapticsEnabled, false);
    expect(data.settings.webDav.endpoint, 'https://dav.example.com');
    expect(data.sessions, hasLength(1));
    expect(data.sessions.single.id, 'focus-old');
    expect(data.sessions.single.completed, isTrue);
    expect(data.focusCycleCount, 3);
    expect(data.timer.phase, TimerPhase.idle);
    expect(data.timer.remainingSeconds, 1800);
  });

  test('schema version is written and roundtrips', () {
    final now = DateTime(2026, 3, 20, 14);
    final original = TomatoData(
      settings: const AppSettings(focusMinutes: 45, shortBreakMinutes: 10),
      timer: const TimerSnapshot(
        mode: TimerMode.shortBreak,
        phase: TimerPhase.paused,
        totalSeconds: 600,
        remainingSeconds: 420,
      ),
      sessions: [
        FocusSession(
          id: 'focus-rt',
          startedAt: now.subtract(const Duration(minutes: 45)),
          endedAt: now,
          plannedSeconds: 2700,
          focusedSeconds: 2700,
          completed: true,
        ),
      ],
      focusCycleCount: 2,
      updatedAt: now,
    );

    final json = original.toJson();
    expect(json['schemaVersion'], TomatoData.currentSchemaVersion);

    final restored = TomatoData.fromJson(json);
    expect(restored.settings.focusMinutes, 45);
    expect(restored.settings.shortBreakMinutes, 10);
    expect(restored.timer.mode, TimerMode.shortBreak);
    expect(restored.timer.phase, TimerPhase.paused);
    expect(restored.timer.remainingSeconds, 420);
    expect(restored.sessions, hasLength(1));
    expect(restored.sessions.single.completed, isTrue);
    expect(restored.focusCycleCount, 2);
  });

  test('settings roundtrip all fields', () {
    final settings = const AppSettings(
      focusMinutes: 30,
      shortBreakMinutes: 10,
      longBreakMinutes: 20,
      roundsBeforeLongBreak: 3,
      focusCyclesPerRun: 6,
      idleFocusSeconds: 45,
      themeMode: AppThemeMode.dark,
      keepScreenOnEnabled: true,
      pictureInPictureEnabled: false,
      completionSoundEnabled: true,
      completionHapticsEnabled: false,
      backupAutoSyncEnabled: false,
      backupAutoSyncIntervalMinutes: 20,
      localBackupDirectory: '/tmp/gan',
      localBackupAutoEnabled: true,
      localBackupAutoIntervalMinutes: 30,
      localBackupKeepCount: 10,
      webDav: WebDavSettings(
        endpoint: 'https://dav.example.com/remote.php/dav',
        username: 'test',
        password: 'secret',
        remotePath: 'gan/clock.json',
      ),
    );

    final decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.focusMinutes, 30);
    expect(decoded.shortBreakMinutes, 10);
    expect(decoded.longBreakMinutes, 20);
    expect(decoded.roundsBeforeLongBreak, 3);
    expect(decoded.focusCyclesPerRun, 6);
    expect(decoded.idleFocusSeconds, 45);
    expect(decoded.themeMode, AppThemeMode.dark);
    expect(decoded.keepScreenOnEnabled, isTrue);
    expect(decoded.pictureInPictureEnabled, isFalse);
    expect(decoded.completionSoundEnabled, isTrue);
    expect(decoded.completionHapticsEnabled, isFalse);
    expect(decoded.backupAutoSyncEnabled, isFalse);
    expect(decoded.backupAutoSyncIntervalMinutes, 20);
    expect(decoded.localBackupDirectory, '/tmp/gan');
    expect(decoded.localBackupAutoEnabled, isTrue);
    expect(decoded.localBackupAutoIntervalMinutes, 30);
    expect(decoded.localBackupKeepCount, 10);
    expect(decoded.webDav.endpoint, 'https://dav.example.com/remote.php/dav');
    expect(decoded.webDav.username, 'test');
    expect(decoded.webDav.password, 'secret');
    expect(decoded.webDav.remotePath, 'gan/clock.json');
  });

  test('legacy darkModeEnabled maps to themeMode', () {
    final dark = AppSettings.fromJson(const {'darkModeEnabled': true});
    expect(dark.themeMode, AppThemeMode.dark);

    final light = AppSettings.fromJson(const {'darkModeEnabled': false});
    expect(light.themeMode, AppThemeMode.light);

    final none = AppSettings.fromJson(const {});
    expect(none.themeMode, AppThemeMode.system);
  });

  test('settings bounded int clamps to valid range', () {
    final settings = AppSettings.fromJson({
      'focusMinutes': 999,
      'backupAutoSyncIntervalMinutes': 3,
      'localBackupKeepCount': 100,
      'focusCyclesPerRun': 0,
    });

    expect(settings.focusMinutes, 240); // clamped to max
    expect(settings.backupAutoSyncIntervalMinutes, 5); // clamped to min
    expect(settings.localBackupKeepCount, 50); // clamped to max
    expect(settings.focusCyclesPerRun, 1); // clamped to min
  });

  test('tomato data toPrettyJson produces valid parseable JSON', () {
    final data = TomatoData.initial();
    final pretty = data.toPrettyJson();
    final decoded = jsonDecode(pretty);
    expect(decoded, isA<Map<String, Object?>>());
    final restored = TomatoData.fromJson(decoded);
    expect(restored.settings.focusMinutes, 25);
  });

  test(
    'timer snapshot fromJson falls back to settings duration on bad total',
    () {
      const settings = AppSettings(focusMinutes: 25);
      final snapshot = TimerSnapshot.fromJson({
        'mode': 'focus',
        'phase': 'idle',
        'totalSeconds': 99999,
        'remainingSeconds': 99999,
      }, settings);

      expect(snapshot.totalSeconds, 1500); // 25 * 60
    },
  );
}
