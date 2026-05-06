import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/app_controller.dart';
import 'package:tomato_clock/completion_feedback.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/storage.dart';
import 'package:tomato_clock/timer_engine.dart';
import 'package:tomato_clock/webdav_service.dart';

class MemoryStore implements TomatoStore {
  MemoryStore(this.data);

  TomatoData data;

  @override
  Future<TomatoData> load() async => data;

  @override
  Future<void> save(TomatoData data) async {
    this.data = data;
  }
}

class RecordingCompletionFeedback implements CompletionFeedback {
  TimerMode? completedMode;
  AppSettings? settings;
  final List<TimerMode> completedModes = [];

  @override
  Future<void> notifyStart(AppSettings settings) => Future<void>.value();

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) {
    this.completedMode = completedMode;
    this.settings = settings;
    completedModes.add(completedMode);
    return Future<void>.value();
  }
}

class RecordingWebDavService extends WebDavService {
  RecordingWebDavService(this.remote);

  TomatoData remote;
  WebDavSettings? settings;
  TomatoData? local;
  int syncCalls = 0;

  @override
  Future<TomatoData> sync(WebDavSettings settings, TomatoData local) async {
    syncCalls += 1;
    this.settings = settings;
    this.local = local;
    remote = local.mergeWith(remote);
    return remote;
  }
}

