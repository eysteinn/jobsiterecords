# Patched `flutter_google_places_sdk`

Vendored from pub `0.4.3` with two fixes:

1. Removes `useNewApi` so the client matches `flutter_google_places_sdk_platform_interface` 0.4.0.
2. Depends on `flutter_google_places_sdk_android` 0.3.0 (fixes Kotlin compile errors against Places SDK 5.1.1).

Remove this package when upstream publishes a compatible release.
