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
    int? totalSeconds,
    int? remainingSeconds,
  }) async {
    final arguments = <String, Object?>{
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
      'keepScreenOn': keepScreenOn,
    };
    if (totalSeconds != null) {
      arguments['totalSeconds'] = totalSeconds;
    }
    if (remainingSeconds != null) {
      arguments['remainingSeconds'] = remainingSeconds;
    }
    await _invokeSilently('setPipState', arguments);
  }

  static Future<void> enterPictureInPicture() async {
    await _invokeSilently('enterPictureInPicture');
  }

  static Future<void> setTimerNotification({
    required bool enabled,
    required String title,
    required String subtitle,
    required int totalSeconds,
    required int remainingSeconds,
  }) async {
    await _invokeSilently('setTimerNotification', {
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
      'totalSeconds': totalSeconds,
      'remainingSeconds': remainingSeconds,
    });
  }

  static Future<void> showStageNotification({
    required String title,
    required String subtitle,
  }) async {
    await _invokeSilently('showStageNotification', {
      'title': title,
      'subtitle': subtitle,
    });
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    await _invokeSilently('openNotificationSettings');
  }

  static Future<bool> requestLocationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestLocationPermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openLocationSettings() async {
    await _invokeSilently('openLocationSettings');
  }

  static Future<String?> pickDirectory() async {
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> pickBackupFile() async {
    try {
      return await _channel.invokeMethod<String>('pickBackupFile');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> readTextFile({required String fileUri}) async {
    if (fileUri.trim().isEmpty) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('readTextFile', {
        'fileUri': fileUri,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> writeTextFile({
    required String directoryUri,
    required String displayName,
    required String contents,
  }) async {
    try {
      return await _channel.invokeMethod<String>('writeTextFile', {
        'directoryUri': directoryUri,
        'displayName': displayName,
        'contents': contents,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> vibrate({required int durationMs, int? amplitude}) async {
    final arguments = <String, Object?>{'durationMs': durationMs};
    if (amplitude case final amplitude?) {
      arguments['amplitude'] = amplitude;
    }
    await _invokeSilently('vibrate', arguments);
  }

  static Future<void> vibratePattern({
    required List<int> timingsMs,
    List<int>? amplitudes,
  }) async {
    final arguments = <String, Object?>{'timingsMs': timingsMs};
    if (amplitudes != null) {
      arguments['amplitudes'] = amplitudes;
    }
    await _invokeSilently('vibratePattern', arguments);
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
