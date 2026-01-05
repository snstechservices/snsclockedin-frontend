import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/core/ui/pressable_scale.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Track Your Time',
      description: 'Easily clock in and out with just a tap. Keep track of your work hours effortlessly.',
      icon: Icons.access_time,
    ),
    OnboardingPage(
      title: 'Manage Your Schedule',
      description: 'View your upcoming shifts and manage your availability all in one place.',
      icon: Icons.calendar_today,
    ),
    OnboardingPage(
      title: 'Stay Connected',
      description: 'Get important updates and notifications from your team and managers.',
      icon: Icons.notifications,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _handleSkip() async {
    // Update AppState cache (which also persists to storage)
    // Router redirect will automatically handle navigation - no context.go() needed
    await context.read<AppState>().setOnboardingSeen();
  }

  Future<void> _handleNext() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: Motion.duration(context, Motion.base),
        curve: Motion.curve(context, Motion.emphasized),
      );
    } else {
      // Update AppState cache (which also persists to storage)
      // Router redirect will automatically handle navigation - no context.go() needed
      await context.read<AppState>().setOnboardingSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top row: Spacer + Skip button (top-right)
            Padding(
              padding: AppSpacing.mdAll,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _handleSkip,
                    child: Text(
                      'Skip',
                      style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Logo section (fixed header, rendered once)
            _buildLogo(),

            // PageView content (only icon + title + description)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Dots indicator and Next button
            Padding(
              padding: AppSpacing.xlAll,
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _buildDot(index == _currentPage),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Next/Get Started button
                  Entrance(
                    delay: const Duration(milliseconds: 120),
                    child: PressableScale(
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.mediumAll,
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Image.asset(
        'assets/images/splash_logo.png',
        height: 90,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/app_log.png',
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error2, stackTrace2) {
              return const Icon(
                Icons.access_time,
                size: 90,
                color: AppColors.primary,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: AppSpacing.xlAll,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration placeholder (Icon)
          Entrance(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                page.icon,
                size: 64,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),

          // Title
          Entrance(
            delay: const Duration(milliseconds: 60),
            child: Text(
              page.title,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Description
          Entrance(
            delay: const Duration(milliseconds: 90),
            child: Text(
              page.description,
              style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.muted,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
