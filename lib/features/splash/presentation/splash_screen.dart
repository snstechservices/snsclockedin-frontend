import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
// removed unused imports
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize pulse animation
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkNavigation();
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _checkNavigation() {
    if (_hasNavigated) return;

    // Use read instead of watch to avoid unnecessary rebuilds
    final appState = context.read<AppState>();
    final isBootstrapped = appState.isBootstrapped;

    // Once bootstrapped, pre-build login screen and wait until it's fully ready
    // This ensures smooth transition - splash stays until login is completely loaded
    if (isBootstrapped && !_hasNavigated) {
      _hasNavigated = true;
      _preloadAndNavigate();
    }
  }

  /// Pre-load login screen assets and wait until fully ready before navigating
  Future<void> _preloadAndNavigate() async {
    if (!mounted) return;

    // Determine which screen we'll navigate to
    final appState = context.read<AppState>();
    final hasSeenOnboarding = appState.hasSeenOnboarding;
    final isAuthenticated = appState.isAuthenticated;

    // If navigating to login, pre-cache login screen assets
    if (!isAuthenticated && hasSeenOnboarding) {
      // Pre-cache login screen logo to ensure instant display
      try {
        await precacheImage(
          const AssetImage('assets/images/app_log.png'),
          context,
        );
      } catch (_) {
        // Ignore errors - image will load when needed
      }

      // Wait for multiple frames to ensure login screen widget tree is ready
      // This gives time for the widget tree to be built and assets to be loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Additional delay to ensure login screen is fully ready
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _navigateWhenReady();
            }
          });
        });
      });
    } else {
      // For other screens, shorter wait is fine
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _navigateWhenReady();
          }
        });
      });
    }
  }

  /// Navigate when the next screen is ready
  void _navigateWhenReady() {
    if (!mounted) return;

    // Router's refreshListenable will handle the actual navigation
    // The redirect function is synchronous and will route correctly
    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;

    // Force router to re-evaluate redirect (next screen is ready)
    if (currentLocation == '/') {
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      // Keep splash minimal - no header/footer
      body: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final primaryColor = theme.colorScheme.primary;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Full App Logo with responsive sizing and pulse animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: _buildFullLogo(),
                ),
                SizedBox(height: constraints.maxHeight * 0.05),
                // Loading indicator - optimized for smooth animation
                RepaintBoundary(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.025),
                // Subtle loading text
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullLogo() {
    // Use FractionallySizedBox for responsive logo sizing - 40% of screen width
    // RepaintBoundary prevents unnecessary repaints during animation
    return RepaintBoundary(
      child: FractionallySizedBox(
        widthFactor: 0.4, // 40% of screen width
        child: FittedBox(
          fit: BoxFit.contain,
          child: _buildDefaultLogo(),
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    // Cache the image to prevent reloading on rebuilds
    return Image.asset(
      'assets/images/splash_logo.png',
      fit: BoxFit.contain,
      cacheWidth: 400, // Limit image size for better performance
      errorBuilder: (context, error, stackTrace) {
        // Fallback to app_log.png if splash_logo.png fails
        return Image.asset(
          'assets/images/app_log.png',
          fit: BoxFit.contain,
          cacheWidth: 400,
          errorBuilder: (context, error2, stackTrace2) {
            // Final fallback to simple icon
            return _buildFallbackIcon();
          },
        );
      },
    );
  }

  Widget _buildFallbackIcon() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(Icons.access_time, size: 30, color: primaryColor),
        const SizedBox(height: 3),
        Text(
          'SNS Clocked In',
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
