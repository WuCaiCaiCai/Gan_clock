import 'package:flutter/services.dart';

import 'models.dart';
import 'platform_controls.dart';

abstract class CompletionFeedback {
  Future<void> notifyStart(AppSettings settings);
  Future<void> notify(TimerMode completedMode, AppSettings settings);
}

class SystemCompletionFeedback implements CompletionFeedback {
  const SystemCompletionFeedback();

  @override
  Future<void> notifyStart(AppSettings settings) async {
    if (!settings.completionHapticsEnabled) {
      return;
    }
    // 计时开始：明确双脉冲
    await PlatformControls.vibratePattern(
      timingsMs: const [0, 180, 70, 280],
      amplitudes: const [0, 255, 0, 255],
    );
  }

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {
    final futures = <Future<void>>[];
    if (settings.completionHapticsEnabled) {
      if (completedMode == TimerMode.focus) {
        // 专注结束 → 进入休息：长振提示
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 1200, 180, 900],
            amplitudes: const [0, 255, 0, 255],
          ),
        );
      } else {
        // 休息结束/跳过休息 → 回到专注：强节奏三段振动
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 350, 110, 350, 110, 520],
            amplitudes: const [0, 255, 0, 255, 0, 255],
          ),
        );
      }
    }
    if (settings.completionSoundEnabled) {
      futures.add(SystemSound.play(SystemSoundType.alert));
    }
    await Future.wait(futures);
  }
}

class NoopCompletionFeedback implements CompletionFeedback {
  const NoopCompletionFeedback();

  @override
  Future<void> notifyStart(AppSettings settings) async {}

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {}
}
