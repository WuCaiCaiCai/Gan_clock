import 'package:flutter/services.dart';

typedef PlatformBoolChanged = void Function(bool enabled);

class PlatformControls {
  const PlatformControls._();

  static const _channel = MethodChannel('tomato_clock/platform');
  static PlatformBoolChanged? _onPictureInPictureChanged;
  static PlatformBoolChanged? _onKeepScreenOnChanged;

  static void setEventHandlers({
    PlatformBoolChanged? onPictureInPictureChanged,
    PlatformBoolChanged? onKeepScreenOnChanged,
  }) {
    _onPictureInPictureChanged = onPictureInPictureChanged;
    _onKeepScreenOnChanged = onKeepScreenOnChanged;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static void clearEventHandlers() {
    _onPictureInPictureChanged = null;
    _onKeepScreenOnChanged = null;
    _channel.setMethodCallHandler(null);
  }

  static Future<void> setKeepScreenOn(bool enabled) async {
    await _invokeSilently('setKeepScreenOn', {'enabled': enabled});
  }

  static Future<void> setPipState({
    required bool enabled,
    required String title,
    required String subtitle,
    required bool keepScreenOn,
  }) async {
    await _invokeSilently('setPipState', {
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
      'keepScreenOn': keepScreenOn,
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
      await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      // Android-only affordance; desktop and widget tests can ignore it.
    } on PlatformException {
      // Native support can be absent on older Android versions.
    }
  }

  static Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPictureInPictureModeChanged':
        _onPictureInPictureChanged?.call(_enabledArgument(call.arguments));
        break;
      case 'onKeepScreenOnChanged':
        _onKeepScreenOnChanged?.call(_enabledArgument(call.arguments));
        break;
      default:
        throw MissingPluginException('No handler for ${call.method}');
    }
  }

  static bool _enabledArgument(Object? arguments) {
    if (arguments is Map<Object?, Object?>) {
      return arguments['enabled'] == true;
    }
    return false;
  }
}
