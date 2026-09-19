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
  /// [campus] and [area] are the two halves the report form collects; the implementation composes
  /// them into the single `location` string the API stores.
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
    // A file path cannot represent a picked image on Flutter Web, so the picked image travels as
    // bytes; [imageFileName] just needs a plausible extension for the server's content-type check.
    Uint8List? imageBytes,
    String? imageFileName,
  });

  Future<void> deleteReport(String id);

  /// Files a claim on a found item. [message] is optional context for the owner reviewing it.
  Future<void> claimReport(String reportId, {String message});

  /// Posts a message on a report's comment thread — used to contact the reporter.
  Future<void> addComment(String reportId, String body);
}

/// Consolidated repository interface for report data operations (DIP, LSP).
abstract class IReportRepository implements IReportReader, IReportWriter, Listenable {}
