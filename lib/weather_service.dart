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

enum WeatherSource { qweather, openMeteo }

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

  WeatherSource effectiveSource(String? apiKey) {
    final key = (apiKey ?? '').trim();
    return key.isNotEmpty ? WeatherSource.qweather : WeatherSource.openMeteo;
  }

  Future<List<CityResult>> search(String query, {String? apiKey}) async {
    final source = effectiveSource(apiKey);
    if (source == WeatherSource.qweather) {
      return _searchQWeather(query, apiKey!);
    }
    return _searchOpenMeteo(query);
  }

  Future<List<CityResult>> _searchQWeather(String query, String apiKey) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.https('geoapi.qweather.com', '/v2/city/lookup', {
        'location': query.trim(),
        'key': apiKey,
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

  Future<List<CityResult>> _searchOpenMeteo(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query.trim(),
        'count': '6',
        'language': 'zh',
      });
      final response = await _getJson(uri);
      final results = response?['results'];
      if (results is! List) return [];
      final cities = <CityResult>[];
      for (final item in results) {
        if (item is! Map<String, Object?>) continue;
        final name = item['name'] as String? ?? '';
        final admin1 = item['admin1'] as String? ?? '';
        final country = item['country'] as String? ?? '';
        final lat = item['latitude'] as num?;
        final lon = item['longitude'] as num?;
        if (lat == null || lon == null || name.isEmpty) continue;
        final locId = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        cities.add(CityResult(
          id: locId,
          name: name,
          adm2: admin1,
          adm1: country,
        ));
      }
      return cities;
    } on Object {
      return [];
    }
  }

  Future<WeatherSnapshot?> fetch({
    String? locationId,
    String? apiKey,
  }) async {
    final key = (apiKey ?? '').trim();
    final source = effectiveSource(apiKey);
    final effectiveId = locationId?.trim();

    if (effectiveId != null && effectiveId.isNotEmpty) {
      if (effectiveId == _cachedLocationId && _cached != null) {
        return _cached;
      }
      _cachedLocationId = effectiveId;
      final result = source == WeatherSource.qweather
          ? await _fetchQWeather(effectiveId, key)
          : await _fetchOpenMeteo(effectiveId);
      _cached = result;
      _pending = null;
      return result;
    }

    if (_cached != null) return _cached;
    return _pending ??= _autoFetch(source, key);
  }

  Future<WeatherSnapshot?> _autoFetch(WeatherSource source, String key) async {
    if (source == WeatherSource.qweather) {
      return _autoFetchQWeather(key);
    }
    return _autoFetchOpenMeteo();
  }

  Future<WeatherSnapshot?> _autoFetchQWeather(String key) async {
    final locationId = await _qweatherAutoLocation(key);
    if (locationId == null) return null;
    _cachedLocationId = locationId;
    return _fetchQWeather(locationId, key);
  }

  Future<String?> _qweatherAutoLocation(String key) async {
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

  Future<WeatherSnapshot?> _fetchQWeather(String locationId, String key) async {
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

  Future<WeatherSnapshot?> _autoFetchOpenMeteo() async {
    try {
      final uri = Uri.https('ipapi.co', '/json/');
      final resp = await _getJson(uri);
      final lat = _doubleOrNull(resp?['latitude']);
      final lon = _doubleOrNull(resp?['longitude']);
      final city = (resp?['city'] as String?) ?? '';
      if (lat == null || lon == null) return _fetchOpenMeteo('');
      final locId = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      _cachedLocationId = locId;
      _cached = WeatherSnapshot(
        place: city,
        temperatureC: 0,
        condition: '--',
      );
      return _fetchOpenMeteo(locId);
    } on Object {
      return _fetchOpenMeteo('');
    }
  }

  Future<WeatherSnapshot?> _fetchOpenMeteo(String locationId) async {
    try {
      final parts = locationId.isNotEmpty
          ? locationId.split(',').take(2).toList()
          : <String>[];
      final params = <String, String>{
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      };
      if (parts.length == 2) {
        params['latitude'] = parts[0];
        params['longitude'] = parts[1];
      }
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', params);
      final response = await _getJson(uri);
      final current = response?['current'];
      if (current is! Map<String, Object?>) return null;
      final temperature = _doubleOrNull(current['temperature_2m']);
      final code = _intOrNull(current['weather_code']);
      if (temperature == null || code == null) return null;
      final place = _cached?.place ?? '';
      return WeatherSnapshot(
        place: place,
        temperatureC: temperature.round(),
        condition: _omWeatherLabel(code),
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

double? _doubleOrNull(Object? value) {
  return switch (value) {
    int item => item.toDouble(),
    double item => item,
    String item => double.tryParse(item),
    _ => null,
  };
}

int? _intOrNull(Object? value) {
  return switch (value) {
    int item => item,
    double item => item.round(),
    String item => int.tryParse(item),
    _ => null,
  };
}

String _omWeatherLabel(int code) {
  if (code == 0) return '晴';
  if (code == 1 || code == 2) return '少云';
  if (code == 3) return '多云';
  if (code == 45 || code == 48) return '雾';
  if (code >= 51 && code <= 57) return '毛毛雨';
  if (code >= 61 && code <= 67) return '雨';
  if (code >= 71 && code <= 77) return '雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 85 && code <= 86) return '阵雪';
  if (code >= 95) return '雷雨';
  return '天气';
}
