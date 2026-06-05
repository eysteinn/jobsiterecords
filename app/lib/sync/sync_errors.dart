import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

const _noConnection =
    'No internet connection. Check Wi‑Fi or mobile data and try again.';

/// Maps sync failures to short, user-facing text.
String userFacingSyncError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Session expired. Sign in again.';
    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'Server unavailable. Try again later.';
    }
    return error.message;
  }

  if (_isNetworkError(error) || _looksLikeNetworkError(error.toString())) {
    return _noConnection;
  }

  return 'Sync failed. Try again later.';
}

bool _isNetworkError(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is HttpException ||
      error is http.ClientException;
}

bool _looksLikeNetworkError(String text) {
  final lower = text.toLowerCase();
  const patterns = [
    'clientexception',
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection timed out',
    'connection reset',
    'no route to host',
    'software caused connection abort',
    'operation timed out',
    'timed out',
    'network error',
    'errno =',
  ];
  return patterns.any(lower.contains);
}
