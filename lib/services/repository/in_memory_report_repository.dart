import 'package:flutter/foundation.dart';
import '../../models/report_item.dart';
import 'report_repository_interface.dart';

class InMemoryReportRepository extends ValueNotifier<List<ReportItem>>
    implements IReportRepository {
  InMemoryReportRepository([List<ReportItem>? initialReports])
      : super(initialReports ?? _initialDefaultReports);

  static final List<ReportItem> _initialDefaultReports = [
    ReportItem(
      id: '1',
      title: 'Black Leather Wallet',
      location: 'Central Park, NY',
      type: ReportType.lost,
      timeAgo: '2h ago',
      reward: r'$50 reward',
      emojiIcon: '👛',
      iconBgHex: 'FFF0F5',
    ),
    ReportItem(
      id: '2',
      title: 'iPhone 15 Pro Max',
      location: 'Times Square Station',
      type: ReportType.found,
      timeAgo: '4h ago',
      status: 'MATCHED',
      emojiIcon: '📱',
      iconBgHex: 'F0F7FF',
    ),
    ReportItem(
      id: '3',
      title: 'Golden Retriever Pup',
      location: 'Brooklyn Bridge Park',
      type: ReportType.lost,
      timeAgo: '1d ago',
      reward: r'$200 reward',
      emojiIcon: '🐕',
      iconBgHex: 'FFF9EB',
    ),
    ReportItem(
      id: '4',
      title: 'Toyota Smart Key Fob',
      location: 'Whole Foods Market',
      type: ReportType.found,
      timeAgo: '3h ago',
      emojiIcon: '🔑',
      iconBgHex: 'F0FDF4',
    ),
    ReportItem(
      id: '5',
      title: 'Blue North Face Backpack',
      location: 'Grand Central Station',
      type: ReportType.lost,
      timeAgo: '6h ago',
      reward: r'$30 reward',
      emojiIcon: '🎒',
      iconBgHex: 'EFF6FF',
    ),
    ReportItem(
      id: '6',
      title: 'Sony Wireless Headphones',
      location: 'Main Street Cafe',
      type: ReportType.found,
      timeAgo: '5h ago',
      emojiIcon: '🎧',
      iconBgHex: 'F5F3FF',
    ),
    ReportItem(
      id: '7',
      title: 'MacBook Pro 16-inch',
      location: 'University Library',
      type: ReportType.lost,
      timeAgo: '8h ago',
      reward: r'$150 reward',
      emojiIcon: '💻',
      iconBgHex: 'F0F9FF',
    ),
    ReportItem(
      id: '8',
      title: 'Ray-Ban Sunglasses',
      location: 'Beach Boardwalk',
      type: ReportType.found,
      timeAgo: '1d ago',
      emojiIcon: '🕶️',
      iconBgHex: 'FFF7ED',
    ),
  ];

  @override
  List<ReportItem> getAllReports() => List.unmodifiable(value);

  @override
  List<ReportItem> getLostReports() =>
      List.unmodifiable(value.where((item) => item.type == ReportType.lost));

  @override
  List<ReportItem> getFoundReports() =>
      List.unmodifiable(value.where((item) => item.type == ReportType.found));

  @override
  void addReport(ReportItem item) {
    value = [item, ...value];
  }

  @override
  void deleteReport(String id) {
    value = value.where((item) => item.id != id).toList();
  }
}
