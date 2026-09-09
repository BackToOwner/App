import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/stats_viewmodel.dart';
import '../widgets/custom_bottom_nav.dart';

import '../widgets/report_item_modal.dart';
import 'found_screen.dart';
import 'lost_screen.dart';
import 'notifications_screen.dart';
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

class _DashboardHomeView extends StatefulWidget {
  const _DashboardHomeView();

  @override
  State<_DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<_DashboardHomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // Both are independent; a failing stats call must not stop the feed loading.
    await Future.wait([
      context.read<DashboardViewModel>().refresh(),
      context.read<StatsViewModel>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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

                // 3. Browse Items (Lost Items / Found Items)
                _buildBrowseItemsSection(context),
              ],
            ),
          ),

          // 4. Platform Statistics Footer Section
          _buildBottomStatsSection(context),
        ],
      ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Utility Row: Brand Mark + Notification + Avatar
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white.withAlpha(35), width: 1),
                    ),
                    child: Image.asset('assets/images/app_logo.png'),
                  ),
                  const SizedBox(width: 10),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      children: [
                        TextSpan(text: 'Back', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'To', style: TextStyle(color: AppColors.primaryCyan)),
                        TextSpan(text: 'Owner', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Notification Bell Button
                  _HeaderIconButton(
                    icon: Icons.notifications_outlined,
                    showBadge: true,
                    tooltip: 'Notifications',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Avatar — taps through to the Profile tab
                  _HeaderIconButton(
                    tooltip: 'Profile',
                    onTap: () => context.read<DashboardViewModel>().setNavIndex(3),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D2B5), Color(0xFF00A99D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: const Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Greeting Block
              Text(
                _greetingForNow(),
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.watch<ProfileViewModel>().user?.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
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
              gradientColors: const [AppColors.lostRedStart, AppColors.lostRedEnd],
              shadowColor: AppColors.lostRedEnd,
              onTap: () => ReportItemModal.show(context, initialType: ReportType.lost),
            ),
            const SizedBox(width: 14),
            _buildActionTile(
              context: context,
              emoji: '🎉',
              title: 'Report Found',
              subtitle: 'Found an item?',
              gradientColors: const [AppColors.foundGreenStart, AppColors.foundGreenEnd],
              shadowColor: AppColors.foundGreenEnd,
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

  // ─── BROWSE ITEMS ───────────────────────────────────────────────────────────
  Widget _buildBrowseItemsSection(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildBrowseTile(
              icon: Icons.inventory_2_outlined,
              title: 'Lost Items',
              subtitle: '${viewModel.lostReports.length} reported',
              themeColor: AppColors.lostRedEnd,
              onTap: () => viewModel.setNavIndex(1),
            ),
            const SizedBox(width: 14),
            _buildBrowseTile(
              icon: Icons.task_alt_rounded,
              title: 'Found Items',
              subtitle: '${viewModel.foundReports.length} reported',
              themeColor: AppColors.foundGreenEnd,
              onTap: () => viewModel.setNavIndex(2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrowseTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: themeColor.withAlpha(60), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: themeColor.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: themeColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: themeColor, size: 19),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.darkNavy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
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

  // ─── BOTTOM STATS ───────────────────────────────────────────────────────────
  Widget _buildBottomStatsSection(BuildContext context) {
    final stats = context.watch<StatsViewModel>();
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
                    value: stats.itemsReturned,
                    label: 'Items Returned',
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.manage_search_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    value: stats.activeCases,
                    label: 'Active Cases',
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.track_changes_rounded,
                    iconColor: const Color(0xFFFF7675),
                    value: stats.successRate,
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

/// Circular header button used for the notification bell and avatar.
/// Gives proper tactile ripple feedback on tap instead of a bare GestureDetector.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.tooltip,
    this.icon,
    this.gradient,
    this.child,
    this.showBadge = false,
  });

  final VoidCallback onTap;
  final String tooltip;
  final IconData? icon;
  final LinearGradient? gradient;
  final Widget? child;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? Colors.white.withAlpha(20) : null,
          shape: BoxShape.circle,
          border: gradient == null
              ? Border.all(color: Colors.white.withAlpha(30), width: 1)
              : null,
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: gradient!.colors.first.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withAlpha(60),
              highlightColor: Colors.white.withAlpha(30),
              child: Center(
                child: showBadge
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(icon, color: Colors.white, size: 22),
                          Positioned(
                            right: -1,
                            top: -1,
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
                      )
                    : child ?? Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
