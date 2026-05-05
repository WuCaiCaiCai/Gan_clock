import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

class NativeBridge {
  static const _channel = MethodChannel('tomato_clock/native');

  Future<String> appDataDirectory() async {
    if (Platform.isAndroid) {
      final path = await _channel.invokeMethod<String>('appDataDirectory');
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }
    return _fallbackDataDirectory();
  }

  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  Future<void> startOverlay(TimerSnapshot snapshot) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<Object?>('startOverlay', _overlayArgs(snapshot));
  }

  Future<void> updateOverlay(TimerSnapshot snapshot) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<Object?>('updateOverlay', _overlayArgs(snapshot));
  }

  Future<void> stopOverlay() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('stopOverlay');
  }

  Map<String, Object?> _overlayArgs(TimerSnapshot snapshot) {
    return {
      'mode': snapshot.mode.name,
      'modeLabel': snapshot.mode.label,
      'phase': snapshot.phase.name,
      'totalSeconds': snapshot.totalSeconds,
      'remainingSeconds': snapshot.remainingSeconds,
      'endsAtMillis': snapshot.endsAt?.millisecondsSinceEpoch,
      'isRunning': snapshot.phase == TimerPhase.running,
    };
  }

  String _fallbackDataDirectory() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return '$home/.tomato_clock';
  }
}
