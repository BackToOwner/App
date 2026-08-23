import 'package:flutter/material.dart';
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
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
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
    _locationController.dispose();
    _rewardController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _requestCameraAccess() {
    setState(() {
      _imageFileName = 'captured_photo_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}.jpg';
      _imageController.text = _imageFileName!;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Camera access granted. Image attached: $_imageFileName'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _submitReport() {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final rewardText = _rewardController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item title.')),
      );
      return;
    }

    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the location.')),
      );
      return;
    }

    final newItem = ReportItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      location: location,
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

            // Form Field: Location
            CustomTextField(
              label: 'Location *',
              hintText: 'e.g. Central Park, NY or Terminal 2',
              prefixIcon: Icons.location_on_outlined,
              controller: _locationController,
            ),
            const SizedBox(height: 14),

            // Form Field: Upload Image (Requests Camera Access)
            CustomTextField(
              label: 'Upload Image',
              hintText: _imageFileName ?? 'Take photo or upload image',
              prefixIcon: Icons.camera_alt_outlined,
              controller: _imageController,
              suffixWidget: IconButton(
                onPressed: _requestCameraAccess,
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.primaryBlue,
                  size: 20,
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
