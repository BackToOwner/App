import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';
import '../models/item_category.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../controllers/dashboard_controller.dart';
import 'custom_text_field.dart';
import 'gradient_button.dart';

class ReportItemModal extends StatefulWidget {
  final ReportType initialType;

  const ReportItemModal({super.key, this.initialType = ReportType.lost});

  static void show(
    BuildContext context, {
    ReportType initialType = ReportType.lost,
  }) {
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
  final TextEditingController _additionalDetailsController =
      TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  // Bytes rather than a File/path: `dart:io.File` and file paths don't exist on Flutter Web, and
  // `XFile.readAsBytes()` is the one accessor image_picker guarantees on every platform.
  Uint8List? _pickedImageBytes;
  String? _imageFileName;

  /// Active categories are loaded from the shared Supabase categories table.
  List<ItemCategory> _categories = [];
  String? _selectedCategory;
  bool _categoriesLoading = true;
  String? _categoryLoadError;

  static const List<String> _fallbackCategoryIds = [
    'electronics',
    'wallets',
    'pets',
    'keys',
    'bags',
    'documents',
    'jewelry',
    'clothing',
    'other',
  ];

  Future<void> _loadCategories() async {
    try {
      final rows = await context.read<ApiClient>().get<List<dynamic>>(
        '/categories',
        skipAuth: true,
      );

      final loaded = rows
          .whereType<Map>()
          .map((row) => ItemCategory.fromJson(Map<String, dynamic>.from(row)))
          .where(
            (category) => category.id.isNotEmpty && category.label.isNotEmpty,
          )
          .toList();

      if (loaded.isEmpty) {
        throw StateError('The server returned no active categories.');
      }

      if (!mounted) return;
      setState(() {
        _categories = loaded;
        if (!_categories.any((c) => c.id == _selectedCategory)) {
          _selectedCategory = _categories.first.id;
        }
        _categoriesLoading = false;
        _categoryLoadError = null;
      });
    } catch (error) {
      debugPrint('[CATEGORIES] Failed to load live categories: $error');
      if (!mounted) return;

      // Keep reporting usable if the backend is temporarily unreachable.
      setState(() {
        _categories = _fallbackCategoryIds
            .map(
              (id) => ItemCategory(
                id: id,
                label: id[0].toUpperCase() + id.substring(1),
                icon: id,
                color: '#00D2B4',
              ),
            )
            .toList();
        _selectedCategory ??= _categories.first.id;
        _categoriesLoading = false;
        _categoryLoadError = 'Could not refresh categories. Using defaults.';
      });
    }
  }

  IconData _categoryIcon(ItemCategory category) {
    switch (category.icon.toLowerCase()) {
      case 'shirt':
      case 'clothing':
        return Icons.checkroom;
      case 'briefcase':
      case 'bags':
        return Icons.backpack;
      case 'smartphone':
      case 'electronics':
        return Icons.smartphone;
      case 'watch':
      case 'jewelry':
        return Icons.watch;
      case 'key':
      case 'keys':
        return Icons.vpn_key;
      case 'baby':
      case 'kids':
        return Icons.child_care;
      case 'filetext':
      case 'documents':
        return Icons.description;
      case 'umbrella':
        return Icons.umbrella;
      case 'wallet':
      case 'wallets':
        return Icons.account_balance_wallet;
      case 'pets':
        return Icons.pets;
      default:
        return ReportItem.iconForCategory(category.id);
    }
  }

  Color _categoryColor(String value) {
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? AppColors.primaryBlue : Color(parsed);
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadCategories();
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
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
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
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    if (_categoriesLoading ||
        _selectedCategory == null ||
        _categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories are still loading. Please try again.'),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final itemColor = _colorController.text.trim();
    final campus = _campusController.text.trim();
    final area = _areaController.text.trim();
    final additionalDetails = _additionalDetailsController.text.trim();
    final rewardText = _rewardController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (title.length < 3) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter an item title (at least 3 characters).'),
        ),
      );
      return;
    }

    if (campus.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter the campus.')),
      );
      return;
    }

    if (area.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter the area.')),
      );
      return;
    }

    // The field is free text ("$50", "5000 reward"); keep only the number the API expects.
    final rewardDigits = rewardText.replaceAll(RegExp(r'[^0-9.]'), '');
    final reward = rewardDigits.isEmpty ? null : double.tryParse(rewardDigits);
    debugPrint(
      '[REWARD TRACE form] raw=[$rewardText], digits=[$rewardDigits], parsed=[$reward]',
    );

    setState(() => _isSubmitting = true);
    try {
      await context.read<DashboardController>().addReport(
        title: title,
        type: _selectedType,
        campus: campus,
        area: area,
        itemColor: itemColor.isNotEmpty ? itemColor : null,
        additionalDetails: additionalDetails.isNotEmpty
            ? additionalDetails
            : null,
        category: _selectedCategory!,
        reward: reward,
        imageBytes: _pickedImageBytes,
        imageFileName: _imageFileName,
      );

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully reported: "$title"'),
          backgroundColor: AppColors.foundThemeStart,
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                  isLost ? 'Report Lost Item' : 'Report Found Item',
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
              hintText: isLost
                  ? 'e.g. Leather Wallet, Laptop Bag'
                  : 'e.g. iPhone 15, Car Keys',
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

            // Form Field: Upload Image (Camera / Gallery picker) — optional, so a submission
            // never blocks on it: the report is created either way, and the photo is a second,
            // best-effort request (see ApiReportRepository.addReport).
            const Text(
              'Upload Image (Optional)',
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
                child: _pickedImageBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            child: Image.memory(
                              _pickedImageBytes!,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
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
                                const Icon(
                                  Icons.edit,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
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
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
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
                hintText: 'e.g. LKR 5,000',
                prefixIcon: Icons.card_giftcard,
                controller: _rewardController,
              ),
              const SizedBox(height: 14),
            ],

            // Category selector backed by the live categories endpoint.
            const Text(
              'Select Item Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_categoriesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              if (_categoryLoadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _categoryLoadError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              SizedBox(
                height: 94,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category.id;
                    final categoryColor = _categoryColor(category.color);
                    final themeColor = isSelected
                        ? categoryColor
                        : (isLost
                              ? AppColors.lostThemeStart
                              : AppColors.foundThemeStart);

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = category.id),
                      child: Container(
                        width: 82,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? categoryColor.withAlpha(24)
                              : AppColors.fieldBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? categoryColor
                                : AppColors.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _categoryIcon(category),
                              size: 23,
                              color: themeColor,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              category.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Button: Submit Report
            GradientButton(
              text: isLost ? 'Upload Lost Report' : 'Upload Found Report',
              gradient: isLost
                  ? AppColors.reportLostGradient
                  : AppColors.reportFoundGradient,
              // Disabled mid-flight so a double tap cannot file the report twice.
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
        ),
      ),
    );
  }
}
