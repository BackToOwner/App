import '../../models/report_item.dart';

abstract class ReportFilterStrategy {
  ReportType get type;
  List<ReportItem> filter(List<ReportItem> items, String searchQuery);

  bool matchesSearch(ReportItem item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return item.title.toLowerCase().contains(q) ||
        item.location.toLowerCase().contains(q);
  }
}

class AllReportsFilterStrategy extends ReportFilterStrategy {
  @override
  ReportType get type => ReportType.all;

  @override
  List<ReportItem> filter(List<ReportItem> items, String searchQuery) {
    return items.where((item) => matchesSearch(item, searchQuery)).toList();
  }
}

class LostReportsFilterStrategy extends ReportFilterStrategy {
  @override
  ReportType get type => ReportType.lost;

  @override
  List<ReportItem> filter(List<ReportItem> items, String searchQuery) {
    return items
        .where(
          (item) =>
              item.type == ReportType.lost && matchesSearch(item, searchQuery),
        )
        .toList();
  }
}

class FoundReportsFilterStrategy extends ReportFilterStrategy {
  @override
  ReportType get type => ReportType.found;

  @override
  List<ReportItem> filter(List<ReportItem> items, String searchQuery) {
    return items
        .where(
          (item) =>
              item.type == ReportType.found && matchesSearch(item, searchQuery),
        )
        .toList();
  }
}
