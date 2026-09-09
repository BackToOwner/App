/// Where the Flutter app finds its backend (the Node API in `backend/` of this repo).
///
/// `localhost` on a device means the *device itself*, not your development machine, so the
/// default targets the Android emulator's host alias. Override without editing code:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:5001/api/v1
///
/// | Running on        | Value                            |
/// |-------------------|----------------------------------|
/// | Android emulator  | http://10.0.2.2:5001/api/v1      |
/// | iOS simulator     | http://localhost:5001/api/v1     |
/// | Physical device   | `http://<machine-LAN-IP>:5001/api/v1` |
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5001/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
