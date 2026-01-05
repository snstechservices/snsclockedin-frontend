import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/features/auth/presentation/login_screen.dart';
import 'package:sns_clocked_in/features/home/presentation/home_screen.dart';
import 'package:sns_clocked_in/features/splash/presentation/splash_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    // Error handling
    errorBuilder: (context, state) => const SplashScreen(),
  );
}
