import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/clickable_stat_card.dart';
import 'package:sns_clocked_in/core/ui/collapsible_filter_section.dart';
import 'package:sns_clocked_in/core/ui/empty_state.dart';
import 'package:sns_clocked_in/core/ui/error_state.dart';
import 'package:sns_clocked_in/core/ui/list_skeleton.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/design_system/components/app_button.dart';
import 'package:sns_clocked_in/design_system/components/app_text_field.dart';
import 'package:sns_clocked_in/design_system/components/loading_button.dart';
import 'package:sns_clocked_in/design_system/components/app_snackbar.dart';
import 'package:sns_clocked_in/design_system/components/confirmation_dialog.dart';
import 'package:sns_clocked_in/design_system/components/app_search_bar.dart';
import 'package:sns_clocked_in/design_system/breakpoints.dart';

/// Component showcase screen displaying all design system components
///
/// Serves as living documentation and visual reference for all reusable components.
/// Accessible via debug menu at /debug/component-showcase
class ComponentShowcaseScreen extends StatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  State<ComponentShowcaseScreen> createState() => _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState extends State<ComponentShowcaseScreen> {
  final _searchController = TextEditingController();
  final _textController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _textController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      title: 'Component Showcase',
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buttons Section
            const SectionHeader('Buttons'),
            _buildButtonShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Cards Section
            const SectionHeader('Cards'),
            _buildCardShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Stat Cards Section
            const SectionHeader('Stat Cards'),
            _buildStatCardShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Input Fields Section
            const SectionHeader('Input Fields'),
            _buildInputShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Status Indicators Section
            const SectionHeader('Status Indicators'),
            _buildStatusShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // States Section
            const SectionHeader('States'),
            _buildStatesShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Filters Section
            const SectionHeader('Filters'),
            _buildFiltersShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Typography Section
            const SectionHeader('Typography'),
            _buildTypographyShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Spacing Section
            const SectionHeader('Spacing'),
            _buildSpacingShowcase(),
            const SizedBox(height: AppSpacing.xl),

            // Colors Section
            const SectionHeader('Colors'),
            _buildColorsShowcase(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppButton(
            label: 'Primary Button',
            onPressed: null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Primary Button (Active)',
            onPressed: () {
              AppSnackbar.showSuccess(context, 'Button pressed!');
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const AppButton(
            label: 'Primary Button (Loading)',
            onPressed: null,
            isLoading: true,
          ),
          const SizedBox(height: AppSpacing.md),
          const AppButton(
            label: 'Outlined Button',
            onPressed: null,
            isOutlined: true,
          ),
          const SizedBox(height: AppSpacing.md),
          LoadingButton(
            label: 'Loading Button',
            onPressed: () async {
              setState(() => _isLoading = true);
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                setState(() => _isLoading = false);
                AppSnackbar.showSuccess(context, 'Action completed!');
              }
            },
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildCardShowcase() {
    return Column(
      children: [
        AppCard(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standard Card',
                style: AppTypography.lightTextTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is a standard AppCard with padding and content.',
                style: AppTypography.lightTextTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: AppSpacing.lgAll,
          onTap: () {
            AppSnackbar.showInfo(context, 'Card tapped!');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clickable Card',
                style: AppTypography.lightTextTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap this card to see the ripple effect.',
                style: AppTypography.lightTextTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardShowcase() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const StatCard(
            title: 'Total',
            value: '42',
            icon: Icons.people,
            color: AppColors.primary,
            width: 140,
          ),
          const SizedBox(width: AppSpacing.md),
          const StatCard(
            title: 'Active',
            value: '38',
            icon: Icons.check_circle,
            color: AppColors.success,
            width: 140,
          ),
          const SizedBox(width: AppSpacing.md),
          const StatCard(
            title: 'Pending',
            value: '4',
            icon: Icons.schedule,
            color: AppColors.warning,
            width: 140,
          ),
          const SizedBox(width: AppSpacing.md),
          ClickableStatCard(
            title: 'Clickable',
            value: '12',
            icon: Icons.touch_app,
            color: AppColors.secondary,
            width: 140,
            isSelected: false,
            onTap: () {
              AppSnackbar.showInfo(context, 'Stat card tapped!');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _textController,
            labelText: 'Standard Text Field',
            hintText: 'Enter text here',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _passwordController,
            labelText: 'Password Field',
            hintText: 'Enter password',
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSearchBar(
            controller: _searchController,
            hintText: 'Search...',
            onChanged: (value) {
              // Search functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          StatusBadge(label: 'Approved', type: StatusBadgeType.approved),
          StatusBadge(label: 'Pending', type: StatusBadgeType.pending),
          StatusBadge(label: 'Rejected', type: StatusBadgeType.rejected),
          StatusBadge(label: 'Cancelled', type: StatusBadgeType.cancelled),
          StatusBadge(label: 'Compact', type: StatusBadgeType.approved, compact: true),
        ],
      ),
    );
  }

  Widget _buildStatesShowcase() {
    return Column(
      children: [
        AppCard(
          padding: AppSpacing.lgAll,
          child: const EmptyState(
            title: 'No Items Found',
            message: 'This is an empty state component. Use it when lists are empty.',
            icon: Icons.inbox_outlined,
            actionLabel: 'Add Item',
            onAction: null,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: AppSpacing.lgAll,
          child: ErrorState(
            title: 'Error Occurred',
            message: 'This is an error state component. Use it when operations fail.',
            onRetry: () {
              AppSnackbar.showInfo(context, 'Retry action triggered');
            },
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          padding: AppSpacing.lgAll,
          child: ListSkeleton(items: 3, itemHeight: 80),
        ),
      ],
    );
  }

  Widget _buildFiltersShowcase() {
    return CollapsibleFilterSection(
      title: 'Filters',
      initiallyExpanded: true,
      onClear: () {
        AppSnackbar.showInfo(context, 'Filters cleared');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: TextEditingController(),
            labelText: 'Search',
            hintText: 'Enter search term',
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(borderRadius: AppRadius.mediumAll),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildTypographyShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display Hero',
            style: AppTypography.lightTextTheme.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Title Large',
            style: AppTypography.lightTextTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Title Medium',
            style: AppTypography.lightTextTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Body Large - This is body large text used for primary content.',
            style: AppTypography.lightTextTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Body Medium - This is body medium text used for secondary content.',
            style: AppTypography.lightTextTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Body Small - This is body small text used for captions and helper text.',
            style: AppTypography.lightTextTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Label Small',
            style: AppTypography.lightTextTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSpacingShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpacingRow('XS (4dp)', AppSpacing.xs),
          _buildSpacingRow('S (8dp)', AppSpacing.s),
          _buildSpacingRow('M (12dp)', AppSpacing.m),
          _buildSpacingRow('L (16dp)', AppSpacing.l),
          _buildSpacingRow('XL (24dp)', AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSpacingRow(String label, double spacing) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.lightTextTheme.bodySmall,
            ),
          ),
          Container(
            width: spacing,
            height: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${spacing.toInt()}dp',
            style: AppTypography.lightTextTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorsShowcase() {
    return AppCard(
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildColorRow('Primary', AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Secondary', AppColors.secondary),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Success', AppColors.success),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Warning', AppColors.warning),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Error', AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Background', AppColors.background),
          const SizedBox(height: AppSpacing.sm),
          _buildColorRow('Surface', AppColors.surface),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.mediumAll,
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
