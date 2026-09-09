import 'package:flutter/foundation.dart';
import '../../models/report_item.dart';

/// Read-only operations on report items (ISP).
///
/// These stay synchronous and serve a locally cached list, so widgets can build without awaiting.
/// [refresh] is what actually talks to the network.
abstract class IReportReader {
  List<ReportItem> getAllReports();
  List<ReportItem> getLostReports();
  List<ReportItem> getFoundReports();

  /// The caller's own reports, for the My Reports screen.
  List<ReportItem> getMyReports();

  bool get isLoading;
  String? get errorMessage;

  Future<void> refresh();
}

/// Write operations on report items (ISP).
///
/// Asynchronous, unlike the in-memory version they replaced: each one is a network round trip
/// that can fail, and the caller needs to await the result before telling the user it worked.
abstract class IReportWriter {
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
  });

  Future<void> deleteReport(String id);
}

/// Consolidated repository interface for report data operations (DIP, LSP).
abstract class IReportRepository implements IReportReader, IReportWriter, Listenable {}
