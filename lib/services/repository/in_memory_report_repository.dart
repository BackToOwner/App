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
      title: 'Leather Wallet',
      itemColor: 'Black',
      campus: 'BCI',
      area: 'CRK 2',
      additionalDetails: 'Near the computers on the second floor',
      type: ReportType.lost,
      timeAgo: '2h ago',
      reward: r'$50 reward',
      emojiIcon: '👛',
      iconBgHex: 'FFF0F5',
    ),
    ReportItem(
      id: '2',
      title: 'iPhone 15 Pro Max',
      itemColor: 'Silver',
      campus: 'BCI',
      area: 'Main Hall',
      additionalDetails: 'Found on a bench near the entrance',
      type: ReportType.found,
      timeAgo: '4h ago',
      status: 'MATCHED',
      emojiIcon: '📱',
      iconBgHex: 'F0F7FF',
    ),
    ReportItem(
      id: '3',
      title: 'Golden Retriever Pup',
      campus: 'BCI',
      area: 'Garden Area',
      additionalDetails: 'Last seen near the parking lot',
      type: ReportType.lost,
      timeAgo: '1d ago',
      reward: r'$200 reward',
      emojiIcon: '🐕',
      iconBgHex: 'FFF9EB',
    ),
    ReportItem(
      id: '4',
      title: 'Toyota Smart Key Fob',
      itemColor: 'Grey',
      campus: 'BCI',
      area: 'CRK 1',
      additionalDetails: 'Found in Room 105',
      type: ReportType.found,
      timeAgo: '3h ago',
      emojiIcon: '🔑',
      iconBgHex: 'F0FDF4',
    ),
    ReportItem(
      id: '5',
      title: 'North Face Backpack',
      itemColor: 'Blue',
      campus: 'BCI',
      area: 'Canteen',
      type: ReportType.lost,
      timeAgo: '6h ago',
      reward: r'$30 reward',
      emojiIcon: '🎒',
      iconBgHex: 'EFF6FF',
    ),
    ReportItem(
      id: '6',
      title: 'Sony Wireless Headphones',
      itemColor: 'Black',
      campus: 'BCI',
      area: 'Library',
      additionalDetails: 'Left on a table near the window',
      type: ReportType.found,
      timeAgo: '5h ago',
      emojiIcon: '🎧',
      iconBgHex: 'F5F3FF',
    ),
    ReportItem(
      id: '7',
      title: 'MacBook Pro 16-inch',
      itemColor: 'Space Grey',
      campus: 'BCI',
      area: 'CRK 3',
      additionalDetails: 'Third floor, Lab Room B',
      type: ReportType.lost,
      timeAgo: '8h ago',
      reward: r'$150 reward',
      emojiIcon: '💻',
      iconBgHex: 'F0F9FF',
    ),
    ReportItem(
      id: '8',
      title: 'Ray-Ban Sunglasses',
      itemColor: 'Brown',
      campus: 'BCI',
      area: 'Sports Ground',
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
