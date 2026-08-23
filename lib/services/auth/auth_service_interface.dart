abstract class IAuthService {
  bool get isAuthenticated;
  String? get currentUserEmail;

  Future<bool> signIn(String email, String password);
  Future<bool> signUp(String email, String password);
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}
