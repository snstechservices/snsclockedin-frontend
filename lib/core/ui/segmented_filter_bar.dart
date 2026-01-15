import 'package:flutter/material.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

class FilterOption<T> {
  const FilterOption({required this.label, required this.value});

  final String label;
  final T value;
}

class SegmentedFilterBar<T> extends StatelessWidget {
  const SegmentedFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.padding,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final contentPadding = padding ??
        const EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    return Padding(
      padding: contentPadding,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: options.map((opt) {
            final isSelected = opt.value == selected;
            return Expanded(
              child: _SegmentButton(
                label: opt.label,
                isSelected: isSelected,
                onPressed: () => onChanged(opt.value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.lgAll,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onPressed,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                label,
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

