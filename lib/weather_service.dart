import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CityResult {
  const CityResult({
    required this.id,
    required this.name,
    required this.adm2,
    required this.adm1,
  });

  final String id;
  final String name;
  final String adm2;
  final String adm1;

  String get fullName {
    final parts = <String>[];
    if (adm2.isNotEmpty && adm2 != name) parts.add(adm2);
    parts.add(name);
    return parts.join(' · ');
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.place,
    required this.temperatureC,
    required this.condition,
  });

  final String place;
  final int temperatureC;
  final String condition;

  String get label {
    final area = place.trim().isEmpty ? '本地' : place.trim();
    return '$area $temperatureC° $condition';
  }
}

class WeatherService {
  const WeatherService();

  static WeatherSnapshot? _cached;
  static String? _cachedLocationId;
  static Future<WeatherSnapshot?>? _pending;

  String? _resolveKey(String? apiKey) {
    final key = (apiKey ?? '').trim();
    return key.isNotEmpty ? key : null;
  }

  Future<List<CityResult>> search(String query, {String? apiKey}) async {
    final key = _resolveKey(apiKey);
    if (key == null || query.trim().length < 2) return [];
    try {
      final uri = Uri.https('geoapi.qweather.com', '/v2/city/lookup', {
        'location': query.trim(),
        'key': key,
        'number': '6',
      });
      final response = await _getJson(uri);
      final location = response?['location'];
      if (location is! List) return [];
      final results = <CityResult>[];
      for (final item in location) {
        if (item is! Map<String, Object?>) continue;
        final id = item['id'] as String? ?? '';
        final name = item['name'] as String? ?? '';
        final adm2 = item['adm2'] as String? ?? '';
        final adm1 = item['adm1'] as String? ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        results.add(CityResult(id: id, name: name, adm2: adm2, adm1: adm1));
      }
      return results;
    } on Object {
      return [];
    }
  }

  Future<WeatherSnapshot?> fetch({String? locationId, String? apiKey}) async {
    final key = _resolveKey(apiKey);
    if (key == null) return null;
    final effectiveId = locationId?.trim();
    if (effectiveId != null && effectiveId.isNotEmpty) {
      if (effectiveId == _cachedLocationId && _cached != null) {
        return _cached;
      }
      _cachedLocationId = effectiveId;
      _pending = _fetchWeather(effectiveId, key).then((value) {
        _cached = value;
        _pending = null;
        return value;
      });
      return _pending;
    }
    if (_cached != null) {
      return _cached;
    }
    return _pending ??= _fetchAutoLocation(key).then((value) {
      _cached = value;
      _pending = null;
      return value;
    });
  }

  Future<WeatherSnapshot?> _fetchAutoLocation(String key) async {
    final locationId = await _autoLocationId(key);
    if (locationId == null) return null;
    _cachedLocationId = locationId;
    return _fetchWeather(locationId, key);
  }

  Future<String?> _autoLocationId(String key) async {
    try {
      final uri = Uri.https('geoapi.qweather.com', '/v2/city/lookup', {
        'location': 'auto_ip',
        'key': key,
        'number': '1',
      });
      final response = await _getJson(uri);
      final location = response?['location'];
      if (location is! List || location.isEmpty) return null;
      final first = location[0];
      if (first is! Map<String, Object?>) return null;
      final id = first['id'] as String?;
      if (id == null || id.isEmpty) return null;
      final name = first['name'] as String? ?? '';
      final adm2 = first['adm2'] as String? ?? '';
      final parts = <String>[];
      if (adm2.isNotEmpty && adm2 != name) parts.add(adm2);
      parts.add(name);
      _cached = WeatherSnapshot(
        place: parts.join('·'),
        temperatureC: 0,
        condition: '--',
      );
      return id;
    } on Object {
      return null;
    }
  }

  Future<WeatherSnapshot?> _fetchWeather(String locationId, String key) async {
    try {
      final uri = Uri.https('devapi.qweather.com', '/v7/weather/now', {
        'location': locationId,
        'key': key,
      });
      final response = await _getJson(uri);
      final now = response?['now'];
      if (now is! Map<String, Object?>) return null;
      final tempStr = now['temp'] as String?;
      final text = now['text'] as String? ?? '';
      if (tempStr == null) return null;
      final temperatureC = int.tryParse(tempStr) ?? 0;
      final place = _cached?.place ?? '';
      return WeatherSnapshot(
        place: place,
        temperatureC: temperatureC,
        condition: text,
      );
    } on Object {
      return null;
    }
  }

  Future<Map<String, Object?>?> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
