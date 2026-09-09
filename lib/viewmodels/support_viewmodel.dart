import 'package:flutter/material.dart';
import '../models/faq.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// Serves the Help & Support screen from the backend, so hotline numbers, social links and FAQ
/// copy can change without shipping a new build.
class SupportViewModel extends ChangeNotifier {
  final ApiClient _api;

  SupportViewModel(this._api);

  List<Faq> _faqs = const [];
  Map<String, String> _config = const {};
  bool _isLoading = false;
  String? _errorMessage;

  List<Faq> get faqs => _faqs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String config(String key, {String fallback = ''}) => _config[key] ?? fallback;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getList('/faqs'),
        _api.get<Map<String, dynamic>>('/config', skipAuth: true),
      ]);
      _faqs = (results[0] as List<Map<String, dynamic>>).map(Faq.fromJson).toList();
      _config = (results[1] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitTicket({required String subject, required String message}) async {
    await _api.post<dynamic>('/support/tickets', data: {
      'subject': subject,
      'message': message,
    });
  }
}
