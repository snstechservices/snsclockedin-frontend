import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/navigation/nav_config.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Reusable bottom navigation with "More" functionality
class MoreBottomNav extends StatelessWidget {
  const MoreBottomNav({
    super.key,
    required this.currentIndex,
    required this.mainDestinations,
    required this.moreItems,
    required this.onDestinationSelected,
    required this.onMoreItemSelected,
  });

  final int currentIndex;
  final List<NavItem> mainDestinations;
  final List<NavItem> moreItems;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onMoreItemSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine label behavior - only show selected to prevent wrapping
        final labelBehavior = NavigationDestinationLabelBehavior.onlyShowSelected;

        // Build main destinations (4 items)
        final destinations = <NavigationDestination>[
          ...mainDestinations.map((item) {
            return NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: item.label,
            );
          }),
          // "More" destination
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ];

        return NavigationBar(
          selectedIndex: currentIndex,
          labelBehavior: labelBehavior,
          onDestinationSelected: (index) {
            if (index < mainDestinations.length) {
              // Main destination tapped
              onDestinationSelected(index);
            } else if (index == mainDestinations.length) {
              // "More" tapped - open bottom sheet
              _showMoreBottomSheet(context);
            }
          },
          destinations: destinations,
        );
      },
    );
  }

  void _showMoreBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (sheetContext) => _MoreBottomSheet(
        items: moreItems,
        onItemSelected: (route) {
          Navigator.pop(sheetContext);
          onMoreItemSelected(route);
        },
      ),
    );
  }
}

class _MoreBottomSheet extends StatelessWidget {
  const _MoreBottomSheet({
    required this.items,
    required this.onItemSelected,
  });

  final List<NavItem> items;
  final ValueChanged<String> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: AppRadius.smAll,
            ),
          ),
          // Title
          Padding(
            padding: AppSpacing.lgAll,
            child: Row(
              children: [
                Text(
                  'More',
                  style: AppTypography.lightTextTheme.headlineMedium,
                ),
              ],
            ),
          ),
          // Items list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: AppColors.textPrimary,
                ),
                title: Text(
                  item.label,
                  style: AppTypography.lightTextTheme.bodyLarge,
                ),
                onTap: () => onItemSelected(item.route),
              );
            },
          ),
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

