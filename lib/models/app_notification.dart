/// One row of the notifications inbox.
///
/// `type` mirrors the backend's CHECK constraint exactly, so the screen's icon/colour switch maps
/// straight onto it with no translation layer.
enum NotificationType { match, comment, claim, returned, info, reminder }

NotificationType notificationTypeFromString(String? value) {
  switch (value) {
    case 'match':
      return NotificationType.match;
    case 'comment':
      return NotificationType.comment;
    case 'claim':
      return NotificationType.claim;
    case 'returned':
      return NotificationType.returned;
    case 'reminder':
      return NotificationType.reminder;
    default:
      return NotificationType.info;
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? reportId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.reportId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: notificationTypeFromString(json['type'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        reportId: json['reportId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        reportId: reportId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  String get timeAgo {
    final created = createdAt;
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
