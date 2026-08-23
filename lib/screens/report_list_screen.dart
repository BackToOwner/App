import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/item_detail_modal.dart';
import '../widgets/report_item_card.dart';
import '../widgets/report_item_modal.dart';

/// Reusable report list screen replacing duplicated LostScreen and FoundScreen boilerplate (DRY)
class ReportListScreen extends StatelessWidget {
  final ReportType reportType;

  const ReportListScreen({
    super.key,
    required this.reportType,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final isLost = reportType == ReportType.lost;
    final items = isLost ? viewModel.lostReports : viewModel.foundReports;

    final primaryColor = isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd;
    final title = isLost ? 'Lost Items 🥹' : 'Found Items 🎉';
    final fabLabel = isLost ? 'Report Lost' : 'Report Found';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: items.isEmpty
          ? EmptyStateWidget(
              emoji: isLost ? '🥹' : '🎉',
              title: isLost ? 'No Lost Items Reported Yet' : 'No Found Items Reported Yet',
              subtitle: isLost
                  ? 'Be the first to upload a report for a missing item in your area.'
                  : 'Found something? Upload a report to help return it to its owner.',
              buttonLabel: isLost ? 'Report Lost Item' : 'Report Found Item',
              badgeBgColor: isLost ? AppColors.lostBadgeBg : AppColors.foundBadgeBg,
              buttonBgColor: primaryColor,
              onButtonPressed: () => ReportItemModal.show(context, initialType: reportType),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ReportItemCard(
                  item: item,
                  onTap: () => ItemDetailModal.show(context, item),
                );
              },
            ),
      floatingActionButton: items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => ReportItemModal.show(context, initialType: reportType),
              backgroundColor: primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                fabLabel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}
