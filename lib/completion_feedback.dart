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
    // 短促双击：告知计时已开始
    await PlatformControls.vibratePattern(
      timingsMs: const [0, 120, 80, 220],
      amplitudes: const [0, 200, 0, 255],
    );
  }

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {
    final futures = <Future<void>>[];
    if (settings.completionHapticsEnabled) {
      if (completedMode == TimerMode.focus) {
        // 专注结束 → 进入休息：持续长振动，让人放松下来
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 1200, 200, 800],
            amplitudes: const [0, 255, 0, 220],
          ),
        );
      } else {
        // 休息结束 → 回到专注：强节奏三段振动，把注意力拉回来
        futures.add(
          PlatformControls.vibratePattern(
            timingsMs: const [0, 600, 140, 600, 140, 900],
            amplitudes: const [0, 235, 0, 245, 0, 255],
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
