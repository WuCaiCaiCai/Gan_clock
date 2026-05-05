import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'native_bridge.dart';

class AppStorage {
  AppStorage(this._bridge);

  final NativeBridge _bridge;
  File? _dataFile;

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

  Future<File> _file() async {
    final cached = _dataFile;
    if (cached != null) {
      return cached;
    }
    final directory = Directory(await _bridge.appDataDirectory());
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}tomato_data.json');
    _dataFile = file;
    return file;
  }
}
