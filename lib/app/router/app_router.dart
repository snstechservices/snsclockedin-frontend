import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/core/navigation/admin_shell.dart';
import 'package:sns_clocked_in/core/navigation/employee_shell.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/features/admin/dashboard/presentation/admin_dashboard_screen.dart';
import 'package:sns_clocked_in/features/employees/presentation/admin_employees_screen.dart';
import 'package:sns_clocked_in/features/admin/presentation/reports_screen.dart';
import 'package:sns_clocked_in/features/admin/presentation/settings_screen.dart';
import 'package:sns_clocked_in/features/attendance/presentation/my_attendance_screen.dart';
import 'package:sns_clocked_in/features/auth/presentation/login_screen.dart';
import 'package:sns_clocked_in/features/unsupported/presentation/unsupported_screen.dart';
import 'package:sns_clocked_in/features/debug/presentation/debug_menu_screen.dart';
import 'package:sns_clocked_in/features/employee/dashboard/presentation/employee_dashboard_screen.dart';
import 'package:sns_clocked_in/features/leave/presentation/admin_leave_screen.dart';
import 'package:sns_clocked_in/features/leave/presentation/apply_leave_screen.dart';
import 'package:sns_clocked_in/features/leave/presentation/leave_list_screen.dart';
import 'package:sns_clocked_in/features/notifications/presentation/notifications_screen.dart';
import 'package:sns_clocked_in/features/profile/presentation/profile_screen.dart';
import 'package:sns_clocked_in/features/onboarding/presentation/onboarding_screen.dart';
import 'package:sns_clocked_in/features/splash/presentation/splash_screen.dart';

class AppRouter {
  AppRouter._();

  /// Create router with guards based on app state
  static GoRouter createRouter(AppState appState) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: appState,
      redirect: (context, state) {
        final isBootstrapped = appState.isBootstrapped;
        final isAuthenticated = appState.isAuthenticated;
        final location = state.uri.path;

        // If not bootstrapped, only allow splash
        if (!isBootstrapped) {
          return location == '/' ? null : '/';
        }

        // Use cached onboarding status (loaded during bootstrap) - synchronous!
        final hasSeenOnboarding = appState.hasSeenOnboarding;

        // If onboarding NOT seen: only allow /onboarding and /debug
        if (!hasSeenOnboarding) {
          if (location == '/onboarding' || (kDebugMode && location == '/debug')) {
            return null;
          }
          return '/onboarding';
        }

        // If onboarding seen and user not authenticated: allow /login and /debug
        if (!isAuthenticated) {
          if (location == '/login' || (kDebugMode && location == '/debug')) {
            return null;
          }
          // Redirect /home to /login if not authenticated
          if (location == '/home') {
            return '/login';
          }
          return '/login';
        }

        // If authenticated, enforce role-based routing
        if (isAuthenticated) {
          final currentRole = appState.currentRole;

          // Super admin: redirect to unsupported screen (unless already there or /debug in debug mode)
          if (currentRole == Role.superAdmin) {
            if (location == '/unsupported' || (kDebugMode && location == '/debug')) {
              return null;
            }
            return '/unsupported';
          }

          // Employee and Admin: enforce prefix-based routing
          final defaultRoute = Role.defaultRouteForRole(currentRole);
          final rolePrefix = currentRole.routePrefix;

          // Allow debug route in debug mode even when authenticated
          if (kDebugMode && location == '/debug') {
            return null;
          }

          // Redirect /home to role-specific default route
          if (location == '/home') {
            if (currentRole == Role.admin) {
              return '/a/dashboard';
            }
            return '/e/dashboard';
          }

          // Redirect splash and login to role-specific default route
          if (location == '/' || location == '/login') {
            return defaultRoute;
          }

          // Enforce prefix rule: user can only access routes matching their role prefix
          // Allow routes that start with the role prefix
          if (location.startsWith(rolePrefix)) {
            return null;
          }

          // If route doesn't match role prefix, redirect to default route
          return defaultRoute;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'splash',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const SplashScreen(),
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const OnboardingScreen(),
          ),
        ),
        // /home redirects to role-specific default route (handled in redirect)
        GoRoute(
          path: '/home',
          redirect: (context, state) {
            final role = appState.currentRole;
            if (role == Role.superAdmin) {
              return '/unsupported';
            }
            return role == Role.admin ? '/a/dashboard' : '/e/dashboard';
          },
        ),
        // Unsupported screen for super admin
        GoRoute(
          path: '/unsupported',
          name: 'unsupported',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const UnsupportedScreen(),
          ),
        ),
        // Employee routes
        GoRoute(
          path: '/e',
          redirect: (context, state) => '/e/dashboard',
        ),
        GoRoute(
          path: '/e/dashboard',
          name: 'employee_dashboard',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const EmployeeShell(
              child: EmployeeDashboardScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/e/attendance',
          name: 'employee_attendance',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const EmployeeShell(
              child: MyAttendanceScreen(roleScope: Role.employee),
            ),
          ),
        ),
        GoRoute(
          path: '/e/leave',
          name: 'employee_leave',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const EmployeeShell(
              child: LeaveListScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/e/leave/apply',
          name: 'employee_leave_apply',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const ApplyLeaveScreen(),
          ),
        ),
        GoRoute(
          path: '/e/profile',
          name: 'employee_profile',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const EmployeeShell(
              child: ProfileScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/e/notifications',
          name: 'employee_notifications',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const EmployeeShell(
              child: NotificationsScreen(roleScope: Role.employee),
            ),
          ),
        ),
        // Admin routes
        GoRoute(
          path: '/a',
          redirect: (context, state) => '/a/dashboard',
        ),
        GoRoute(
          path: '/a/dashboard',
          name: 'admin_dashboard',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: AdminDashboardScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/a/employees',
          name: 'admin_employees',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: AdminEmployeesScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/a/attendance',
          name: 'admin_attendance',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: MyAttendanceScreen(roleScope: Role.admin),
            ),
          ),
        ),
        GoRoute(
          path: '/a/leave',
          name: 'admin_leave',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: AdminLeaveScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/a/reports',
          name: 'admin_reports',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: AdminReportsScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/a/notifications',
          name: 'admin_notifications',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: NotificationsScreen(roleScope: Role.admin),
            ),
          ),
        ),
        GoRoute(
          path: '/a/settings',
          name: 'admin_settings',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const AdminShell(
              child: AdminSettingsScreen(),
            ),
          ),
        ),
        // Debug route - only available in debug mode
        if (kDebugMode)
          GoRoute(
            path: '/debug',
            name: 'debug',
            pageBuilder: (context, state) => _buildTransitionPage(
              context: context,
              state: state,
              child: const DebugMenuScreen(),
            ),
          ),
      ],
      // Error handling
      errorBuilder: (context, state) => const SplashScreen(),
    );
  }

  /// Build a custom transition page with fade + slide up
  static CustomTransitionPage _buildTransitionPage({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    final reducedMotion = Motion.reducedMotion(context);
    final duration = Motion.duration(context, Motion.page);
    final curve = Motion.curve(context, Motion.standard);

    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Get background color from theme to prevent black flash
        // Always wrap with ColoredBox, even for reduced motion
        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

        if (reducedMotion) {
          // Even with reduced motion, ensure background is painted
          return ColoredBox(
            color: backgroundColor,
            child: child,
          );
        }

        // Fade animation
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        // Slide animation (slight slide up)
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.08), // ~12px on typical screen
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: curve,
          ),
        );

        // Wrap with ColoredBox to prevent black flash during transition
        return ColoredBox(
          color: backgroundColor,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }
}
