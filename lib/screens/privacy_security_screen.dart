import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/api/api_exception.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Privacy & Security screen with password change fields.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _changePassword() async {
    if (_isSaving) return;
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnackBar('Please fill in all fields.', AppColors.lostRedEnd);
      return;
    }

    if (newPass.length < 8) {
      _showSnackBar(
          'New password must be at least 8 characters.', AppColors.lostRedEnd);
      return;
    }

    if (newPass != confirm) {
      _showSnackBar('New passwords do not match.', AppColors.lostRedEnd);
      return;
    }

    // Simulate password change
    setState(() => _isSaving = true);
    try {
      await context.read<ProfileViewModel>().changePassword(
            currentPassword: current,
            newPassword: newPass,
          );
      if (!mounted) return;
      _showSnackBar('Password changed successfully!', AppColors.foundGreenEnd);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message, AppColors.lostRedEnd);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header: Change Password ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha(14),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primaryBlue.withAlpha(40)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline,
                      color: AppColors.primaryBlue, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Current Password ──
            _buildFieldLabel('Current Password'),
            const SizedBox(height: 6),
            _buildPasswordField(
              controller: _currentPasswordController,
              hintText: 'Enter current password',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 18),

            // ── New Password ──
            _buildFieldLabel('New Password'),
            const SizedBox(height: 6),
            _buildPasswordField(
              controller: _newPasswordController,
              hintText: 'Enter new password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 18),

            // ── Confirm New Password ──
            _buildFieldLabel('Confirm New Password'),
            const SizedBox(height: 6),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hintText: 'Re-enter new password',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 32),

            // ── Change Password Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.darkNavy.withAlpha(80),
                ),
                child: const Text(
                  'CHANGE PASSWORD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.lock_outline,
            color: AppColors.textMuted, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
    );
  }
}
