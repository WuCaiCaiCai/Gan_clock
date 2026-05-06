import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/app_controller.dart';
import 'package:tomato_clock/completion_feedback.dart';
import 'package:tomato_clock/models.dart';
import 'package:tomato_clock/storage.dart';

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

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) {
    this.completedMode = completedMode;
    this.settings = settings;
    return Future<void>.value();
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
}
