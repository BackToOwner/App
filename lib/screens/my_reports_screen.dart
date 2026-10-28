import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/chat_unread_controller.dart';
import '../widgets/item_detail_modal.dart';
import '../widgets/report_item_card.dart';

/// Screen that displays the current user's filed reports.
/// Navigated to from the Profile screen → "My Reports" option.
class MyReportsScreen extends StatefulWidget {
  final ReportType? type;

  const MyReportsScreen({super.key, this.type});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardController>().refresh();
      context.read<ChatUnreadController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    // The caller's own reports, from /me/reports — not the whole public feed.
    final allReports = controller.myReports
        .where((item) => widget.type == null || item.type == widget.type)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.type == ReportType.lost
              ? 'My Lost Items'
              : widget.type == ReportType.found
              ? 'My Found Items'
              : 'My Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: allReports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: allReports.length,
              itemBuilder: (context, index) {
                final item = allReports[index];
                return ReportItemCard(
                  item: item,
                  hasUnreadMessage:
                      context.watch<ChatUnreadController>().unreadForReport(
                        item.id,
                      ) >
                      0,
                  onTap: () => ItemDetailModal.show(context, item),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.primaryBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.type == ReportType.lost
                  ? 'You haven\'t filed any lost reports yet.'
                  : widget.type == ReportType.found
                  ? 'You haven\'t filed any found reports yet.'
                  : 'You haven\'t filed any reports yet.\nGo to Lost or Found to report an item.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
