import 'package:flutter/material.dart';
import '../services/auth/auth_service_interface.dart';

class AuthViewModel extends ChangeNotifier {
  final IAuthService _authService;

  AuthViewModel(this._authService);

  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController emailController = TextEditingController(
    text: 'you@example.com',
  );
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController(
    text: '+94 71 234 5678',
  );
  final TextEditingController idVerificationController =
      TextEditingController();

  bool get isSignIn => _isSignIn;
  bool get obscurePassword => _obscurePassword;
  bool get isLoading => _isLoading;
  IAuthService get authService => _authService;

  void setAuthMode(bool isSignIn) {
    if (_isSignIn != isSignIn) {
      _isSignIn = isSignIn;
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  Future<void> submitAuth(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = _isSignIn
          ? await _authService.signIn(
              emailController.text,
              passwordController.text,
            )
          : await _authService.signUp(
              emailController.text,
              passwordController.text,
            );

      if (success && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitGoogleAuth(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _authService.signInWithGoogle();
      if (success && context.mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    idVerificationController.dispose();
    super.dispose();
  }
}
