import 'package:flutter/foundation.dart';

/// Where the Flutter app finds its backend (the Node API in `backend/` of this repo).
///
/// `localhost` on a device means the *device itself*, not your development machine, and
/// `10.0.2.2` is an alias that only exists inside the Android emulator — pointing either at the
/// wrong target gets the packets silently dropped, which surfaces in the app as
/// "The server took too long to respond" once the connect timeout expires. So the default is
/// chosen per platform rather than fixed.
///
/// | Running on        | Default                          |
/// |-------------------|----------------------------------|
/// | Android emulator  | http://10.0.2.2:5001/api/v1      |
/// | iOS simulator     | http://localhost:5001/api/v1     |
/// | Web / desktop     | http://localhost:5001/api/v1     |
///
/// A *physical* device is the one case that cannot be detected — it reads as Android or iOS but
/// needs this machine's LAN IP, so pass it explicitly:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:5001/api/v1
class ApiConfig {
  const ApiConfig._();

  static const int port = 5001;

  /// Empty unless `--dart-define=API_BASE_URL=...` was given; always wins when set.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'http://$_host:$port/api/v1';
  }

  /// The emulator reaches the host machine through a NAT alias; everything else that runs a
  /// Flutter debug build shares a loopback with the server.
  static String get _host {
    if (kIsWeb) return 'localhost';
    return defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
