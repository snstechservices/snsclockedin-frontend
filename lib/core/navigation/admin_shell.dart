import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/core/navigation/more_bottom_nav.dart';
import 'package:sns_clocked_in/core/navigation/nav_config.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

/// Shell widget for admin role with bottom navigation
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final mainNavItems = NavConfig.adminMainNavItems;
    final moreNavItems = NavConfig.adminMoreNavItems;

    // Find selected index in main nav items
    // This handles deep-linking correctly (e.g., /a/leave/... still highlights Leave)
    final selectedIndex = mainNavItems.indexWhere(
      (item) => currentRoute == item.route || currentRoute.startsWith('${item.route}/'),
    );

    // Also check if current route is in "More" items (for highlighting when in More sheet routes)
    final isInMoreItems = moreNavItems.any(
      (item) => currentRoute == item.route || currentRoute.startsWith('${item.route}/'),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: MoreBottomNav(
        // If in a "More" route, highlight the "More" button (index 4)
        currentIndex: isInMoreItems
            ? mainNavItems.length
            : (selectedIndex >= 0 ? selectedIndex : 0),
        mainDestinations: mainNavItems,
        moreItems: moreNavItems,
        onDestinationSelected: (index) {
          if (index < mainNavItems.length) {
            context.go(mainNavItems[index].route);
          }
        },
        onMoreItemSelected: (route) {
          context.go(route);
        },
      ),
    );
  }
}

