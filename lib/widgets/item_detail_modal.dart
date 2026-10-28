import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../services/api/api_exception.dart';
import '../services/api/api_client.dart';
import '../screens/match_chat_screen.dart';
import '../controllers/dashboard_controller.dart';
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
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: isLost
                        ? AppColors.lostThemeStart
                        : AppColors.foundThemeStart,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isLost
                                ? AppColors.lostBadgeBg
                                : AppColors.foundBadgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLost ? 'LOST ITEM' : 'FOUND ITEM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isLost
                                  ? AppColors.lostBadgeText
                                  : AppColors.foundBadgeText,
                            ),
                          ),
                        ),
                        if (item.status != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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

          // Report photo, when the API provides one.
          Builder(
            builder: (context) {
              final imageUrl = (item.primaryImage?.trim().isNotEmpty ?? false)
                  ? item.primaryImage!.trim()
                  : item.images
                        .where((url) => url.trim().isNotEmpty)
                        .firstOrNull;

              if (imageUrl == null || imageUrl.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      alignment: Alignment.center,
                      color: AppColors.borderColor,
                      child: const Text('Could not load report photo'),
                    ),
                  ),
                ),
              );
            },
          ),

          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 16),

          // Detail Items List
          if (item.itemColor != null && item.itemColor!.isNotEmpty) ...[
            _buildDetailRow(Icons.palette_outlined, 'Color', item.itemColor!),
            const SizedBox(height: 12),
          ],
          // Campus and area are shown separately when the report has them; reports filed before
          // the split — and anything from the admin dashboard — only have the one location line.
          if (item.campus.isNotEmpty || item.area.isNotEmpty) ...[
            if (item.campus.isNotEmpty) ...[
              _buildDetailRow(Icons.school_outlined, 'Campus', item.campus),
              const SizedBox(height: 12),
            ],
            if (item.area.isNotEmpty) ...[
              _buildDetailRow(Icons.place_outlined, 'Area', item.area),
              const SizedBox(height: 12),
            ],
          ] else ...[
            _buildDetailRow(
              Icons.location_on_outlined,
              'Location',
              item.location,
            ),
            const SizedBox(height: 12),
          ],
          if (item.additionalDetails != null &&
              item.additionalDetails!.isNotEmpty) ...[
            _buildDetailRow(
              Icons.info_outline,
              'Details',
              item.additionalDetails!,
            ),
            const SizedBox(height: 12),
          ],
          _buildDetailRow(Icons.access_time, 'Reported', item.timeAgo),
          if (item.reward != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.emoji_events_outlined,
              'Reward Offered',
              item.reward!,
              valueColor: const Color(0xFFD97706),
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.confirmation_number_outlined,
            'Case ID',
            '#${item.id}',
          ),
          const SizedBox(height: 24),

          // Contact the other participant through the real, approved match ID.
          GradientButton(
            text:
                (isLost ||
                    [
                      'matched',
                      'returned',
                    ].contains((item.status ?? '').toLowerCase()))
                ? 'Contact Owner / Reporter'
                : 'Claim Found Item',
            gradient: isLost
                ? AppColors.reportLostGradient
                : AppColors.reportFoundGradient,
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final status = (item.status ?? '').toLowerCase();
              final isMatched = status == 'matched';
              final isReturned = status == 'returned';

              // Preserve the existing claim placeholder for unmatched found items.
              if (!isLost && !isMatched && !isReturned) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Submitting claim request for "${item.displayTitle}"...',
                    ),
                  ),
                );
                return;
              }

              try {
                final response = await context
                    .read<ApiClient>()
                    .get<Map<String, dynamic>>(
                      '/chat/reports/${Uri.encodeComponent(item.id)}/approved-match',
                    );

                final matchId = response['matchId']?.toString();
                if (matchId == null || matchId.isEmpty) {
                  throw const ApiException(
                    'No approved match is available for chat yet.',
                  );
                }

                if (!context.mounted) return;

                navigator.pop();
                await navigator.push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchChatScreen(matchId: matchId),
                  ),
                );
              } on ApiException catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not open chat. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
                    await context.read<DashboardController>().deleteReport(
                      item.id,
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Deleted "${item.displayTitle}".'),
                      ),
                    );
                  } on ApiException catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                label: const Text(
                  'Delete Report',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
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
