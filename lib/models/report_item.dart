enum ReportType { all, lost, found }

class ReportItem {
  final String id;
  final String title;
  final String? itemColor;
  final String campus;
  final String area;
  final String? additionalDetails;
  final ReportType type;
  final String timeAgo;
  final String? reward;
  final String? status;
  final String emojiIcon;
  final String iconBgHex;

  ReportItem({
    required this.id,
    required this.title,
    this.itemColor,
    required this.campus,
    required this.area,
    this.additionalDetails,
    required this.type,
    required this.timeAgo,
    this.reward,
    this.status,
    required this.emojiIcon,
    required this.iconBgHex,
  });

  /// Title with color prefix (e.g. "Black Sony Wireless Headphones")
  String get displayTitle {
    if (itemColor != null && itemColor!.isNotEmpty) {
      return '$itemColor $title';
    }
    return title;
  }

  /// Combined location string for display (e.g. "BCI · CRK 2")
  String get location {
    final parts = <String>[campus, area];
    return parts.join(' · ');
  }

  /// Full location including additional details
  String get locationFull {
    final base = location;
    if (additionalDetails != null && additionalDetails!.isNotEmpty) {
      return '$base\n$additionalDetails';
    }
    return base;
  }
}
