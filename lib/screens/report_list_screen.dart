import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../controllers/dashboard_controller.dart';
import '../services/filter/report_filter_strategy.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/item_detail_modal.dart';
import '../widgets/report_item_card.dart';
import '../widgets/report_item_modal.dart';

class ReportListScreen extends StatefulWidget {
  final ReportType reportType;

  const ReportListScreen({super.key, required this.reportType});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isLost => widget.reportType == ReportType.lost;

  ReportFilterStrategy get _filterStrategy =>
      _isLost ? LostReportsFilterStrategy() : FoundReportsFilterStrategy();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final isLost = _isLost;
    final hasAnyItems = (isLost ? controller.lostReports : controller.foundReports).isNotEmpty;
    final items = _filterStrategy.filter(controller.allReports, _searchQuery);

    final primaryColor = isLost
        ? AppColors.lostThemeStart
        : AppColors.foundThemeStart;
    final title = isLost ? 'Lost Items' : 'Found Items';
    final fabLabel = isLost ? 'Report Lost' : 'Report Found';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.read<DashboardController>().setNavIndex(0);
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (hasAnyItems) _buildSearchBar(primaryColor, isLost),
          Expanded(
            child: !hasAnyItems
                ? EmptyStateWidget(
                    iconData: isLost ? Icons.search_off_rounded : Icons.task_alt_rounded,
                    title: isLost
                        ? 'No Lost Items Reported Yet'
                        : 'No Found Items Reported Yet',
                    subtitle: isLost
                        ? 'Be the first to upload a report for a missing item in your area.'
                        : 'Found something? Upload a report to help return it to its owner.',
                    buttonLabel: isLost ? 'Report Lost Item' : 'Report Found Item',
                    badgeBgColor: isLost
                        ? AppColors.lostBadgeBg
                        : AppColors.foundBadgeBg,
                    buttonBgColor: primaryColor,
                    onButtonPressed: () =>
                        ReportItemModal.show(context, initialType: widget.reportType),
                  )
                : items.isEmpty
                    ? _buildNoResultsState(isLost)
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
          ),
        ],
      ),
      floatingActionButton: hasAnyItems
          ? FloatingActionButton.extended(
              heroTag: isLost ? 'lost_fab' : 'found_fab',
              onPressed: () => ReportItemModal.show(context, initialType: isLost ? ReportType.lost : ReportType.found),
              backgroundColor: primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                fabLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSearchBar(Color accentColor, bool isLost) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkNavy.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: isLost ? 'Search lost items...' : 'Search found items...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: 22),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isLost) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No matching items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No ${isLost ? 'lost' : 'found'} items match "$_searchQuery". Try a different search.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
