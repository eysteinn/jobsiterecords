import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Maps / Places API key from `app/.env` or `--dart-define=GOOGLE_MAPS=...`.
String? get googleMapsApiKey {
  const fromDefine = String.fromEnvironment('GOOGLE_MAPS');
  if (fromDefine.isNotEmpty) return fromDefine;

  final key = dotenv.env['GOOGLE_MAPS']?.trim();
  if (key == null || key.isEmpty) return null;
  return key;
}

bool get hasGoogleMapsApiKey => googleMapsApiKey != null;
