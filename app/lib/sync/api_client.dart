import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiClient {
  ApiClient({http.Client? client, Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 15),
        _client = client ?? _defaultClient();

  final http.Client _client;
  final Duration _timeout;

  static http.Client _defaultClient() {
    final io = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    return IOClient(io);
  }

  String get baseUrl =>
      dotenv.env['API_BASE_URL']?.trim().isNotEmpty == true
          ? dotenv.env['API_BASE_URL']!.trim()
          : 'http://10.0.2.2:8080';

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    String? accessToken,
  }) {
    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(headers, accessToken),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    String? accessToken,
  }) {
    return _client
        .get(
          Uri.parse('$baseUrl$path'),
          headers: _headers(headers, accessToken),
        )
        .timeout(_timeout);
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    String? accessToken,
  }) {
    return _client
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers(headers, accessToken),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> putBytes(
    Uri url, {
    required List<int> body,
    required String contentType,
    Duration? timeout,
  }) {
    return _client
        .put(
          url,
          headers: {'Content-Type': contentType},
          body: body,
        )
        .timeout(timeout ?? const Duration(minutes: 10));
  }

  Future<http.Response> getRaw(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return _client.get(url, headers: headers).timeout(timeout ?? const Duration(minutes: 5));
  }

  Future<List<int>> downloadMedia(String mediaId, {required String accessToken}) async {
    final first = await get(
      '/api/v1/media-files/$mediaId/download',
      accessToken: accessToken,
    );
    if (first.statusCode >= 300 && first.statusCode < 400) {
      final location = first.headers['location'];
      if (location == null) {
        throw ApiException('Missing download redirect', statusCode: first.statusCode);
      }
      final bytes = await getRaw(Uri.parse(location));
      if (bytes.statusCode >= 400) {
        throw ApiException('Download failed', statusCode: bytes.statusCode);
      }
      return bytes.bodyBytes;
    }
    if (first.statusCode >= 400) {
      throw ApiException('Download failed', statusCode: first.statusCode);
    }
    return first.bodyBytes;
  }

  Map<String, String> _headers(Map<String, String>? extra, String? accessToken) {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      ...?extra,
    };
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

Map<String, dynamic> decodeJsonMap(http.Response res) {
  final data = jsonDecode(res.body);
  if (data is! Map<String, dynamic>) {
    throw ApiException('Unexpected response', statusCode: res.statusCode);
  }
  if (res.statusCode >= 400) {
    final msg = data['message']?.toString() ?? data['error']?.toString() ?? 'Request failed';
    throw ApiException(msg, statusCode: res.statusCode);
  }
  return data;
}
