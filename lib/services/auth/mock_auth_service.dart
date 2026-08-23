import 'auth_service_interface.dart';

class MockAuthService implements IAuthService {
  bool _authenticated = false;
  String? _userEmail;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  String? get currentUserEmail => _userEmail;

  @override
  Future<bool> signIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authenticated = true;
    _userEmail = email;
    return true;
  }

  @override
  Future<bool> signUp(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authenticated = true;
    _userEmail = email;
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authenticated = true;
    _userEmail = 'user.google@example.com';
    return true;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _authenticated = false;
    _userEmail = null;
  }
}
