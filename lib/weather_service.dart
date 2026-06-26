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

  Future<WeatherSnapshot?> fetch({String? city}) {
    final effectiveCity = city?.trim();
    if (effectiveCity != null && effectiveCity.isNotEmpty) {
      // ponytail: manual city overrides IP geolocation, bypass cache
      _pending = _fetchForCity(effectiveCity);
      return _pending!;
    }
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

  Future<WeatherSnapshot?> _fetchForCity(String city) async {
    final coords = await _geocode(city);
    if (coords == null) return null;
    final weather = await _fetchWeather(coords.latitude, coords.longitude);
    if (weather == null) return null;
    final result = WeatherSnapshot(
      place: city,
      temperatureC: weather.temperatureC,
      condition: weather.condition,
    );
    _cached = result;
    _pending = null;
    return result;
  }

  Future<_WeatherLocation?> _geocode(String city) async {
    final client = HttpClient();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': city,
        'format': 'json',
        'limit': '1',
        'accept-language': 'zh',
      });
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final httpResponse = await request.close().timeout(const Duration(seconds: 4));
      final raw = await httpResponse.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return null;
      final place = decoded[0];
      if (place is! Map<String, Object?>) return null;
      final lat = _doubleOrNull(place['lat']);
      final lon = _doubleOrNull(place['lon']);
      if (lat == null || lon == null) return null;
      return _WeatherLocation(latitude: lat, longitude: lon, city: city);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<WeatherSnapshot?> _fetchFresh() async {
    final location = await _fetchLocation();
    if (location == null) {
      return null;
    }
    final district = await _reverseGeocode(location.latitude, location.longitude);
    final place = district ?? location.city;
    final weather = await _fetchWeather(location.latitude, location.longitude);
    if (weather == null) return null;
    return WeatherSnapshot(
      place: place,
      temperatureC: weather.temperatureC,
      condition: weather.condition,
    );
  }

  Future<_WeatherLocation?> _fetchLocation() async {
    // ponytail: two free IP geolocation services for reliability
    var response = await _getJson(Uri.parse('https://ipapi.co/json/'));
    response ??= await _getJson(Uri.parse('http://ip-api.com/json/?fields=status,lat,lon,city'));
    if (response == null) {
      return null;
    }
    final latitude = _doubleOrNull(response['latitude'] ?? response['lat']);
    final longitude = _doubleOrNull(response['longitude'] ?? response['lon']);
    if (latitude == null || longitude == null) {
      return null;
    }
    final city = (response['city'] as String?) ?? '';
    final region = (response['region'] as String?) ?? (response['regionName'] as String?) ?? '';
    // Build best available place name from API data
    final apiPlace = region.isNotEmpty && region != city ? '$region$city' : city;
    return _WeatherLocation(
      latitude: latitude,
      longitude: longitude,
      city: apiPlace,
    );
  }

  // ponytail: Nominatim reverse geocode for district-level name
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toStringAsFixed(6),
        'lon': lon.toStringAsFixed(6),
        'format': 'json',
        'zoom': '14',
        'accept-language': 'zh',
      });
      final response = await _getJson(uri);
      final address = response?['address'];
      if (address is! Map<String, Object?>) return null;
      // Prefer district/county/suburb level for Chinese addresses
      return (address['city_district'] as String?) ??
          (address['county'] as String?) ??
          (address['suburb'] as String?) ??
          (address['city'] as String?);
    } on Object {
      return null;
    }
  }

  Future<WeatherSnapshot?> _fetchWeather(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
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
      place: '',
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
