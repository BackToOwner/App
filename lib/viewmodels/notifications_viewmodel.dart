import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// Backs the notifications screen, which previously rendered a hard-coded list.
class NotificationsViewModel extends ChangeNotifier {
  final ApiClient _api;

  NotificationsViewModel(this._api);

  List<AppNotification> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unread = 0;

  List<AppNotification> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unread;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final rows = await _api.getList('/notifications', query: {'pageSize': 50});
      _items = rows.map(AppNotification.fromJson).toList();
      _unread = _items.where((n) => !n.isRead).length;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks one row read. The list updates immediately and only reverts if the server refuses,
  /// so a tap never feels like it did nothing.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final previous = _items;
    _items = _items.map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n).toList();
    _unread = _items.where((n) => !n.isRead).length;
    notifyListeners();

    try {
      await _api.patch<dynamic>('/notifications/${notification.id}/read');
    } on ApiException {
      _items = previous;
      _unread = _items.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final previous = _items;
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    _unread = 0;
    notifyListeners();

    try {
      await _api.post<dynamic>('/notifications/read-all');
    } on ApiException {
      _items = previous;
      _unread = _items.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }
}
