import '../../models/app_user.dart';

/// Contract for authentication.
///
/// Methods return the signed-in [AppUser] rather than a bool: the caller needs the profile, and a
/// bare `true` gave the mock implementation licence to succeed without checking anything. Failures
/// throw [ApiException], so the reason reaches the UI instead of being flattened to `false`.
abstract class IAuthService {
  bool get isAuthenticated;
  String? get currentUserEmail;
  AppUser? get currentUser;

  Future<AppUser> signIn(String email, String password);

  Future<AppUser> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? idVerificationNo,
  });

  Future<AppUser> signInWithGoogle();

  /// Restores a session from stored tokens on app start. Returns null when there is none.
  Future<AppUser?> restoreSession();

  Future<void> signOut();

  /// Requests a password-reset code. Returns the code only in development, where the backend
  /// echoes it because no email provider is configured yet.
  Future<String?> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
