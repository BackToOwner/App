import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/api/api_exception.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Screen that lets the user edit their profile details.
/// Avatar photo can be updated via camera or gallery using image_picker.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    final user = context.read<ProfileViewModel>().user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email ?? '';
      _mobileController.text = user.phone ?? '';
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final profile = context.read<ProfileViewModel>();

    setState(() => _isSaving = true);
    try {
      await profile.updateProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _mobileController.text,
      );

      // The photo is a separate endpoint, so it only uploads when one was picked.
      final image = _profileImage;
      if (image != null) await profile.uploadAvatar(image.path);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppColors.foundGreenEnd,
        ),
      );
      navigator.pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.lostRedEnd),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  /// Shows a bottom sheet letting the user choose Camera or Gallery.
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
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
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: AppColors.primaryCyan,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo selected — tap SAVE to upload it.'),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.lostRedEnd,
          ),
        );
      }
    }
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
          'User Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Avatar with camera icon ──
            Center(
              child: GestureDetector(
                onTap: _showImagePickerOptions,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderColor,
                          width: 3,
                        ),
                        color: AppColors.primaryCyan,
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? Center(
                              child: Text(
                                context.watch<ProfileViewModel>().user?.initial ?? '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ── First Name ──
            _buildFieldLabel('First Name'),
            const SizedBox(height: 6),
            _buildTextField(_firstNameController),
            const SizedBox(height: 18),

            // ── Last Name ──
            _buildFieldLabel('Last Name'),
            const SizedBox(height: 6),
            _buildTextField(_lastNameController),
            const SizedBox(height: 18),

            // ── E-Mail ──
            _buildFieldLabel('E-Mail'),
            const SizedBox(height: 6),
            _buildTextField(
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),

            // ── Mobile ──
            _buildFieldLabel('Mobile'),
            const SizedBox(height: 6),
            _buildTextField(
              _mobileController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 36),

            // ── SAVE Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.darkNavy.withAlpha(80),
                ),
                child: Text(
                  _isSaving ? 'SAVING…' : 'SAVE',
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

  Widget _buildTextField(
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
