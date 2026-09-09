import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/auth/api_auth_service.dart';
import '../services/auth/auth_service_interface.dart';

/// Holds the signed-in user for every screen that used to show hard-coded details.
class ProfileViewModel extends ChangeNotifier {
  final ApiClient _api;
  final IAuthService _authService;

  ProfileViewModel(this._api, this._authService) {
    _user = _authService.currentUser;
  }

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.get<Map<String, dynamic>>('/me');
      _user = AppUser.fromJson(data);
      _syncAuthCache();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) async {
    final data = await _api.patch<Map<String, dynamic>>('/me', data: {
      if (firstName != null && firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
      if (lastName != null) 'lastName': lastName.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim().toLowerCase(),
      if (phone != null) 'phone': phone.trim(),
    });
    _user = AppUser.fromJson(data);
    _syncAuthCache();
    notifyListeners();
  }

  Future<void> uploadAvatar(String filePath) async {
    final data = await _api.uploadFile('/me/avatar', filePath, field: 'image');
    _user = AppUser.fromJson(data);
    _syncAuthCache();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Sending the refresh token keeps *this* device signed in while every other session is
    // revoked — the backend treats its absence as "sign me out everywhere".
    final refreshToken = await _api.tokens.refreshToken;
    await _api.patch<dynamic>('/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'refreshToken': ?refreshToken,
    });
  }

  void _syncAuthCache() {
    final user = _user;
    final service = _authService;
    if (user != null && service is ApiAuthService) {
      service.updateCachedUser(user);
    }
  }
}
