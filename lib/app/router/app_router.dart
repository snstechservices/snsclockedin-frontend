import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/features/auth/presentation/login_screen.dart';
import 'package:sns_clocked_in/features/debug/presentation/debug_menu_screen.dart';
import 'package:sns_clocked_in/features/home/presentation/home_screen.dart';
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

        // If onboarding seen and authenticated: allow /home
        // Allow debug route in debug mode even when authenticated
        if (kDebugMode && location == '/debug') {
          return null;
        }

        // If authenticated, redirect splash and login to home
        if (isAuthenticated) {
          if (location == '/login' || location == '/') {
            return '/home';
          }
          // Already on /home or other allowed route
          return null;
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
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => _buildTransitionPage(
            context: context,
            state: state,
            child: const HomeScreen(),
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
