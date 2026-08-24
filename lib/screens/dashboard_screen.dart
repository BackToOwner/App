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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Banner with Integrated Search Bar
          _buildTopHeader(context),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Quick Actions (Report Lost / Report Found)
                _buildQuickActionsSection(context),
                const SizedBox(height: 28),

                // 3. Category Explorer with Segmented Tabs & Category Chips
                const _TopCategoryExplorerWidget(),
              ],
            ),
          ),

          // 4. Platform Statistics Footer Section
          _buildBottomStatsSection(context),
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330B2252),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Logo + Greeting + Notification + Avatar
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withAlpha(35), width: 1),
                    ),
                    child: Image.asset('assets/images/app_logo.png'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning 👋',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Ahmed Khalid',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Notification Bell Button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(30), width: 1),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C5C),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0C2C69), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D2B5), Color(0xFF00A99D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2B5).withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
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
            ],
          ),
        ),
      ),
    );
  }

  // ─── QUICK ACTIONS ──────────────────────────────────────────────────────────
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1246A3).withAlpha(12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tap to report',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1246A3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildActionTile(
              context: context,
              emoji: '🥹',
              title: 'Report Lost',
              subtitle: 'Lost an item?',
              gradientColors: const [Color(0xFFFF5252), Color(0xFFE11D48)],
              shadowColor: const Color(0xFFFF5252),
              onTap: () => ReportItemModal.show(context, initialType: ReportType.lost),
            ),
            const SizedBox(width: 14),
            _buildActionTile(
              context: context,
              emoji: '🎉',
              title: 'Report Found',
              subtitle: 'Found an item?',
              gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
              shadowColor: const Color(0xFF10B981),
              onTap: () => ReportItemModal.show(context, initialType: ReportType.found),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 105,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withAlpha(70),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM STATS ───────────────────────────────────────────────────────────
  Widget _buildBottomStatsSection(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.dashboardHeaderGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLATFORM STATS',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF22C55E),
                    value: '12,483',
                    label: 'Items Returned',
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.manage_search_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    value: '3,291',
                    label: 'Active Cases',
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.track_changes_rounded,
                    iconColor: const Color(0xFFFF7675),
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

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(170),
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category Explorer Widget with 2 Expandable Cards (Lost Item & Found Item)
/// Summary items are only shown INSIDE the expanded card, not directly on the front page.
class _TopCategoryExplorerWidget extends StatefulWidget {
  const _TopCategoryExplorerWidget();

  @override
  State<_TopCategoryExplorerWidget> createState() => _TopCategoryExplorerWidgetState();
}

class _TopCategoryExplorerWidgetState extends State<_TopCategoryExplorerWidget> {
  String? _expandedCard; // null, 'lost', or 'found'
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Category Explorer'),
        const SizedBox(height: 14),

        // 1. Lost Item Card
        _buildExpandableCard(
          cardKey: 'lost',
          title: 'Lost Item',
          subtitle: 'Explore Lost Categories',
          emojiIcon: '🥹',
          gradient: AppColors.reportLostGradient,
          themeColor: AppColors.lostRedEnd,
          categoryLabel: '🥹 Select Lost Category:',
          panelBgColor: const Color(0xFFFFF0F3),
          reports: viewModel.lostReports,
          context: context,
        ),
        const SizedBox(height: 14),

        // 2. Found Item Card
        _buildExpandableCard(
          cardKey: 'found',
          title: 'Found Item',
          subtitle: 'Explore Found Categories',
          emojiIcon: '🎉',
          gradient: AppColors.reportFoundGradient,
          themeColor: AppColors.foundGreenEnd,
          categoryLabel: '🎉 Select Found Category:',
          panelBgColor: const Color(0xFFF0FDF4),
          reports: viewModel.foundReports,
          context: context,
        ),
      ],
    );
  }

  Widget _buildExpandableCard({
    required String cardKey,
    required String title,
    required String subtitle,
    required String emojiIcon,
    required LinearGradient gradient,
    required Color themeColor,
    required String categoryLabel,
    required Color panelBgColor,
    required List<ReportItem> reports,
    required BuildContext context,
  }) {
    final isExpanded = _expandedCard == cardKey;

    final filteredItems = _selectedCategoryEmoji == 'ALL'
        ? reports
        : reports.where((item) => item.emojiIcon == _selectedCategoryEmoji).toList();

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCard = isExpanded ? null : cardKey;
          _selectedCategoryEmoji = 'ALL';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withAlpha(80),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emojiIcon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withAlpha(220),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded Category & Summary Panel INSIDE the Card
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  decoration: BoxDecoration(
                    color: panelBgColor,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label & Count Badge
                      Row(
                        children: [
                          Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: themeColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredItems.length} Items',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Horizontal Category Chips inside the Card
                      SizedBox(
                        height: 68,
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
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? themeColor : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? themeColor : AppColors.borderColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: themeColor.withAlpha(40),
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
                                      style: const TextStyle(fontSize: 18),
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

                      // Filtered Items Summary List INSIDE the Card
                      const SizedBox(height: 14),
                      if (filteredItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  _selectedCategoryEmoji == 'ALL' ? '🔍' : _selectedCategoryEmoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No items in this category.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: themeColor.withAlpha(180),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filteredItems.map(
                          (item) => ReportItemCard(
                            item: item,
                            onTap: () => ItemDetailModal.show(context, item),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


