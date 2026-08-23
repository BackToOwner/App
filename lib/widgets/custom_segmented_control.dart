import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SegmentedOption<T> {
  final T value;
  final String label;
  final LinearGradient? activeGradient;

  const SegmentedOption({
    required this.value,
    required this.label,
    this.activeGradient,
  });
}

class CustomSegmentedControl<T> extends StatelessWidget {
  final List<SegmentedOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final Color activeColor;
  final double height;

  const CustomSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onValueChanged,
    this.activeColor = AppColors.primaryBlue,
    this.height = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onValueChanged(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected && option.activeGradient == null
                      ? activeColor
                      : Colors.transparent,
                  gradient: isSelected ? option.activeGradient : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
