import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/core/navigation/nav_config.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';

/// Shell widget for super admin role with drawer navigation
class SuperAdminShell extends StatelessWidget {
  const SuperAdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final navItems = NavConfig.superAdminNavItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'System Management',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ...navItems.map((item) {
              final isSelected = item.route == currentRoute;
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: isSelected ? AppColors.primary : null,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : null,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
                selected: isSelected,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.route);
                },
              );
            }),
          ],
        ),
      ),
      body: child,
    );
  }
}

