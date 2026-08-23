enum ReportType { all, lost, found }

class ReportItem {
  final String id;
  final String title;
  final String location;
  final ReportType type; // lost or found
  final String timeAgo;
  final String? reward;
  final String? status; // e.g. "MATCHED"
  final String emojiIcon;
  final String iconBgHex;

  ReportItem({
    required this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.timeAgo,
    this.reward,
    this.status,
    required this.emojiIcon,
    required this.iconBgHex,
  });
}
