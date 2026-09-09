import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth/auth_service_interface.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'my_reports_screen.dart';
import 'privacy_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh from the server so counters stay accurate after filing or returning an item.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().load();
    });
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await context.read<IAuthService>().signOut();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ProfileViewModel>().user;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.read<DashboardViewModel>().setNavIndex(0);
          },
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Avatar (tappable to edit profile) ──
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                ),
                child: user?.avatar != null
                    ? ClipOval(
                        child: Image.network(
                          user!.avatar!,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) => _avatarInitial(user.initial),
                        ),
                      )
                    : _avatarInitial(user?.initial ?? '?'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.name ?? 'Loading…',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),

            // Real activity counters, straight from the user's row.
            if (user != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('Reported', user.itemsReported),
                  _buildStat('Found', user.itemsFound),
                  _buildStat('Returned', user.itemsReturned),
                ],
              ),
            const SizedBox(height: 24),

            _buildProfileOption(Icons.description_outlined, 'My Reports', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyReportsScreen()),
              );
            }),

            // ── Edit Profile ──
            _buildProfileOption(Icons.edit, 'Edit Profile', () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            }),

            // ── Privacy & Security (password change) ──
            _buildProfileOption(Icons.security, 'Privacy & Security', () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacySecurityScreen(),
                ),
              );
            }),

            _buildProfileOption(Icons.help_outline, 'Help & Support', () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen(),
                ),
              );
            }),
            const SizedBox(height: 16),
            _buildProfileOption(Icons.logout, 'Log Out', _signOut, textColor: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _avatarInitial(String initial) => Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
        ),
      );

  Widget _buildStat(String label, int value) => Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildProfileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? AppColors.primaryBlue),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 18,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
