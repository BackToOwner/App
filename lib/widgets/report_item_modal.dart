import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'custom_text_field.dart';
import 'gradient_button.dart';

class ReportItemModal extends StatefulWidget {
  final ReportType initialType;

  const ReportItemModal({
    super.key,
    this.initialType = ReportType.lost,
  });

  static void show(BuildContext context, {ReportType initialType = ReportType.lost}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportItemModal(initialType: initialType),
    );
  }

  @override
  State<ReportItemModal> createState() => _ReportItemModalState();
}

class _ReportItemModalState extends State<ReportItemModal> {
  late ReportType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _campusController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _additionalDetailsController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  String? _imageFileName;

  final List<String> _emojis = ['👛', '📱', '🐕', '🔑', '🎒', '🎧', '💻', '🕶️', '⌚', '💼'];
  late String _selectedEmoji;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedEmoji = _emojis[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _colorController.dispose();
    _campusController.dispose();
    _areaController.dispose();
    _additionalDetailsController.dispose();
    _rewardController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  /// Shows a bottom sheet to pick from Camera or Gallery.
  void _showImagePickerOptions() {
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
              'Upload Image',
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
          _imageFileName = pickedFile.name;
          _imageController.text = _imageFileName!;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image attached: $_imageFileName'),
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

  void _submitReport() {
    final title = _titleController.text.trim();
    final itemColor = _colorController.text.trim();
    final campus = _campusController.text.trim();
    final area = _areaController.text.trim();
    final additionalDetails = _additionalDetailsController.text.trim();
    final rewardText = _rewardController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item title.')),
      );
      return;
    }

    if (campus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the campus.')),
      );
      return;
    }

    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the area.')),
      );
      return;
    }

    final newItem = ReportItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      itemColor: itemColor.isNotEmpty ? itemColor : null,
      campus: campus,
      area: area,
      additionalDetails: additionalDetails.isNotEmpty ? additionalDetails : null,
      type: _selectedType,
      timeAgo: 'Just now',
      reward: rewardText.isNotEmpty ? (rewardText.contains('reward') ? rewardText : '$rewardText reward') : null,
      emojiIcon: _selectedEmoji,
      iconBgHex: _selectedType == ReportType.lost ? 'FFF0F5' : 'E6F9F3',
    );

    context.read<DashboardViewModel>().addReport(newItem);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully reported: "$title"'),
        backgroundColor: AppColors.foundGreenStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isLost = _selectedType == ReportType.lost;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Grab Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Modal Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLost ? 'Report Lost Item 🥹' : 'Report Found Item 🎉',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Form Field: Title
            CustomTextField(
              label: 'Item Title *',
              hintText: isLost ? 'e.g. Leather Wallet, Laptop Bag' : 'e.g. iPhone 15, Car Keys',
              prefixIcon: Icons.shopping_bag_outlined,
              controller: _titleController,
            ),
            const SizedBox(height: 14),

            // Form Field: Item Color (Optional)
            CustomTextField(
              label: 'Item Color',
              hintText: 'e.g. Black, Silver, Red',
              prefixIcon: Icons.palette_outlined,
              controller: _colorController,
            ),
            const SizedBox(height: 14),

            // Form Field: Location — Campus & Area
            const Text(
              'Location *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Campus',
                    hintText: 'e.g. BCI',
                    prefixIcon: Icons.school_outlined,
                    controller: _campusController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Area',
                    hintText: 'e.g. CRK 2',
                    prefixIcon: Icons.place_outlined,
                    controller: _areaController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Form Field: Additional Details (Optional)
            CustomTextField(
              label: 'Additional Details (Optional)',
              hintText: 'e.g. Near the computers on the second floor',
              prefixIcon: Icons.info_outline,
              controller: _additionalDetailsController,
            ),
            const SizedBox(height: 14),

            // Form Field: Upload Image (Camera / Gallery picker)
            const Text(
              'Upload Image',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.fieldBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor, width: 1.2),
                ),
                child: _pickedImage != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15)),
                            child: Image.file(
                              _pickedImage!,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.camera_alt_outlined,
                                    color: AppColors.primaryBlue, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _imageFileName ?? 'Image attached',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.edit,
                                    color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Take photo or upload image',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(Icons.add_a_photo_outlined,
                                color: AppColors.primaryBlue, size: 20),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Form Field: Reward (Optional)
            if (isLost) ...[
              CustomTextField(
                label: 'Reward Amount (Optional)',
                hintText: 'e.g. \$50 or \$100',
                prefixIcon: Icons.card_giftcard,
                controller: _rewardController,
              ),
              const SizedBox(height: 14),
            ],

            // Category Emoji Selector
            const Text(
              'Select Item Icon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  final isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isLost ? AppColors.lostBadgeBg : AppColors.foundBadgeBg)
                            : AppColors.fieldBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? (isLost ? AppColors.lostRedEnd : AppColors.foundGreenEnd)
                              : AppColors.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Action Button: Submit Report
            GradientButton(
              text: isLost ? 'Upload Lost Report' : 'Upload Found Report',
              gradient: isLost ? AppColors.reportLostGradient : AppColors.reportFoundGradient,
              onPressed: _submitReport,
            ),
          ],
        ),
      ),
    );
  }
}
