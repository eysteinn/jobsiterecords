import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

const _noConnection =
    'No internet connection. Check Wi‑Fi or mobile data and try again.';

enum SyncErrorKind { transient, permanent, auth }

/// Classifies sync failures for retry vs quarantine behavior.
SyncErrorKind classifySyncError(Object error) {
  if (error is ApiException) {
    final code = error.statusCode;
    if (code == 401) return SyncErrorKind.auth;
    if (code != null) {
      if (code >= 500 || code == 408 || code == 425 || code == 429) {
        return SyncErrorKind.transient;
      }
      if (code == 400 || code == 409 || code == 413 || code == 422) {
        return SyncErrorKind.permanent;
      }
      if (code >= 400 && code < 500) return SyncErrorKind.permanent;
    }
    return SyncErrorKind.transient;
  }

  if (_isNetworkError(error) || _looksLikeNetworkError(error.toString())) {
    return SyncErrorKind.transient;
  }

  return SyncErrorKind.transient;
}

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
