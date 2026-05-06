import 'package:flutter/services.dart';

class PlatformControls {
  const PlatformControls._();

  static const _channel = MethodChannel('tomato_clock/platform');

  static Future<void> setKeepScreenOn(bool enabled) async {
    await _invokeSilently('setKeepScreenOn', {'enabled': enabled});
  }

  static Future<void> setPipState({
    required bool enabled,
    required String title,
    required String subtitle,
  }) async {
    await _invokeSilently('setPipState', {
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
    });
  }

  static Future<void> enterPictureInPicture() async {
    await _invokeSilently('enterPictureInPicture');
  }

  static Future<void> _invokeSilently(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Android-only affordance; desktop and widget tests can ignore it.
    } on PlatformException {
      // Native support can be absent on older Android versions.
    }
  }
}
