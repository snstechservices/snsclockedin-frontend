import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Collapsible filter section widget
///
/// Features:
/// - Expandable/collapsible container
/// - Filter icon and title
/// - Chevron indicator
/// - Contains filter controls (date buttons, dropdowns, etc.)
/// - White card with shadow
/// - Optional clear filters button
///
/// Example usage:
/// ```dart
/// CollapsibleFilterSection(
///   title: 'Filters',
///   initiallyExpanded: true,
///   onClear: () {
///     // Clear all filters
///   },
///   child: Column(
///     children: [
///       // Filter widgets here
///     ],
///   ),
/// )
/// ```
class CollapsibleFilterSection extends StatefulWidget {
  const CollapsibleFilterSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.onClear,
  });

  /// Section title
  final String title;

  /// Filter controls content (date buttons, dropdowns, etc.)
  final Widget child;

  /// Whether section is initially expanded (default: true)
  final bool initiallyExpanded;

  /// Optional clear filters callback
  final VoidCallback? onClear;

  @override
  State<CollapsibleFilterSection> createState() => _CollapsibleFilterSectionState();
}

class _CollapsibleFilterSectionState extends State<CollapsibleFilterSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: AppSpacing.mdAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and chevron
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: _toggleExpanded,
                tooltip: _isExpanded ? 'Collapse Filters' : 'Expand Filters',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          // Collapsible content
          if (_isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            widget.child,
            // Clear button (if provided)
            if (widget.onClear != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    padding: AppSpacing.smAll,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
