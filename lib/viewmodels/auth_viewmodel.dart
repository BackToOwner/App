import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/api/api_exception.dart';
import '../services/auth/auth_service_interface.dart';

class AuthViewModel extends ChangeNotifier {
  final IAuthService _authService;

  AuthViewModel(this._authService);

  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Empty, not pre-filled with a sample address — a placeholder that looks like a real value is
  // the reason people tap Sign In without noticing they typed nothing.
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idVerificationController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  bool get isSignIn => _isSignIn;
  bool get obscurePassword => _obscurePassword;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  IAuthService get authService => _authService;

  void setAuthMode(bool isSignIn) {
    if (_isSignIn != isSignIn) {
      _isSignIn = isSignIn;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Local checks first, so an empty form never reaches the network — and, more importantly, so
  /// a blank password can never be treated as a successful sign-in.
  String? _validate() {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) return 'Please enter your password.';
    if (!_isSignIn && password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  Future<AppUser?> submitAuth(BuildContext context) async {
    final validationError = _validate();
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _isSignIn
          ? await _authService.signIn(emailController.text, passwordController.text)
          : await _authService.signUp(
              email: emailController.text,
              password: passwordController.text,
              firstName: firstNameController.text,
              lastName: lastNameController.text,
              phone: phoneController.text,
              idVerificationNo: idVerificationController.text,
            );

      passwordController.clear();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
      return user;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitGoogleAuth(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a reset code. Returns a message for the UI to show — including the code itself while
  /// the backend has no email provider and echoes it in development.
  Future<String> requestPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return 'Enter your email address first, then tap Forgot password.';

    try {
      final devCode = await _authService.requestPasswordReset(email);
      return devCode != null
          ? 'Reset code (development): $devCode'
          : 'If that email is registered, a reset code has been sent.';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    idVerificationController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }
}
