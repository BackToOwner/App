import 'package:flutter/material.dart';
import '../models/report_item.dart';
import '../services/filter/report_filter_strategy.dart';
import '../services/repository/report_repository_interface.dart';

/// ViewModel managing dashboard presentation state, injecting IReportRepository (DIP)
/// and delegating filter logic to ReportFilterStrategy (OCP).
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

  List<ReportItem> get filteredReports =>
      _filterStrategy.filter(_repository.getAllReports(), _searchQuery);

  void addReport(ReportItem newItem) {
    _repository.addReport(newItem);
  }

  void deleteReport(String id) {
    _repository.deleteReport(id);
  }

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
