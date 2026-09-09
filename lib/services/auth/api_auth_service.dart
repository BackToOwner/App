import '../../models/app_user.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'auth_service_interface.dart';

/// Real authentication against the backend in `backend/`.
///
/// Replaces the previous MockAuthService, which returned true for any input — including an empty
/// password — and so let anyone through.
class ApiAuthService implements IAuthService {
  final ApiClient _api;

  ApiAuthService(this._api);

  AppUser? _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  String? get currentUserEmail => _currentUser?.email;

  /// Stores the tokens from an auth response and returns the user it carries.
  Future<AppUser> _consumeAuthPayload(Map<String, dynamic> data) async {
    await _api.tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    // Checked here as well as on the server so an obvious mistake costs no round trip.
    if (email.trim().isEmpty) throw const ApiException('Please enter your email address.');
    if (password.isEmpty) throw const ApiException('Please enter your password.');

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email.trim().toLowerCase(), 'password': password},
      skipAuth: true,
    );
    return _consumeAuthPayload(data);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? idVerificationNo,
  }) async {
    if (email.trim().isEmpty) throw const ApiException('Please enter your email address.');
    if (password.length < 8) {
      throw const ApiException('Password must be at least 8 characters.');
    }

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (idVerificationNo != null && idVerificationNo.trim().isNotEmpty)
          'idVerificationNo': idVerificationNo.trim(),
      },
      skipAuth: true,
    );
    return _consumeAuthPayload(data);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    // The backend verifies a real Google ID token; there is nothing to send until google_sign_in
    // is added and GOOGLE_CLIENT_ID is configured. Failing loudly beats a fake success.
    throw const ApiException(
      'Google sign-in is not set up yet. Please use your email and password.',
    );
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (!await _api.tokens.hasSession) return null;
    try {
      final data = await _api.get<Map<String, dynamic>>('/auth/me');
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      _currentUser = user;
      return user;
    } on ApiException {
      // An expired or revoked session simply means signed out.
      await _api.tokens.clear();
      _currentUser = null;
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final refreshToken = await _api.tokens.refreshToken;
    try {
      await _api.post<dynamic>(
        '/auth/logout',
        data: refreshToken != null ? {'refreshToken': refreshToken} : const {},
      );
    } on ApiException {
      // Revoking server-side is best-effort; the local tokens go either way.
    }
    await _api.tokens.clear();
    _currentUser = null;
  }

  @override
  Future<String?> requestPasswordReset(String email) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email.trim().toLowerCase()},
      skipAuth: true,
    );
    return data['devCode'] as String?;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post<dynamic>(
      '/auth/reset-password',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
      skipAuth: true,
    );
  }

  /// Keeps the cached profile in step after an edit elsewhere in the app.
  void updateCachedUser(AppUser user) => _currentUser = user;
}
