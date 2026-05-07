import 'dart:async';
import 'dart:convert';

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
  Timer? _autoSyncTimer;
  Timer? _localBackupTimer;
  Future<void> _saveQueue = Future<void>.value();
  DateTime? _lastAutoSyncAttemptAt;
  DateTime? _lastSyncAt;
  String? _lastSyncError;
  DateTime? _lastLocalBackupAt;
  String? _lastLocalBackupPath;
  String? _lastLocalBackupError;
  bool _loading = true;
  bool _syncing = false;
  bool _disposed = false;
  bool _saveErrorNotified = false;
  String? _message;

  TomatoData get data => _data;

  bool get loading => _loading;

  bool get syncing => _syncing;

  DateTime? get lastSyncAt => _lastSyncAt;

  String? get lastSyncError => _lastSyncError;

  DateTime? get lastLocalBackupAt => _lastLocalBackupAt;

  String? get lastLocalBackupPath => _lastLocalBackupPath;

  String? get lastLocalBackupError => _lastLocalBackupError;

  String localBackupStatusLabel() {
    final error = _lastLocalBackupError;
    if (error != null) {
      return error;
    }
    final path = _lastLocalBackupPath;
    if (path == null) {
      return '本地同步尚未创建';
    }
    return '本地同步已保存 ${_formatDateTime(_lastLocalBackupAt!)} · $path';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

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
        await _saveData(_data);
      }
      _setCompletionMessage(ticked.completedMode);
    } on Object {
      _data = TomatoData.initial();
      _message = '本地数据读取失败，已恢复默认番茄钟';
    } finally {
      _loading = false;
      _restartTicker();
      _restartAutoSyncTimer();
      _restartLocalBackupTimer();
      _notify();
    }
  }

  Future<void> start() async {
    await _replaceData(_timerEngine.start(_data));
    unawaited(_completionFeedback.notifyStart(_data.settings));
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
    final before = _data.timer;
    final next = _timerEngine.skip(_data);
    await _replaceData(next);
    if (before.phase == TimerPhase.running &&
        before.mode != TimerMode.focus &&
        next.timer.phase == TimerPhase.running &&
        next.timer.mode == TimerMode.focus) {
      _setCompletionMessage(before.mode);
      _notify();
    }
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
    unawaited(_autoSyncIfDue(force: true));
  }

  Future<void> syncNow() async {
    await _syncNow(silent: false, force: true);
  }

  Future<void> createLocalBackup({String? directory}) async {
    await _runLocalBackup(
      directory: directory,
      keepCount: _data.settings.localBackupKeepCount,
      manual: true,
    );
  }

  Future<void> restoreFromLocalJson(String rawJson) async {
    try {
      final decoded = TomatoData.fromJson(_decodeJsonObject(rawJson));
      final now = DateTime.now();
      final ticked = _timerEngine.tick(decoded, at: now);
      _data = ticked.data;
      await _saveData(_data);
      _restartTicker();
      _restartAutoSyncTimer();
      _restartLocalBackupTimer();
      _message = 'LOCAL_RESTORE_SUCCESS';
    } on FormatException {
      _message = '本地同步文件格式无效';
    } on Object {
      _message = '本地恢复失败';
    } finally {
      _notify();
    }
  }

  Future<void> restoreFromWebDav() async {
    final settings = _data.settings.webDav;
    if (!settings.isConfigured) {
      _message = '请先配置 WebDAV';
      _notify();
      return;
    }
    if (_syncing) {
      return;
    }
    _syncing = true;
    _lastSyncError = null;
    _notify();
    try {
      final remote = await _webDavService.download(settings);
      final now = DateTime.now();
      final ticked = _timerEngine.tick(remote, at: now);
      _data = ticked.data;
      await _saveData(_data);
      _lastSyncAt = now;
      _lastSyncError = null;
      _message = 'CLOUD_RESTORE_SUCCESS';
      _restartTicker();
      _restartAutoSyncTimer();
      _restartLocalBackupTimer();
    } on WebDavException catch (error) {
      _lastSyncError = error.message;
      _message = error.message;
    } on Object {
      _lastSyncError = '云端恢复失败';
      _message = '云端恢复失败';
    } finally {
      _syncing = false;
      _notify();
    }
  }

  Future<void> _runLocalBackup({
    String? directory,
    int keepCount = 0,
    bool manual = false,
  }) async {
    try {
      await _storage.save(_data);
      final storage = _storage;
      final directoryPath = directory ?? _data.settings.localBackupDirectory;
      final path = storage is AppStorage
          ? await storage.createLocalBackup(
              _data,
              directoryPath: directoryPath,
              keepCount: keepCount,
            )
          : await AppStorage().createLocalBackup(
              _data,
              directoryPath: directoryPath,
              keepCount: keepCount,
            );
      _lastLocalBackupAt = DateTime.now();
      _lastLocalBackupPath = path;
      _lastLocalBackupError = null;
      if (manual) {
        _message = 'LOCAL_BACKUP_SUCCESS';
      }
    } on Object {
      _lastLocalBackupError = '本地同步失败，请检查目录是否可写';
      if (manual) {
        _message = _lastLocalBackupError;
      }
    } finally {
      _notify();
    }
  }

  Future<void> syncBeforeBackground() async {
    if (!_data.settings.backupAutoSyncEnabled) {
      return;
    }
    await _syncNow(silent: true, force: true);
  }

  Future<void> _syncNow({required bool silent, required bool force}) async {
    if (!_data.settings.webDav.isConfigured || _syncing) {
      return;
    }
    if (!force && !_data.settings.backupAutoSyncEnabled) {
      return;
    }
    final attemptedAt = DateTime.now();
    _lastAutoSyncAttemptAt = attemptedAt;
    _syncing = true;
    _lastSyncError = null;
    _notify();
    try {
      final merged = await _webDavService.sync(_data.settings.webDav, _data);
      _data = merged;
      await _saveData(_data);
      _lastSyncAt = attemptedAt;
      _lastSyncError = null;
    } on WebDavException catch (error) {
      _lastSyncError = error.message;
      if (!silent) {
        _message = error.message;
      }
    } on Object {
      _lastSyncError = 'WebDAV 同步失败';
      if (!silent) {
        _message = 'WebDAV 同步失败';
      }
    } finally {
      _syncing = false;
      _restartTicker();
      _restartAutoSyncTimer();
      _notify();
    }
  }

  Future<void> _autoSyncIfDue({bool force = false}) async {
    final settings = _data.settings;
    if (!settings.backupAutoSyncEnabled || !settings.webDav.isConfigured) {
      return;
    }
    final now = DateTime.now();
    final interval = Duration(minutes: settings.backupAutoSyncIntervalMinutes);
    final lastAttempt = _lastAutoSyncAttemptAt;
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt) < interval) {
      return;
    }
    await _syncNow(silent: true, force: false);
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
    _restartAutoSyncTimer();
    _restartLocalBackupTimer();
    _notify();
    await _saveData(_data);
  }

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_data.timer.phase == TimerPhase.running) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _restartAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    final settings = _data.settings;
    if (!settings.backupAutoSyncEnabled || !settings.webDav.isConfigured) {
      return;
    }
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: settings.backupAutoSyncIntervalMinutes),
      (_) => unawaited(_autoSyncIfDue(force: true)),
    );
  }

  void _restartLocalBackupTimer() {
    _localBackupTimer?.cancel();
    _localBackupTimer = null;
    final settings = _data.settings;
    if (!settings.localBackupAutoEnabled) {
      return;
    }
    _localBackupTimer = Timer.periodic(
      Duration(minutes: settings.localBackupAutoIntervalMinutes),
      (_) => unawaited(
        _runLocalBackup(
          directory: settings.localBackupDirectory,
          keepCount: settings.localBackupKeepCount,
        ),
      ),
    );
  }

  void _setCompletionMessage(TimerMode? mode) {
    if (mode == null) {
      return;
    }
    final timer = _data.timer;
    final runFinished =
        timer.mode == TimerMode.focus && timer.phase == TimerPhase.idle;
    if (runFinished) {
      _message = '已达到循环次数，计时已停止';
    } else {
      _message = mode == TimerMode.focus ? '专注完成，进入休息' : '休息结束，回到专注';
    }
    unawaited(_completionFeedback.notify(mode, _data.settings));
  }

  Future<void> _saveCurrentSilently() async {
    await _saveData(_data);
  }

  Future<void> _saveData(TomatoData snapshot) async {
    final writeFuture = _saveQueue.then((_) => _storage.save(snapshot));
    _saveQueue = writeFuture.then<void>((_) {}, onError: (error, stack) {});
    try {
      await writeFuture;
      _saveErrorNotified = false;
    } on Object {
      if (_saveErrorNotified) {
        return;
      }
      _saveErrorNotified = true;
      _message = '本地数据保存失败';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Object? _decodeJsonObject(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('empty');
    }
    return jsonDecode(text);
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _autoSyncTimer?.cancel();
    _localBackupTimer?.cancel();
    super.dispose();
  }
}
