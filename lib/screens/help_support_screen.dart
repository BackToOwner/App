import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../viewmodels/support_viewmodel.dart';

/// Help & Support screen.
///
/// Contact details, social links and FAQ copy come from the backend (`/config` and `/faqs`), so
/// support can change a phone number without shipping a new build.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final support = context.watch<SupportViewModel>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contact Us Section ──
            _buildSectionHeader(Icons.headset_mic_outlined, 'Contact Us'),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone_outlined,
              title: 'Hotline',
              subtitle: support.config('hotline', fallback: '—'),
              trailing: support.config('hotlineHours', fallback: ''),
              trailingColor: AppColors.foundGreenEnd,
            ),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: support.config('supportEmail', fallback: '—'),
              trailing: support.config('supportReplyTime', fallback: ''),
              trailingColor: AppColors.primaryBlue,
            ),
            _buildContactCard(
              icon: Icons.chat_bubble_outline,
              title: 'Live Chat',
              subtitle: 'Chat with our team',
              trailing: '9AM – 9PM',
              trailingColor: AppColors.primaryCyan,
            ),
            const SizedBox(height: 24),

            // ── Emergency Contact ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.lostRedEnd.withAlpha(40), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lostRedEnd.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emergency_outlined,
                        color: AppColors.lostRedEnd, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency? Call Police',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lostRedEnd,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '119 (Sri Lanka Police)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.call, color: AppColors.lostRedEnd, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── How It Works ──
            _buildSectionHeader(Icons.lightbulb_outline, 'How It Works'),
            const SizedBox(height: 12),
            _buildStepCard(
              stepNumber: '1',
              title: 'Report Lost or Found Item',
              description:
                  'Fill in the item details, upload a photo, and submit your report.',
              color: AppColors.primaryBlue,
            ),
            _buildStepCard(
              stepNumber: '2',
              title: 'We Match Items',
              description:
                  'Our system automatically compares lost and found reports to find potential matches.',
              color: AppColors.primaryCyan,
            ),
            _buildStepCard(
              stepNumber: '3',
              title: 'Get Connected',
              description:
                  'When a match is found, both parties are notified to arrange a safe return.',
              color: AppColors.foundGreenEnd,
            ),
            const SizedBox(height: 24),

            // ── FAQs ──
            _buildSectionHeader(Icons.quiz_outlined, 'Frequently Asked Questions'),
            const SizedBox(height: 12),
            if (support.isLoading && support.faqs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (support.faqs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Help topics could not be loaded. Pull down on the dashboard to retry.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              ...support.faqs.map(
                (faq) => _buildFaqTile(question: faq.question, answer: faq.answer),
              ),
            const SizedBox(height: 24),

            // ── Follow Us ──
            _buildSectionHeader(Icons.share_outlined, 'Follow Us'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(Icons.facebook, 'Facebook',
                    const Color(0xFF1877F2)),
                _buildSocialButton(Icons.camera_alt_outlined, 'Instagram',
                    const Color(0xFFE4405F)),
                _buildSocialButton(Icons.alternate_email, 'Twitter',
                    const Color(0xFF1DA1F2)),
                _buildSocialButton(Icons.language, 'Website',
                    AppColors.primaryCyan),
              ],
            ),
            const SizedBox(height: 24),

            // ── App Info ──
            Center(
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BackToOwner v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '© 2026 BackToOwner. All rights reserved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Helper Builders ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withAlpha(35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: trailingColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: trailingColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trailingColor.withAlpha(16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: trailingColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _buildFaqTile({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.help_outline,
              color: AppColors.primaryBlue, size: 16),
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(50), width: 1),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
