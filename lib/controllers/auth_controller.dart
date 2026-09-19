import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../services/api/api_exception.dart';
import '../services/auth/auth_service_interface.dart';
import 'dashboard_controller.dart';
import 'profile_controller.dart';

class AuthController extends ChangeNotifier {
  final IAuthService _authService;

  AuthController(this._authService);

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

  /// Matches a leading `+`, a 1-3 digit country code, then exactly 9 digits for the subscriber
  /// number (e.g. `+94712345678`) — spaces in the input are stripped before this runs.
  static final RegExp _phonePattern = RegExp(r'^\+\d{1,3}\d{9}$');

  /// Sri Lankan NIC: digits only, up to 12 of them (the new 12-digit format; the old 9-digit
  /// format plus a letter is not accepted here since the field is validated as digits).
  static final RegExp _nicPattern = RegExp(r'^\d{1,12}$');

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

    if (!_isSignIn) {
      final phone = phoneController.text.trim().replaceAll(' ', '');
      if (phone.isEmpty) return 'Please enter your phone number.';
      if (!_phonePattern.hasMatch(phone)) {
        return 'Enter your phone number as a country code followed by 9 digits (e.g. +94712345678).';
      }

      final idVerification = idVerificationController.text.trim();
      if (idVerification.isEmpty) return 'Please enter your NIC / ID verification number.';
      if (!_nicPattern.hasMatch(idVerification)) {
        return 'NIC must contain digits only, up to 12 digits.';
      }
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
      if (!context.mounted) return user;

      // Mirror what the splash screen does for a restored session. Without this, signing out and
      // back in as someone else leaves the previous account's profile on screen.
      context.read<ProfileController>().setUser(user);
      final dashboard = context.read<DashboardController>();
      final navigator = Navigator.of(context);
      try {
        await dashboard.refresh();
      } on ApiException {
        // The sign-in itself succeeded; an empty feed can be pulled to refresh on the dashboard.
      }
      navigator.pushReplacementNamed('/dashboard');
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

  Future<AppUser?> submitGoogleAuth(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (!context.mounted) return user;

      // Mirror submitAuth: without this, signing out and back in as someone else via Google
      // would leave the previous account's profile and feed on screen.
      context.read<ProfileController>().setUser(user);
      final dashboard = context.read<DashboardController>();
      final navigator = Navigator.of(context);
      try {
        await dashboard.refresh();
      } on ApiException {
        // The sign-in itself succeeded; an empty feed can be pulled to refresh on the dashboard.
      }
      navigator.pushReplacementNamed('/dashboard');
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
