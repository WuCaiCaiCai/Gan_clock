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
    await PlatformControls.vibratePattern(
      timingsMs: const [0, 80, 60, 160],
      amplitudes: const [0, 180, 0, 220],
    );
  }

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {
    final futures = <Future<void>>[];
    if (settings.completionHapticsEnabled) {
      if (completedMode == TimerMode.focus) {
        // 专注结束 → 进入休息：长振动
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 900, 180, 600],
            amplitudes: const [0, 255, 0, 200],
          ),
        );
      } else {
        // 休息结束 → 回到专注：强提醒
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 520, 120, 520, 120, 760],
            amplitudes: const [0, 235, 0, 235, 0, 255],
          ),
        );
      }
      futures.add(HapticFeedback.heavyImpact());
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
