import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/app_notification.dart';
import '../viewmodels/notifications_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    final notifications = vm.items;
    final hasUnread = vm.unreadCount > 0;

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
            onPressed: hasUnread ? () => context.read<NotificationsViewModel>().markAllRead() : null,
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: hasUnread ? AppColors.primaryCyan : Colors.white.withAlpha(70),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: vm.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView(children: [SizedBox(height: 120), _buildEmptyState()]),
                )
              : RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildTile(notifications[index]),
                  ),
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

  Widget _buildTile(AppNotification n) {
    final visual = _visualFor(n.type);

    return GestureDetector(
      onTap: () => context.read<NotificationsViewModel>().markRead(n),
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
                    n.body,
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

  ({IconData icon, Color color}) _visualFor(NotificationType type) {
    switch (type) {
      case NotificationType.match:
        return (icon: Icons.favorite_rounded, color: AppColors.foundGreenEnd);
      case NotificationType.comment:
        return (icon: Icons.chat_bubble_rounded, color: AppColors.primaryBlue);
      case NotificationType.claim:
        return (icon: Icons.handshake_rounded, color: AppColors.primaryCyan);
      case NotificationType.returned:
        return (icon: Icons.task_alt_rounded, color: AppColors.foundGreenEnd);
      case NotificationType.info:
        return (icon: Icons.trending_up_rounded, color: AppColors.primaryBlue);
      case NotificationType.reminder:
        return (icon: Icons.notifications_active_rounded, color: AppColors.lostRedEnd);
    }
  }
}
