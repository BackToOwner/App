import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/item_detail_modal.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/report_item_card.dart';
import '../widgets/report_item_modal.dart';
import '../widgets/section_header.dart';
import '../widgets/stats_card.dart';
import 'found_screen.dart';
import 'lost_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: IndexedStack(
            index: viewModel.currentNavIndex,
            children: const [
              _DashboardHomeView(),
              LostScreen(),
              FoundScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: viewModel.currentNavIndex,
            onTap: (index) => viewModel.setNavIndex(index),
          ),
        );
      },
    );
  }
}

class _DashboardHomeView extends StatelessWidget {
  const _DashboardHomeView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Curved Dark Blue Top Header Area
          _buildHeader(context, viewModel),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Section
                _buildQuickActionsSection(context),
                const SizedBox(height: 22),

                // Nearby Items Section
                _buildNearbyItemsSection(context),
                const SizedBox(height: 22),

                // Recent Reports Section & Filters
                _buildRecentReportsSection(context, viewModel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashboardViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330B2252),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Profile Row
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset('assets/images/app_logo.png'),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning 👋',
                        style: TextStyle(
                          color: Colors.white.withAlpha(190),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'Ahmed Khalid',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Bell Notification Button with Dot
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5252),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Avatar Circle 'A'
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryCyan,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withAlpha(35),
                    width: 1,
                  ),
                ),
                child: TextField(
                  onChanged: viewModel.setSearchQuery,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search lost or found items...',
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha(160),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withAlpha(180),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row (3 Cards)
              Row(
                children: [
                  StatsCard(
                    iconWidget: _buildBadgeIcon(Icons.check, const Color(0xFF22C55E)),
                    value: '12,483',
                    label: 'Items Returned',
                  ),
                  const SizedBox(width: 10),
                  StatsCard(
                    iconWidget: _buildBadgeIcon(Icons.search, const Color(0xFF3B82F6)),
                    value: '3,291',
                    label: 'Active Cases',
                  ),
                  const SizedBox(width: 10),
                  StatsCard(
                    iconWidget: _buildBadgeIcon(Icons.gps_fixed, const Color(0xFFEF4444)),
                    value: '78%',
                    label: 'Success Rate',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            QuickActionCard(
              title: 'Report Lost',
              subtitle: 'Lost something?',
              emojiIcon: '🥹',
              gradient: AppColors.reportLostGradient,
              onTap: () => ReportItemModal.show(context, initialType: ReportType.lost),
            ),
            const SizedBox(width: 14),
            QuickActionCard(
              title: 'Report Found',
              subtitle: 'Found something?',
              emojiIcon: '🎉',
              gradient: AppColors.reportFoundGradient,
              onTap: () => ReportItemModal.show(context, initialType: ReportType.found),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNearbyItemsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Nearby Items',
          actionLabel: 'View Map',
          onActionTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening Interactive Map View...')),
            );
          },
        ),
        const SizedBox(height: 12),
        const MapPlaceholderWidget(),
      ],
    );
  }

  Widget _buildRecentReportsSection(BuildContext context, DashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Reports',
          actionLabel: 'See all',
          onActionTap: () {},
        ),
        const SizedBox(height: 12),

        // Filter Pills Row (All / Lost / Found)
        Row(
          children: [
            _buildFilterPill(
              context,
              label: 'All',
              type: ReportType.all,
              selected: viewModel.selectedFilter == ReportType.all,
              onTap: () => viewModel.setFilter(ReportType.all),
            ),
            const SizedBox(width: 10),
            _buildFilterPill(
              context,
              label: '🥹 Lost',
              type: ReportType.lost,
              selected: viewModel.selectedFilter == ReportType.lost,
              onTap: () => viewModel.setFilter(ReportType.lost),
            ),
            const SizedBox(width: 10),
            _buildFilterPill(
              context,
              label: '🎉 Found',
              type: ReportType.found,
              selected: viewModel.selectedFilter == ReportType.found,
              onTap: () => viewModel.setFilter(ReportType.found),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Reports ListView
        if (viewModel.filteredReports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No report items match your search or filter.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.filteredReports.length,
            itemBuilder: (context, index) {
              final item = viewModel.filteredReports[index];
              return ReportItemCard(
                item: item,
                onTap: () => ItemDetailModal.show(context, item),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required ReportType type,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : const Color(0xFFE2E8F0).withAlpha(180),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
