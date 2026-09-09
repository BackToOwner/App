import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../services/api/api_exception.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'gradient_button.dart';

class ItemDetailModal extends StatelessWidget {
  final ReportItem item;

  const ItemDetailModal({super.key, required this.item});

  static void show(BuildContext context, ReportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemDetailModal(item: item),
    );
  }

  Color _parseHexColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final isLost = item.type == ReportType.lost;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Grab Bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row with Icon & Title
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _parseHexColor(item.iconBgHex),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(item.emojiIcon, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLost ? AppColors.lostBadgeBg : AppColors.foundBadgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLost ? 'LOST ITEM' : 'FOUND ITEM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isLost ? AppColors.lostBadgeText : AppColors.foundBadgeText,
                            ),
                          ),
                        ),
                        if (item.status != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.matchedBadgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.status!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.matchedBadgeText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 16),

          // Detail Items List
          _buildDetailRow(Icons.location_on_outlined, 'Location', item.location),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.access_time, 'Reported', item.timeAgo),
          if (item.reward != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.emoji_events_outlined, 'Reward Offered', item.reward!, valueColor: const Color(0xFFD97706)),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(Icons.confirmation_number_outlined, 'Case ID', '#${item.id}'),
          const SizedBox(height: 24),

          // Primary Contact / Claim Button
          GradientButton(
            text: isLost ? 'Contact Owner / Reporter' : 'Claim Found Item',
            gradient: isLost ? AppColors.reportLostGradient : AppColors.reportFoundGradient,
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLost ? 'Messaging reporter of "${item.title}"...' : 'Submitting claim request for "${item.title}"...',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Delete is owner-only on the server; hiding it elsewhere avoids a guaranteed 403.
          if (item.isMine)
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  await context.read<DashboardViewModel>().deleteReport(item.id);
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Deleted "${item.title}".')),
                  );
                } on ApiException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text('Delete Report', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
