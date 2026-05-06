import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HitokotoQuote {
  const HitokotoQuote({required this.text, this.source});

  final String text;
  final String? source;
}

class HitokotoService {
  const HitokotoService();

  static final Uri endpoint = Uri.parse(
    'https://v1.hitokoto.cn/?encode=json&max_length=28',
  );

  Future<HitokotoQuote?> fetch({
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(endpoint).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Gan/0.1 TomatoClock');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      return parseQuote(body);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static HitokotoQuote? parseQuote(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return quoteFromJson(decoded);
    } on Object {
      return null;
    }
  }

  static HitokotoQuote? quoteFromJson(Map<String, Object?> json) {
    final rawText = json['hitokoto'];
    if (rawText is! String) {
      return null;
    }
    final text = _cleanText(rawText);
    if (text == null || text.length > 40) {
      return null;
    }
    final source = _cleanText(json['from_who']) ?? _cleanText(json['from']);
    return HitokotoQuote(text: text, source: source);
  }

  static String? _cleanText(Object? value) {
    if (value is! String) {
      return null;
    }
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }
}
