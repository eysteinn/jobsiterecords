import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> canUploadBlobs({required bool wifiOnly}) async {
  if (!wifiOnly) return true;
  final results = await Connectivity().checkConnectivity();
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
}
