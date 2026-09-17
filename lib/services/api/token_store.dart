import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access and refresh tokens in the platform keystore.
///
/// Deliberately not SharedPreferences: a refresh token is a 30-day credential, and on a rooted or
/// jailbroken device plain preferences are readable by other apps.
class TokenStore {
  static const _accessKey = 'bto_access_token';
  static const _refreshKey = 'bto_refresh_token';

  final FlutterSecureStorage _storage;

  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // Cached so the request interceptor does not hit the keystore on every call.
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
    } catch (_) {
      // A keystore that cannot be read (wiped keys after a reinstall, for instance) means the
      // user is simply signed out — never a crash on startup.
      _accessToken = null;
      _refreshToken = null;
    }
    _loaded = true;
  }

  Future<String?> get accessToken async {
    await _load();
    return _accessToken;
  }

  Future<String?> get refreshToken async {
    await _load();
    return _refreshToken;
  }

  Future<bool> get hasSession async => (await refreshToken) != null;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