void main() {
  test(
    'load reconciles expired timer and triggers completion feedback',
    () async {
      final now = DateTime.now();
      final startedAt = now.subtract(const Duration(minutes: 25));
      final expired = TomatoData.initial().copyWith(
        timer: TimerSnapshot(
          mode: TimerMode.focus,
          phase: TimerPhase.running,
          totalSeconds: 1500,
          remainingSeconds: 1,
          startedAt: startedAt,
          endsAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final store = MemoryStore(expired);
      final feedback = RecordingCompletionFeedback();
      final controller = AppController(
        storage: store,
        completionFeedback: feedback,
      );

      await controller.load();

      expect(feedback.completedMode, TimerMode.focus);
      expect(feedback.settings, isNotNull);
      expect(controller.data.timer.mode, TimerMode.shortBreak);
      expect(controller.data.timer.phase, TimerPhase.running);
      expect(controller.data.sessions, hasLength(1));
      expect(store.data.sessions, hasLength(1));

      controller.dispose();
    },
  );

  test('manual WebDAV sync merges remote data and saves it locally', () async {
    final localStarted = DateTime(2026, 1, 1, 9);
    final remoteStarted = DateTime(2026, 1, 2, 9);
    final local = TomatoData.initial().copyWith(
      settings: const AppSettings(
        webDav: WebDavSettings(endpoint: 'https://dav.example.com'),
      ),
      sessions: [
        FocusSession(
          id: 'local',
          startedAt: localStarted,
          endedAt: localStarted.add(const Duration(minutes: 25)),
          plannedSeconds: 1500,
          focusedSeconds: 1500,
          completed: true,
        ),
      ],
      updatedAt: localStarted,
    );
    final remote = TomatoData.initial().copyWith(
      sessions: [
        FocusSession(
          id: 'remote',
          startedAt: remoteStarted,
          endedAt: remoteStarted.add(const Duration(minutes: 25)),
          plannedSeconds: 1500,
          focusedSeconds: 1500,
          completed: true,
        ),
      ],
      updatedAt: remoteStarted,
    );
    final store = MemoryStore(local);
    final webDav = RecordingWebDavService(remote);
    final controller = AppController(
      storage: store,
      webDavService: webDav,
      completionFeedback: const NoopCompletionFeedback(),
    );

    await controller.load();
    await controller.syncNow();

    expect(webDav.syncCalls, 1);
    expect(controller.lastSyncError, isNull);
    expect(controller.lastSyncAt, isNotNull);
    expect(controller.data.sessions.map((item) => item.id), [
      'remote',
      'local',
    ]);
    expect(store.data.sessions.map((item) => item.id), ['remote', 'local']);

    controller.dispose();
  });

  test('creates a timestamped local backup file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tomato_clock_backup_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final data = TomatoData.initial().copyWith(updatedAt: DateTime(2026, 1, 2));
    final store = AppStorage(dataDirectory: directory.path);
    await store.save(data);
    final controller = AppController(
      storage: store,
      completionFeedback: const NoopCompletionFeedback(),
    );

    await controller.load();
    await controller.createLocalBackup();

    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}local_backups',
    );
    final files = backupDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(1));
    expect(await files.single.readAsString(), contains('"schemaVersion": 1'));
    expect(controller.lastLocalBackupError, isNull);
    expect(controller.lastLocalBackupPath, files.single.path);
    expect(controller.lastLocalBackupAt, isNotNull);

    controller.dispose();
  });

  test('creates local backup in configured directory', () async {
    final dataDirectory = await Directory.systemTemp.createTemp(
      'tomato_clock_data_test_',
    );
    final backupDirectory = await Directory.systemTemp.createTemp(
      'tomato_clock_selected_backup_',
    );
    addTearDown(() async {
      for (final directory in [dataDirectory, backupDirectory]) {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    });

    final data = TomatoData.initial().copyWith(
      settings: AppSettings(localBackupDirectory: backupDirectory.path),
    );
    final store = AppStorage(dataDirectory: dataDirectory.path);
    await store.save(data);
    final controller = AppController(
      storage: store,
      completionFeedback: const NoopCompletionFeedback(),
    );

    await controller.load();
    await controller.createLocalBackup();

    final files = backupDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(1));
    expect(controller.lastLocalBackupPath, files.single.path);

    controller.dispose();
  });

  test('manual local backup emits dedicated success message token', () async {
    final dataDirectory = await Directory.systemTemp.createTemp(
      'tomato_clock_manual_backup_msg_test_',
    );
    addTearDown(() async {
      if (await dataDirectory.exists()) {
        await dataDirectory.delete(recursive: true);
      }
    });
    final store = AppStorage(dataDirectory: dataDirectory.path);
    await store.save(TomatoData.initial());
    final controller = AppController(
      storage: store,
      completionFeedback: const NoopCompletionFeedback(),
    );

    await controller.load();
    await controller.createLocalBackup();

    expect(controller.takeMessage(), 'LOCAL_BACKUP_SUCCESS');
    expect(controller.lastLocalBackupPath, isNotNull);
    expect(controller.lastLocalBackupError, isNull);
    controller.dispose();
  });

  test(
    'skip running break triggers completion feedback for returning focus',
    () async {
      final now = DateTime.now();
      const engine = TomatoTimerEngine();
      final breakReady = TomatoData.initial().copyWith(
        timer: engine.snapshotForMode(
          TimerMode.shortBreak,
          const AppSettings(),
        ),
      );
      final runningBreak = engine.start(breakReady, at: now);
      final store = MemoryStore(runningBreak);
      final feedback = RecordingCompletionFeedback();
      final controller = AppController(
        storage: store,
        completionFeedback: feedback,
      );

      await controller.load();
      await controller.skip();

      expect(controller.data.timer.mode, TimerMode.focus);
      expect(controller.data.timer.phase, TimerPhase.running);
      expect(feedback.completedMode, TimerMode.shortBreak);
      expect(feedback.completedModes.last, TimerMode.shortBreak);
      expect(controller.takeMessage(), '休息结束，回到专注');

      controller.dispose();
    },
  );

  test('shows run-finished message when cycle limit is reached', () async {
    final now = DateTime.now();
    final settings = const AppSettings(focusCyclesPerRun: 1);
    final data = TomatoData.initial().copyWith(
      settings: settings,
      timer: TimerSnapshot(
        mode: TimerMode.focus,
        phase: TimerPhase.running,
        totalSeconds: 1500,
        remainingSeconds: 1,
        startedAt: now.subtract(const Duration(minutes: 25)),
        endsAt: now.subtract(const Duration(seconds: 1)),
      ),
    );
    final store = MemoryStore(data);
    final feedback = RecordingCompletionFeedback();
    final controller = AppController(
      storage: store,
      completionFeedback: feedback,
    );

    await controller.load();

    expect(controller.data.timer.mode, TimerMode.focus);
    expect(controller.data.timer.phase, TimerPhase.idle);
    expect(controller.takeMessage(), '已达到循环次数，计时已停止');
    expect(feedback.completedMode, TimerMode.focus);

    controller.dispose();
  });
}
