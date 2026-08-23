import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/item_detail_modal.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Section
                _buildQuickActionsSection(context),
                const SizedBox(height: 22),

                // Redesigned Recent Reports Section with Lost & Found Cards & Category Summary
                const _RecentReportsWidget(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Header & Stats Section moved to the VERY BOTTOM
          _buildBottomHeaderAndStats(context, viewModel),
        ],
      ),
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

  Widget _buildBottomHeaderAndStats(BuildContext context, DashboardViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330B2252),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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

                  // Bell Notification Button
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
              const SizedBox(height: 22),

              // Stats Row (3 Cards) - Search Bar Removed
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
}

class _RecentReportsWidget extends StatefulWidget {
  const _RecentReportsWidget();

  @override
  State<_RecentReportsWidget> createState() => _RecentReportsWidgetState();
}

class _RecentReportsWidgetState extends State<_RecentReportsWidget> {
  ReportType _selectedTab = ReportType.lost;
  String _selectedCategoryEmoji = 'ALL';

  final List<Map<String, String>> _categories = const [
    {'emoji': 'ALL', 'label': 'All'},
    {'emoji': '👛', 'label': 'Wallets'},
    {'emoji': '📱', 'label': 'Phones'},
    {'emoji': '🐕', 'label': 'Pets'},
    {'emoji': '🔑', 'label': 'Keys'},
    {'emoji': '🎒', 'label': 'Bags'},
    {'emoji': '🎧', 'label': 'Audio'},
    {'emoji': '💻', 'label': 'Laptops'},
    {'emoji': '🕶️', 'label': 'Glasses'},
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final isLostTab = _selectedTab == ReportType.lost;

    // Filter reports by selected tab (Lost or Found) and selected category
    final itemsForTab = isLostTab ? viewModel.lostReports : viewModel.foundReports;
    final filteredCategoryItems = _selectedCategoryEmoji == 'ALL'
        ? itemsForTab
        : itemsForTab.where((item) => item.emojiIcon == _selectedCategoryEmoji).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (No "See all" button)
        const SectionHeader(title: 'Recent Reports'),
        const SizedBox(height: 14),

        // Two Main Distinct Cards / Tabs: "Lost" and "Found"
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = ReportType.lost;
                    _selectedCategoryEmoji = 'ALL';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isLostTab ? const Color(0xFFFFECEF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLostTab ? AppColors.lostRedEnd : AppColors.borderColor,
                      width: isLostTab ? 2 : 1,
                    ),
                    boxShadow: isLostTab
                        ? [
                            BoxShadow(
                              color: AppColors.lostRedEnd.withAlpha(35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🥹 ', style: TextStyle(fontSize: 18)),
                      Text(
                        'Lost Items',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isLostTab ? AppColors.lostRedEnd : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = ReportType.found;
                    _selectedCategoryEmoji = 'ALL';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: !isLostTab ? const Color(0xFFE6F9F3) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !isLostTab ? AppColors.foundGreenEnd : AppColors.borderColor,
                      width: !isLostTab ? 2 : 1,
                    ),
                    boxShadow: !isLostTab
                        ? [
                            BoxShadow(
                              color: AppColors.foundGreenEnd.withAlpha(35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎉 ', style: TextStyle(fontSize: 18)),
                      Text(
                        'Found Items',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: !isLostTab ? AppColors.foundGreenEnd : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Category Images / Icons Row
        Text(
          isLostTab ? 'Filter Lost Categories:' : 'Filter Found Categories:',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final emoji = cat['emoji']!;
              final label = cat['label']!;
              final isSelected = _selectedCategoryEmoji == emoji;

              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryEmoji = emoji),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isLostTab ? AppColors.lostRedEnd : AppColors.foundGreenEnd)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isLostTab ? AppColors.lostRedEnd : AppColors.foundGreenEnd)
                          : AppColors.borderColor,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emoji == 'ALL' ? '🌐' : emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Summary List of Selected Category Items
        if (filteredCategoryItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Text(
                  _selectedCategoryEmoji == 'ALL' ? '🔍' : _selectedCategoryEmoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  'No ${isLostTab ? "lost" : "found"} items in this category yet.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCategoryItems.length,
            itemBuilder: (context, index) {
              final item = filteredCategoryItems[index];
              return ReportItemCard(
                item: item,
                onTap: () => ItemDetailModal.show(context, item),
              );
            },
          ),
      ],
    );
  }
}
