import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/gradient_button.dart';

/// Displayed right after authentication so the user understands how their
/// contact information, location, and lost/found data are protected.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        // Header Icon Badge
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0084FF), Color(0xFF00D2B5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withAlpha(70),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Privacy Notice',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please review how BackToOwner safeguards your personal data, identity, and reports.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Notice Cards
                        _buildNoticeItem(
                          icon: Icons.lock_person_outlined,
                          title: 'Contact Privacy',
                          description:
                              'Your phone number and email are encrypted and kept strictly confidential. Strangers in the public feed cannot see them unless you mutually approve a handover claim.',
                          iconColor: AppColors.primaryBlue,
                          iconBg: const Color(0xFFE5F2FF),
                        ),
                        const SizedBox(height: 14),

                        _buildNoticeItem(
                          icon: Icons.location_on_outlined,
                          title: 'Safe Location Sharing',
                          description:
                              'Only general campus zones or areas you select are displayed for lost and found reports. Your private residence or real-time GPS location is never broadcast.',
                          iconColor: const Color(0xFF0D9488),
                          iconBg: const Color(0xFFE6F8F6),
                        ),
                        const SizedBox(height: 14),

                        _buildNoticeItem(
                          icon: Icons.handshake_outlined,
                          title: 'Mutual Handover Verification',
                          description:
                              'Returning an item requires confirmation from both parties, protecting authentic owners and preventing unauthorized claims.',
                          iconColor: const Color(0xFF8B5CF6),
                          iconBg: const Color(0xFFF3E8FF),
                        ),
                        const SizedBox(height: 14),

                        _buildNoticeItem(
                          icon: Icons.shield_outlined,
                          title: 'Secure Account Data',
                          description:
                              'All authentication tokens and stored credentials follow industry best practices to prevent unauthorized access.',
                          iconColor: AppColors.primaryCyan,
                          iconBg: const Color(0xFFE0FBF7),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientButton(
                        text: 'OK',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/dashboard');
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap OK to continue to your dashboard',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeItem({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
