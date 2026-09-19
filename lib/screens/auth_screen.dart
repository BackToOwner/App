import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_segmented_control.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthScreenContent();
  }
}

class _AuthScreenContent extends StatefulWidget {
  const _AuthScreenContent();

  @override
  State<_AuthScreenContent> createState() => _AuthScreenContentState();
}

class _AuthScreenContentState extends State<_AuthScreenContent> {
  final ImagePicker _picker = ImagePicker();
  // Kept client-side only: the backend's sign-up form takes an ID *number*, not a photo, so there
  // is nowhere to upload this yet. Attaching it at least gives the user a real, working capture
  // instead of a button that claimed to scan the card and did nothing.
  Uint8List? _idPhotoBytes;
  String? _idPhotoFileName;

  Future<void> _pickIdPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attach ID Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: AppColors.primaryBlue,
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: AppColors.primaryCyan,
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _idPhotoBytes = bytes;
        _idPhotoFileName = pickedFile.name;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ID photo attached: $_idPhotoFileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final mediaQuery = MediaQuery.of(context);
    final minHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: AppColors.darkNavyDeep,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 40, bottom: 40),
                  decoration: const BoxDecoration(
                    gradient: AppColors.authHeaderGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2652).withAlpha(220),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(40),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(80),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(
                                text: 'Back',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: 'To',
                                style: TextStyle(color: AppColors.primaryCyan),
                              ),
                              TextSpan(
                                text: 'Owner',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 24,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomSegmentedControl<bool>(
                          options: const [
                            SegmentedOption(value: true, label: 'Sign In'),
                            SegmentedOption(value: false, label: 'Sign Up'),
                          ],
                          selectedValue: controller.isSignIn,
                          onValueChanged: controller.setAuthMode,
                        ),
                        const SizedBox(height: 24),
                        CustomTextField(
                          label: 'Email Address',
                          hintText: 'you@example.com',
                          prefixIcon: Icons.mail_outline,
                          controller: controller.emailController,
                        ),
                        if (!controller.isSignIn) ...[
                          const SizedBox(height: 18),
                          CustomTextField(
                            label: 'Phone Number',
                            hintText: '+94 71 234 5678',
                            prefixIcon: Icons.phone_outlined,
                            controller: controller.phoneController,
                          ),
                          const SizedBox(height: 18),
                          CustomTextField(
                            label: 'ID Verification Number',
                            hintText: 'e.g. 200012345678',
                            prefixIcon: Icons.badge_outlined,
                            controller: controller.idVerificationController,
                            suffixWidget: IconButton(
                              tooltip: _idPhotoBytes == null ? 'Attach a photo of your ID' : 'Photo attached',
                              onPressed: _pickIdPhoto,
                              icon: Icon(
                                _idPhotoBytes == null ? Icons.camera_alt_outlined : Icons.check_circle,
                                color: _idPhotoBytes == null ? AppColors.primaryBlue : AppColors.foundThemeStart,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (controller.errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withAlpha(24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.errorRed.withAlpha(90)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    controller.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.errorRed,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        CustomTextField(
                          label: 'Password',
                          hintText: 'Min 8 characters',
                          prefixIcon: Icons.lock_outline,
                          obscureText: controller.obscurePassword,
                          controller: controller.passwordController,
                          suffixWidget: TextButton(
                            onPressed: controller.togglePasswordVisibility,
                            child: Text(
                              controller.obscurePassword ? 'Show' : 'Hide',
                              style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final message = await controller.requestPasswordReset();
                              messenger.showSnackBar(SnackBar(content: Text(message)));
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GradientButton(
                          text: controller.isSignIn ? 'Sign In' : 'Sign Up',
                          onPressed: controller.isLoading
                              ? null
                              : () => controller.submitAuth(context),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.borderColor),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'or continue with',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.borderColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        OutlinedButton(
                          onPressed: controller.isLoading
                              ? null
                              : () => controller.submitGoogleAuth(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.fieldBackground,
                            side: const BorderSide(
                              color: AppColors.borderColor,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
