import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../services/api/api_exception.dart';
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
                    color: isLost ? AppColors.lostThemeStart : AppColors.foundThemeStart,
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
            _buildDetailRow(Icons.location_on_outlined, 'Location', item.location),
            const SizedBox(height: 12),
          ],
          if (item.additionalDetails != null && item.additionalDetails!.isNotEmpty) ...[
            _buildDetailRow(Icons.info_outline, 'Details', item.additionalDetails!),
            const SizedBox(height: 12),
          ],
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
            onPressed: () => isLost ? _contactReporter(context) : _claimItem(context),
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
                  await context.read<DashboardController>().deleteReport(item.id);
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Deleted "${item.displayTitle}".')),
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

  Future<void> _contactReporter(BuildContext context) async {
    final message = await _promptForMessage(
      context,
      title: 'Contact Reporter',
      hintText: 'Write a message about "${item.displayTitle}"...',
      submitLabel: 'Send',
      requireMessage: true,
    );
    if (message == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<DashboardController>().contactReporter(item.id, message);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Message sent to the reporter.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  Future<void> _claimItem(BuildContext context) async {
    final message = await _promptForMessage(
      context,
      title: 'Claim This Item',
      hintText: 'Describe how you can identify it (optional)...',
      submitLabel: 'Submit Claim',
      requireMessage: false,
    );
    if (message == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<DashboardController>().claimReport(item.id, message: message);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Claim submitted — the owner will review it.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  /// Shows a text-entry dialog and returns the trimmed message, or null if the user cancelled.
  /// When [requireMessage] is true the submit button stays disabled until there is text.
  Future<String?> _promptForMessage(
    BuildContext context, {
    required String title,
    required String hintText,
    required String submitLabel,
    required bool requireMessage,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final canSubmit = !requireMessage || controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: hintText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: canSubmit
                    ? () => Navigator.of(dialogContext).pop(controller.text.trim())
                    : null,
                child: Text(submitLabel),
              ),
            ],
          );
        },
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
