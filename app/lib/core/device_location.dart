import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart';

LatLng? _cachedOrigin;
Future<LatLng?>? _inFlight;

/// Best-effort device location for Places autocomplete bias (not stored or synced).
Future<LatLng?> deviceLocationForPlaces() {
  _inFlight ??= _loadLocation();
  return _inFlight!;
}

Future<LatLng?> _loadLocation() async {
  try {
    if (_cachedOrigin != null) return _cachedOrigin;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _cachedOrigin = LatLng(lat: last.latitude, lng: last.longitude);
      return _cachedOrigin;
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    _cachedOrigin = LatLng(lat: current.latitude, lng: current.longitude);
    return _cachedOrigin;
  } catch (_) {
    return null;
  } finally {
    _inFlight = null;
  }
}

/// Soft bias box (~50 km) around [origin]; does not restrict other countries.
LatLngBounds locationBiasAround(LatLng origin, {double radiusDegrees = 0.45}) {
  return LatLngBounds(
    southwest: LatLng(lat: origin.lat - radiusDegrees, lng: origin.lng - radiusDegrees),
    northeast: LatLng(lat: origin.lat + radiusDegrees, lng: origin.lng + radiusDegrees),
  );
}
