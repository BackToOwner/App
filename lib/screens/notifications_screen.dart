import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum _NotificationType { match, comment, info, returned, reminder }

class _AppNotification {
  final _NotificationType type;
  final String title;
  final String message;
  final String timeAgo;
  bool isRead;

  _AppNotification({
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_AppNotification> _notifications = [
    _AppNotification(
      type: _NotificationType.match,
      title: 'Possible Match Found! 🎉',
      message: "Someone reported finding an item that matches your lost 'Black Wallet'.",
      timeAgo: '5m ago',
    ),
    _AppNotification(
      type: _NotificationType.comment,
      title: 'New Reply on Your Report',
      message: 'Sara left a comment on your found item report.',
      timeAgo: '1h ago',
    ),
    _AppNotification(
      type: _NotificationType.returned,
      title: 'Item Marked as Returned',
      message: "Great news — your reported item was successfully returned to its owner.",
      timeAgo: 'Yesterday',
      isRead: true,
    ),
    _AppNotification(
      type: _NotificationType.info,
      title: 'Your Report is Trending',
      message: "Your lost 'iPhone 13' report has been viewed 24 times this week.",
      timeAgo: '2 days ago',
      isRead: true,
    ),
    _AppNotification(
      type: _NotificationType.reminder,
      title: 'Still Missing?',
      message: "It's been 7 days since you reported a lost item. Let us know if it's been found.",
      timeAgo: '3 days ago',
      isRead: true,
    ),
  ];

  bool get _hasUnread => _notifications.any((n) => !n.isRead);

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  void _markRead(_AppNotification n) {
    if (!n.isRead) {
      setState(() => n.isRead = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _hasUnread ? _markAllRead : null,
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: _hasUnread ? AppColors.primaryCyan : Colors.white.withAlpha(70),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildTile(_notifications[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.fieldBackground,
              shape: BoxShape.circle,
            ),
            child: const Text('🔔', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all caught up",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              "You'll see updates about matches, comments, and your reports here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_AppNotification n) {
    final visual = _visualFor(n.type);

    return GestureDetector(
      onTap: () => _markRead(n),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: n.isRead ? AppColors.borderColor : visual.color.withAlpha(70),
            width: n.isRead ? 1 : 1.4,
          ),
          boxShadow: n.isRead
              ? []
              : [
                  BoxShadow(
                    color: visual.color.withAlpha(18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: visual.color.withAlpha(22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(visual.icon, color: visual.color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: n.isRead ? FontWeight.w700 : FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 3),
                          decoration: BoxDecoration(
                            color: visual.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color}) _visualFor(_NotificationType type) {
    switch (type) {
      case _NotificationType.match:
        return (icon: Icons.favorite_rounded, color: AppColors.foundGreenEnd);
      case _NotificationType.comment:
        return (icon: Icons.chat_bubble_rounded, color: AppColors.primaryBlue);
      case _NotificationType.returned:
        return (icon: Icons.task_alt_rounded, color: AppColors.foundGreenEnd);
      case _NotificationType.info:
        return (icon: Icons.trending_up_rounded, color: AppColors.primaryBlue);
      case _NotificationType.reminder:
        return (icon: Icons.notifications_active_rounded, color: AppColors.lostRedEnd);
    }
  }
}
