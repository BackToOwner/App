import 'package:flutter/foundation.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

class ChatUnreadController extends ChangeNotifier {
  final ApiClient _api;
  ChatUnreadController(this._api);

  Map<String, int> _byReportId = {};
  bool _loading = false;

  int get totalUnreadMessages =>
      _byReportId.values.fold(0, (sum, count) => sum + count);

  int unreadForReport(String reportId) => _byReportId[reportId] ?? 0;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/chat/unread-summary',
      );
      final raw = response['byReportId'];
      if (raw is Map) {
        _byReportId = raw.map(
          (key, value) => MapEntry(
            key.toString(),
            value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
          ),
        );
      } else {
        _byReportId = {};
      }
      notifyListeners();
    } on ApiException {
      // Keep the last known counts if the network is temporarily unavailable.
    } catch (_) {
      // Unread badges must not crash the dashboard.
    } finally {
      _loading = false;
    }
  }
}
