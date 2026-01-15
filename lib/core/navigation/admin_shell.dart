import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/navigation/app_drawer.dart';
import 'package:sns_clocked_in/core/navigation/nav_config.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/features/profile/application/profile_store.dart';

/// Shell widget for admin role with left-side drawer navigation
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final appState = context.watch<AppState>();
    final profileStore = context.watch<ProfileStore>();
    final profile = profileStore.profile;
    final drawerNavItems = NavConfig.drawerNavItemsV2ForRole(Role.admin);
    final sectionTitle = NavConfig.getTitleForRoute(currentRoute, Role.admin) ?? 'Dashboard';

    return AppScreenScaffold(
      title: sectionTitle,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          color: AppColors.textPrimary,
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: kDebugMode
          ? [
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                color: AppColors.textPrimary,
                tooltip: 'Debug Harness',
                onPressed: () => context.go('/debug'),
              ),
            ]
          : null,
      drawer: AppDrawer(
        items: drawerNavItems,
        currentLocation: currentRoute,
        role: Role.admin,
        userName: profile.fullName,
        userEmail: profile.email,
        companyName: 'S&S Accounting', // TODO: Get from company store/state
        onLogout: () {
          appState.logout();
          context.go('/login');
        },
      ),
      skipScaffold: false,
      child: child,
    );
  }
}


