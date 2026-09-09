import 'package:flutter/foundation.dart';
import '../../models/report_item.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'report_repository_interface.dart';

/// Reports backed by the API.
///
/// Keeps the ValueNotifier shape of the in-memory repository it replaces, so the existing
/// view-models and screens keep working: reads are synchronous against a cache, and [refresh]
/// is the only thing that hits the network on a read path.
class ApiReportRepository extends ValueNotifier<List<ReportItem>> implements IReportRepository {
  final ApiClient _api;

  ApiReportRepository(this._api) : super(const []);

  List<ReportItem> _mine = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  List<ReportItem> getAllReports() => List.unmodifiable(value);

  @override
  List<ReportItem> getLostReports() =>
      List.unmodifiable(value.where((item) => item.type == ReportType.lost));

  @override
  List<ReportItem> getFoundReports() =>
      List.unmodifiable(value.where((item) => item.type == ReportType.found));

  @override
  List<ReportItem> getMyReports() => List.unmodifiable(_mine);

  @override
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // `status=active` keeps returned and closed items out of the browse feed.
      final feed = await _api.getList('/reports', query: {
        'status': 'active',
        'pageSize': 50,
      });
      final feedItems = feed.map(ReportItem.fromJson).toList();

      // The caller's own reports come from a separate endpoint because the feed is paginated and
      // a user's report may well not be on the first page.
      List<ReportItem> mine = const [];
      try {
        final own = await _api.getList('/me/reports', query: {'pageSize': 50});
        mine = own.map(ReportItem.fromJson).toList();
      } on ApiException {
        // Signed out: the public feed still works, there is just nothing personal to show.
      }

      _mine = mine;
      _errorMessage = null;
      value = feedItems; // assigning to `value` notifies listeners
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<ReportItem> addReport({
    required String title,
    required ReportType type,
    required String location,
    String? description,
    String? category,
    double? reward,
    double? lat,
    double? lng,
    String? imagePath,
  }) async {
    final created = await _api.post<Map<String, dynamic>>('/reports', data: {
      'title': title,
      'type': type == ReportType.found ? 'found' : 'lost',
      'location': location,
      if (description != null && description.isNotEmpty) 'description': description,
      if (category != null && category.isNotEmpty) 'category': category,
      'reward': ?reward,
      'lat': ?lat,
      'lng': ?lng,
    });

    var item = ReportItem.fromJson(created);

    // The photo is a second request: the report exists first, so a failed upload loses the image
    // rather than the whole report.
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final withImage = await _api.uploadFile('/reports/${item.id}/images', imagePath);
        item = ReportItem.fromJson(withImage);
      } on ApiException {
        // Keep the report; the user can add the photo again from the detail screen.
      }
    }

    value = [item, ...value];
    _mine = [item, ..._mine];
    return item;
  }

  @override
  Future<void> deleteReport(String id) async {
    await _api.delete<dynamic>('/reports/$id');
    value = value.where((item) => item.id != id).toList();
    _mine = _mine.where((item) => item.id != id).toList();
  }
}
