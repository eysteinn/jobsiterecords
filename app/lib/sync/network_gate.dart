import 'package:connectivity_plus/connectivity_plus.dart';

bool _isOnline(List<ConnectivityResult> results) {
  return results.any((r) => r != ConnectivityResult.none);
}

Future<bool> isDeviceOnline() async {
  final results = await Connectivity().checkConnectivity();
  return _isOnline(results);
}

Future<bool> canUploadBlobs({required bool wifiOnly}) async {
  if (!wifiOnly) return true;
  final results = await Connectivity().checkConnectivity();
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
}
