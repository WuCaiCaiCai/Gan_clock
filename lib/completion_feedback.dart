import 'package:flutter/services.dart';

import 'models.dart';

abstract class CompletionFeedback {
  Future<void> notify(TimerMode completedMode, AppSettings settings);
}

class SystemCompletionFeedback implements CompletionFeedback {
  const SystemCompletionFeedback();

  @override
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {
    final futures = <Future<void>>[];
    if (settings.completionHapticsEnabled) {
      futures.add(HapticFeedback.vibrate());
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
  Future<void> notify(TimerMode completedMode, AppSettings settings) async {}
}
