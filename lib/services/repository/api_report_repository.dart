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
class ApiReportRepository extends ValueNotifier<List<ReportItem>>
    implements IReportRepository {
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
  List<ReportItem> getLostReports() => List.unmodifiable(
        value.where((item) =>
            item.type == ReportType.lost &&
            (item.status ?? '').toLowerCase() == 'open' &&
            !item.isMine),
      );

  @override
  List<ReportItem> getFoundReports() => List.unmodifiable(
        value.where((item) =>
            item.type == ReportType.found &&
            (item.status ?? '').toLowerCase() == 'open' &&
            !item.isMine),
      );

  @override
  List<ReportItem> getMyReports() => List.unmodifiable(_mine);

  @override
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // `status=active` keeps returned and closed items out of the browse feed.
      final feed = await _api.getList(
        '/reports',
        query: {'status': 'active', 'pageSize': 50},
      );
      final feedItems = feed.map(ReportItem.fromJson).toList();

      // The caller's own reports come from a separate endpoint because the feed is paginated and
      // a user's report may well not be on the first page.
      List<ReportItem> mine = const [];
      try {
        final own = await _api.getList('/reports/me', query: {'pageSize': 50});
        mine = own.map(ReportItem.fromJson).toList();
      } on ApiException catch (e) {
        // Keep the last successful personal-report cache if this request fails.
        // Do not turn a temporary API failure into an empty My Reports screen.
        debugPrint('Could not load personal reports: ${e.message}');
        mine = _mine;
      }

      // Prefer the authenticated copy of a report when the same report is
      // present in both the public feed and the current user's own reports.
      final mineById = {for (final item in mine) item.id: item};
      final mergedFeed = feedItems
          .map((item) => mineById[item.id] ?? item)
          .toList();

      // Include the user's own reports even if they are outside the public
      // feed's current page or filtered out of the active public list.
      final feedIds = mergedFeed.map((item) => item.id).toSet();
      mergedFeed.addAll(mine.where((item) => !feedIds.contains(item.id)));

      _mine = mine;
      _errorMessage = null;
      value = mergedFeed; // assigning to `value` notifies listeners
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
    required String campus,
    required String area,
    String? itemColor,
    String? additionalDetails,
    String? description,
    String? category,
    double? reward,
    double? lat,
    double? lng,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    // `location` stays the single searchable string the feed and FTS index are built on; the
    // parts are sent alongside it so the detail sheet can show them separately.
    debugPrint('[REWARD TRACE repository] reward=[$reward], type=[${type.name}]');
    final created = await _api.post<Map<String, dynamic>>(
      '/reports',
      data: {
        'title': title,
        'type': type == ReportType.found ? 'found' : 'lost',
        'location': ReportItem.composeLocation(campus, area),
        'campus': campus,
        'area': area,
        if (itemColor != null && itemColor.isNotEmpty) 'itemColor': itemColor,
        if (additionalDetails != null && additionalDetails.isNotEmpty)
          'additionalDetails': additionalDetails,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
        'reward': ?reward,
        'lat': ?lat,
        'lng': ?lng,
      },
    );

    var item = ReportItem.fromJson(created);

    // The photo is a second, optional request: the report exists first, so a failed or skipped
    // upload loses only the image, never the report itself.
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final withImage = await _api.uploadFile(
          '/reports/${item.id}/images',
          imageBytes,
          filename: imageFileName ?? 'photo.jpg',
        );
        item = ReportItem.fromJson(withImage);
      } on ApiException catch (e) {
        // Keep the report; the user can add the photo again from the detail screen. The upload
        // failing silently once hid a bad Content-Type for a while, so at least say so in the log.
        debugPrint('Report ${item.id}: image upload failed — ${e.message}');
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
