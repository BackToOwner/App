import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// The three KPI cards on the dashboard. Previously hard-coded as 12,483 / 3,291 / 78%.
class StatsViewModel extends ChangeNotifier {
  final ApiClient _api;

  StatsViewModel(this._api);

  int? _itemsReturned;
  int? _activeCases;
  double? _successRate;

  bool get hasData => _itemsReturned != null;

  /// Em dash until the numbers arrive, so the cards never show an invented figure.
  String get itemsReturned => _itemsReturned == null ? '—' : _format(_itemsReturned!);
  String get activeCases => _activeCases == null ? '—' : _format(_activeCases!);
  String get successRate => _successRate == null ? '—' : '${_successRate!.toStringAsFixed(0)}%';

  Future<void> load() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/stats/home', skipAuth: true);
      _itemsReturned = (data['itemsReturned'] as num?)?.toInt() ?? 0;
      _activeCases = (data['activeCases'] as num?)?.toInt() ?? 0;
      _successRate = (data['successRate'] as num?)?.toDouble() ?? 0;
      notifyListeners();
    } on ApiException {
      // Leave the placeholders; the dashboard is still usable without its stat strip.
    }
  }

  String _format(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}
