import 'dart:convert';
import 'dart:io';

import 'models.dart';

class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return '$message$code';
  }
}

class WebDavService {
  Future<void> upload(WebDavSettings settings, TomatoData data) async {
    _checkConfigured(settings);
    await _ensureCollections(settings);
    final response = await _send(
      settings,
      'PUT',
      _remoteUri(settings),
      body: utf8.encode(data.toPrettyJson()),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
    );
    if (!_ok(response.statusCode, const {200, 201, 204})) {
      throw WebDavException('WebDAV 上传失败', statusCode: response.statusCode);
    }
  }

  Future<TomatoData> download(WebDavSettings settings) async {
    _checkConfigured(settings);
    final response = await _send(settings, 'GET', _remoteUri(settings));
    if (response.statusCode == 404) {
      throw const WebDavException('远端备份文件不存在', statusCode: 404);
    }
    if (!_ok(response.statusCode, const {200})) {
      throw WebDavException('WebDAV 下载失败', statusCode: response.statusCode);
    }
    try {
      return TomatoData.fromJson(jsonDecode(response.body));
    } on Object {
      throw const WebDavException('远端备份文件格式无效');
    }
  }

  Future<TomatoData> sync(WebDavSettings settings, TomatoData local) async {
    _checkConfigured(settings);
    var merged = local;
    try {
      final remote = await download(settings);
      merged = local.mergeWith(remote);
    } on WebDavException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }
    await upload(settings, merged);
    return merged;
  }

  Future<void> _ensureCollections(WebDavSettings settings) async {
    final collections = _collectionUris(settings);
    for (final uri in collections) {
      final response = await _send(settings, 'MKCOL', uri);
      if (!_ok(response.statusCode, const {200, 201, 204, 405})) {
        throw WebDavException('WebDAV 目录创建失败', statusCode: response.statusCode);
      }
    }
  }

  Future<_WebDavResponse> _send(
    WebDavSettings settings,
    String method,
    Uri uri, {
    List<int>? body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'TomatoClock/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, */*');
      final auth = _basicAuth(settings);
      if (auth != null) {
        request.headers.set(HttpHeaders.authorizationHeader, auth);
      }
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return _WebDavResponse(response.statusCode, text);
    } on WebDavException {
      rethrow;
    } on SocketException catch (error) {
      throw WebDavException('WebDAV 网络连接失败: ${error.message}');
    } on HandshakeException catch (error) {
      throw WebDavException('WebDAV TLS 握手失败: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  List<Uri> _collectionUris(WebDavSettings settings) {
    final base = Uri.parse(settings.endpoint.trim());
    final baseSegments = base.pathSegments.where((item) => item.isNotEmpty);
    final remoteSegments = _remoteSegments(settings.remotePath);
    if (remoteSegments.length <= 1) {
      return const [];
    }
    final collections = <Uri>[];
    for (var index = 1; index < remoteSegments.length; index++) {
      collections.add(
        base.replace(
          pathSegments: [...baseSegments, ...remoteSegments.take(index)],
        ),
      );
    }
    return collections;
  }

  Uri _remoteUri(WebDavSettings settings) {
    final base = Uri.parse(settings.endpoint.trim());
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((item) => item.isNotEmpty),
        ..._remoteSegments(settings.remotePath),
      ],
    );
  }

  List<String> _remoteSegments(String remotePath) {
    final cleaned = remotePath.trim().isEmpty
        ? 'tomato_clock/backup.json'
        : remotePath;
    return cleaned.split('/').where((item) => item.trim().isNotEmpty).toList();
  }

  String? _basicAuth(WebDavSettings settings) {
    if (settings.username.isEmpty && settings.password.isEmpty) {
      return null;
    }
    final token = base64Encode(
      utf8.encode('${settings.username}:${settings.password}'),
    );
    return 'Basic $token';
  }

  void _checkConfigured(WebDavSettings settings) {
    if (!settings.isConfigured) {
      throw const WebDavException('请先填写 WebDAV 地址');
    }
    final uri = Uri.tryParse(settings.endpoint.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const WebDavException('WebDAV 地址格式无效');
    }
  }

  bool _ok(int statusCode, Set<int> expected) {
    return expected.contains(statusCode);
  }
}

class _WebDavResponse {
  const _WebDavResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
