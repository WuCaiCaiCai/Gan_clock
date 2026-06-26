import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';

const shelfSeedColor = Color(0xFF646464);

String formatClock(int seconds) {
  final safe = math.max(0, seconds);
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final rest = safe % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String formatHours(int seconds) {
  if (seconds <= 0) {
    return '0 分钟';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    return '$minutes 分钟';
  }
  if (minutes == 0) {
    return '$hours 小时';
  }
  return '$hours 小时 $minutes 分钟';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String lastSyncLabel(DateTime? value) {
  if (value == null) {
    return '尚未同步';
  }
  return '上次同步 ${formatDateTime(value)}';
}

String phaseLabel(TimerPhase phase) {
  switch (phase) {
    case TimerPhase.idle:
      return '准备开始';
    case TimerPhase.running:
      return '计时中';
    case TimerPhase.paused:
      return '已暂停';
  }
}

IconData modeIcon(TimerMode mode) {
  switch (mode) {
    case TimerMode.focus:
      return Icons.radio_button_checked;
    case TimerMode.shortBreak:
      return Icons.local_cafe_outlined;
    case TimerMode.longBreak:
      return Icons.chair_outlined;
  }
}

IconData themeModeIcon(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return Icons.brightness_auto_outlined;
    case AppThemeMode.light:
      return Icons.light_mode_outlined;
    case AppThemeMode.dark:
      return Icons.dark_mode_outlined;
  }
}

class StagePalette {
  const StagePalette({
    required this.accent,
    required this.lightBackground,
    required this.darkBackground,
  });

  final Color accent;
  final Color lightBackground;
  final Color darkBackground;

  Color backgroundFor(BuildContext context) {
    return Theme.of(context).colorScheme.brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }
}

Color contrastOnColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

StagePalette modePalette(TimerMode mode) {
  switch (mode) {
    case TimerMode.focus:
      return const StagePalette(
        accent: Color(0xFFB15E52),
        lightBackground: Color(0xFFEFEAEC),
        darkBackground: Color(0xFF171416),
      );
    case TimerMode.shortBreak:
      return const StagePalette(
        accent: Color(0xFF3D8A5D),
        lightBackground: Color(0xFFE9EFEB),
        darkBackground: Color(0xFF141916),
      );
    case TimerMode.longBreak:
      return const StagePalette(
        accent: Color(0xFF3D79A8),
        lightBackground: Color(0xFFE8ECF2),
        darkBackground: Color(0xFF14191E),
      );
  }
}

bool get usesPersistentTray => defaultTargetPlatform == TargetPlatform.linux;
