import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Web OAuth client ID used as [GoogleSignIn.serverClientId] on Android.
String? googleWebClientId() {
  final web = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
  if (web != null && web.isNotEmpty) return web;

  final raw = dotenv.env['GOOGLE_CLIENT_ID']?.trim();
  if (raw == null || raw.isEmpty) return null;
  final first = raw.split(',').first.trim();
  return first.isEmpty ? null : first;
}
