import 'dart:async';

import 'package:flutter/foundation.dart';

import 'completion_feedback.dart';
import 'models.dart';
import 'storage.dart';
import 'timer_engine.dart';
import 'webdav_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    TomatoStore? storage,
    WebDavService? webDavService,
    CompletionFeedback completionFeedback = const SystemCompletionFeedback(),
    TomatoTimerEngine timerEngine = const TomatoTimerEngine(),
  }) : _webDavService = webDavService ?? WebDavService(),
       _completionFeedback = completionFeedback,
       _timerEngine = timerEngine {
    _storage = storage ?? AppStorage();
  }

  final WebDavService _webDavService;
  final CompletionFeedback _completionFeedback;
  final TomatoTimerEngine _timerEngine;
  late final TomatoStore _storage;

  TomatoData _data = TomatoData.initial();
  Timer? _ticker;
  bool _loading = true;
  bool _syncing = false;
  bool _disposed = false;
  String? _message;

  TomatoData get data => _data;

  bool get loading => _loading;

  bool get syncing => _syncing;

  String? takeMessage() {
    final current = _message;
    _message = null;
    return current;
  }

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      final loaded = await _storage.load();
      final ticked = _timerEngine.tick(loaded);
      _data = ticked.data;
      if (ticked.changed) {
        await _storage.save(_data);
      }
      _setCompletionMessage(ticked.completedMode);
    } on Object {
      _data = TomatoData.initial();
      _message = '本地数据读取失败，已恢复默认番茄钟';
    } finally {
      _loading = false;
      _restartTicker();
      _notify();
    }
  }

  Future<void> start() async {
    await _replaceData(_timerEngine.start(_data));
  }

  Future<void> pause() async {
    await _replaceData(_timerEngine.pause(_data));
  }

  Future<void> reset() async {
    await _replaceData(_timerEngine.reset(_data));
  }

  Future<void> stop() async {
    await _replaceData(_timerEngine.stop(_data));
  }

  Future<void> skip() async {
    await _replaceData(_timerEngine.skip(_data));
  }

  Future<void> selectMode(TimerMode mode) async {
    if (_data.timer.phase == TimerPhase.running) {
      return;
    }
    await _replaceData(_timerEngine.selectMode(_data, mode));
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _replaceData(_timerEngine.applySettings(_data, settings));
  }

  Future<void> updateWebDav(WebDavSettings settings) async {
    await updateSettings(_data.settings.copyWith(webDav: settings));
    _message = 'WebDAV 设置已保存';
    _notify();
  }

  Future<void> syncNow() async {
    if (!_data.settings.webDav.isConfigured || _syncing) {
      return;
    }
    _syncing = true;
    _notify();
    try {
      final merged = await _webDavService.sync(_data.settings.webDav, _data);
      _data = merged;
      await _storage.save(_data);
      _message = 'WebDAV 同步完成';
    } on WebDavException catch (error) {
      _message = error.message;
    } on Object {
      _message = 'WebDAV 同步失败';
    } finally {
      _syncing = false;
      _restartTicker();
      _notify();
    }
  }

  void _tick() {
    final result = _timerEngine.tick(_data);
    if (!result.changed) {
      return;
    }
    _data = result.data;
    _setCompletionMessage(result.completedMode);
    _restartTicker();
    _notify();
    unawaited(_saveCurrentSilently());
  }

  Future<void> _replaceData(TomatoData next) async {
    if (identical(next, _data)) {
      return;
    }
    _data = next;
    _restartTicker();
    _notify();
    await _storage.save(_data);
  }

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_data.timer.phase == TimerPhase.running) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _setCompletionMessage(TimerMode? mode) {
    if (mode == null) {
      return;
    }
    _message = mode == TimerMode.focus ? '专注完成，进入休息' : '休息结束，回到专注';
    unawaited(_completionFeedback.notify(mode, _data.settings));
  }

  Future<void> _saveCurrentSilently() async {
    try {
      await _storage.save(_data);
    } on Object {
      _message = '本地数据保存失败';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
