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
                // Top Section: Side-by-Side Lost Item and Found Item Cards with Category Grid & Dynamic Summary
                const _TopCategoryExplorerWidget(),
                const SizedBox(height: 24),

                // Quick Actions Section (Report Lost / Report Found Modals)
                _buildQuickActionsSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Bottom Header & Stats Section (Greeting & Statistics Cards)
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
}

/// Top Section Feature: Side-by-Side 'Lost Item' and 'Found Item' Cards with Category Grid & Dynamic Summary
class _TopCategoryExplorerWidget extends StatefulWidget {
  const _TopCategoryExplorerWidget();

  @override
  State<_TopCategoryExplorerWidget> createState() => _TopCategoryExplorerWidgetState();
}

class _TopCategoryExplorerWidgetState extends State<_TopCategoryExplorerWidget> {
  ReportType _activeMode = ReportType.lost;
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
    final isLost = _activeMode == ReportType.lost;

    // Filter reports by active mode (Lost / Found) and selected category emoji
    final modeReports = isLost ? viewModel.lostReports : viewModel.foundReports;
    final summaryItems = _selectedCategoryEmoji == 'ALL'
        ? modeReports
        : modeReports.where((item) => item.emojiIcon == _selectedCategoryEmoji).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Category Explorer'),
        const SizedBox(height: 12),

        // 1. Two Primary Cards Side-by-Side: 'Lost Item' Card & 'Found Item' Card
        Row(
          children: [
            QuickActionCard(
              title: 'Lost Item',
              subtitle: 'Explore Lost Categories',
              emojiIcon: '🥹',
              gradient: AppColors.reportLostGradient,
              onTap: () {
                setState(() {
                  _activeMode = ReportType.lost;
                  _selectedCategoryEmoji = 'ALL';
                });
              },
            ),
            const SizedBox(width: 14),
            QuickActionCard(
              title: 'Found Item',
              subtitle: 'Explore Found Categories',
              emojiIcon: '🎉',
              gradient: AppColors.reportFoundGradient,
              onTap: () {
                setState(() {
                  _activeMode = ReportType.found;
                  _selectedCategoryEmoji = 'ALL';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Expandable Inner Panel / Grid featuring Selectable Category Images/Icons
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLost ? const Color(0xFFFFF0F3) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLost ? AppColors.lostRedEnd.withAlpha(80) : AppColors.foundGreenEnd.withAlpha(80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd).withAlpha(15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isLost ? '🥹 Select Lost Category:' : '🎉 Select Found Category:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${summaryItems.length} Items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Selector Row
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final emoji = cat['emoji']!;
                    final label = cat['label']!;
                    final isSelected = _selectedCategoryEmoji == emoji;
                    final activeThemeColor = isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? activeThemeColor : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? activeThemeColor : AppColors.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: activeThemeColor.withAlpha(40),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emoji == 'ALL' ? '🌐' : emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Dynamic Summary List below displaying lost/found items in selected category
        if (summaryItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Text(
                  _selectedCategoryEmoji == 'ALL' ? '🔍' : _selectedCategoryEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  'No ${isLost ? "lost" : "found"} items in this category currently.',
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
            itemCount: summaryItems.length,
            itemBuilder: (context, index) {
              final item = summaryItems[index];
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

