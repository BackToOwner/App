import 'package:flutter/foundation.dart';
import '../../models/report_item.dart';

/// Interface for read-only operations on report items (ISP)
abstract class IReportReader {
  List<ReportItem> getAllReports();
  List<ReportItem> getLostReports();
  List<ReportItem> getFoundReports();
}

/// Interface for write operations on report items (ISP)
abstract class IReportWriter {
  void addReport(ReportItem item);
  void deleteReport(String id);
}

/// Consolidated Repository interface for report data operations (DIP, LSP)
abstract class IReportRepository implements IReportReader, IReportWriter, Listenable {}
