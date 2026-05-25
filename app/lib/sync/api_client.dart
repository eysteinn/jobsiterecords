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
