import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static Future<WeatherSnapshot?>? _pending;

  Future<WeatherSnapshot?> fetch() {
    final cached = _cached;
    if (cached != null) {
      return Future.value(cached);
    }
    return _pending ??= _fetchFresh().then((value) {
      _cached = value;
      _pending = null;
      return value;
    });
  }

  Future<WeatherSnapshot?> _fetchFresh() async {
    final location = await _fetchLocation();
    if (location == null) {
      return null;
    }
    final weather = await _fetchWeather(location);
    return weather;
  }

  Future<_WeatherLocation?> _fetchLocation() async {
    final response = await _getJson(Uri.parse('https://ipapi.co/json/'));
    if (response == null) {
      return null;
    }
    final latitude = _doubleOrNull(response['latitude']);
    final longitude = _doubleOrNull(response['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    final city = response['city'] as String? ?? '';
    return _WeatherLocation(
      latitude: latitude,
      longitude: longitude,
      city: city,
    );
  }

  Future<WeatherSnapshot?> _fetchWeather(_WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toStringAsFixed(4),
      'longitude': location.longitude.toStringAsFixed(4),
      'current': 'temperature_2m,weather_code',
      'timezone': 'auto',
    });
    final response = await _getJson(uri);
    final current = response?['current'];
    if (current is! Map<String, Object?>) {
      return null;
    }
    final temperature = _doubleOrNull(current['temperature_2m']);
    final code = _intOrNull(current['weather_code']);
    if (temperature == null || code == null) {
      return null;
    }
    return WeatherSnapshot(
      place: location.city,
      temperatureC: temperature.round(),
      condition: _weatherLabel(code),
    );
  }

  Future<Map<String, Object?>?> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 4));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 4),
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

class _WeatherLocation {
  const _WeatherLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
  });

  final double latitude;
  final double longitude;
  final String city;
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

String _weatherLabel(int code) {
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
