import 'package:flutter/material.dart';
import '../models/report_item.dart';
import '../services/filter/report_filter_strategy.dart';
import '../services/repository/report_repository_interface.dart';

class DashboardViewModel extends ChangeNotifier {
  final IReportRepository _repository;
  ReportFilterStrategy _filterStrategy = AllReportsFilterStrategy();

  int _currentNavIndex = 0;
  String _searchQuery = '';

  DashboardViewModel(this._repository) {
    _repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    notifyListeners();
  }

  ReportType get selectedFilter => _filterStrategy.type;
  int get currentNavIndex => _currentNavIndex;
  String get searchQuery => _searchQuery;

  List<ReportItem> get allReports => _repository.getAllReports();
  List<ReportItem> get lostReports => _repository.getLostReports();
  List<ReportItem> get foundReports => _repository.getFoundReports();
  List<ReportItem> get myReports => _repository.getMyReports();

  bool get isLoading => _repository.isLoading;
  String? get errorMessage => _repository.errorMessage;

  List<ReportItem> get filteredReports =>
      _filterStrategy.filter(_repository.getAllReports(), _searchQuery);

  Future<void> refresh() => _repository.refresh();

  /// Creates a report on the server. Throws [ApiException] so the caller can show the reason
  /// rather than silently closing the sheet on failure.
  Future<ReportItem> addReport({
    required String title,
    required ReportType type,
    required String location,
    String? description,
    String? category,
    double? reward,
    String? imagePath,
  }) {
    return _repository.addReport(
      title: title,
      type: type,
      location: location,
      description: description,
      category: category,
      reward: reward,
      imagePath: imagePath,
    );
  }

  Future<void> deleteReport(String id) => _repository.deleteReport(id);

  void setFilter(ReportType filter) {
    if (_filterStrategy.type != filter) {
      switch (filter) {
        case ReportType.lost:
          _filterStrategy = LostReportsFilterStrategy();
          break;
        case ReportType.found:
          _filterStrategy = FoundReportsFilterStrategy();
          break;
        case ReportType.all:
          _filterStrategy = AllReportsFilterStrategy();
          break;
      }
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  void setNavIndex(int index) {
    if (_currentNavIndex != index) {
      _currentNavIndex = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
