import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract class TomatoStore {
  Future<TomatoData> load();

  Future<void> save(TomatoData data);
}

class AppStorage implements TomatoStore {
  AppStorage({String? dataDirectory}) : _dataDirectory = dataDirectory;

  final String? _dataDirectory;
  File? _dataFile;

  @override
  Future<TomatoData> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return TomatoData.initial();
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      return TomatoData.fromJson(decoded);
    } on Object {
      return TomatoData.initial();
    }
  }

  @override
  Future<void> save(TomatoData data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data.toPrettyJson(), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  Future<String> createLocalBackup(TomatoData data, {DateTime? at}) async {
    final directory = await _resolveDataDirectory();
    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}local_backups',
    );
    await backupDirectory.create(recursive: true);
    final createdAt = at ?? DateTime.now();
    final basePath =
        '${backupDirectory.path}${Platform.pathSeparator}'
        'gan_backup_${_timestamp(createdAt)}';
    var file = File('$basePath.json');
    var suffix = 1;
    while (await file.exists()) {
      file = File('${basePath}_$suffix.json');
      suffix += 1;
    }
    await file.writeAsString(data.toPrettyJson(), flush: true);
    return file.path;
  }

  Future<File> _file() async {
    final cached = _dataFile;
    if (cached != null) {
      return cached;
    }
    final directory = await _resolveDataDirectory();
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}tomato_data.json',
    );
    _dataFile = file;
    return file;
  }

  Future<Directory> _resolveDataDirectory() async {
    final configured = _dataDirectory;
    if (configured != null && configured.trim().isNotEmpty) {
      return Directory(configured);
    }

    final home =
        Platform.environment['TOMATO_CLOCK_HOME'] ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    final candidates = <Directory>[
      if (home != null && home.trim().isNotEmpty)
        Directory('${home.trim()}${Platform.pathSeparator}.tomato_clock'),
      Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}tomato_clock',
      ),
      Directory(
        '${Directory.current.path}${Platform.pathSeparator}.tomato_clock',
      ),
    ];

    for (final directory in candidates) {
      if (await _canUseDirectory(directory)) {
        return directory;
      }
    }
    return Directory.systemTemp.createTemp('tomato_clock_');
  }

  Future<bool> _canUseDirectory(Directory directory) async {
    try {
      await directory.create(recursive: true);
      final probe = File(
        '${directory.path}${Platform.pathSeparator}.write_test',
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }
}

String _timestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}'
      '${local.second.toString().padLeft(2, '0')}';
}
