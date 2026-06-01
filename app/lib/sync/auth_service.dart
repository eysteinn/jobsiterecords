import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.workspaces,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> workspaces;
}

class AuthService {
  AuthService(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<AuthSession?> loadSession() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    try {
      return await _me(access, refresh);
    } catch (_) {
      try {
        return await refreshSession(refresh);
      } catch (_) {
        return null;
      }
    }
  }

  Future<AuthSession> login(String email, String password) async {
    final res = await _api.post('/api/v1/auth/login', body: {
      'email': email,
      'password': password,
    });
    final data = decodeJsonMap(res);
    return _saveTokens(data);
  }

  Future<AuthSession> signup(String email, String password, {String? name}) async {
    final res = await _api.post('/api/v1/auth/signup', body: {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    final data = decodeJsonMap(res);
    return _saveTokens(data);
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    final res = await _api.post('/api/v1/auth/refresh', body: {
      'refresh_token': refreshToken,
    });
    final data = decodeJsonMap(res);
    return _saveTokens(data);
  }

  Future<void> logout(String accessToken) async {
    try {
      await _api.post('/api/v1/auth/logout', accessToken: accessToken);
    } catch (_) {}
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<AuthSession> _saveTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    return _me(access, refresh);
  }

  Future<AuthSession> _me(String access, String refresh) async {
    final res = await _api.get('/api/v1/auth/me', accessToken: access);
    final data = decodeJsonMap(res);
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: Map<String, dynamic>.from(data['user'] as Map),
      workspaces: (data['workspaces'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

String encodeJson(Object value) => jsonEncode(value);
