import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
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

            // Logo section (only on first page, no logo on others)
            _buildLogo(_currentPage),

            // Consistent spacing between logo and PageView
            SizedBox(height: _currentPage == 0 ? AppSpacing.md : 0),

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
                  PressableScale(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(int currentPage) {
    // Show full logo only on first page, no logo on pages 2 and 3
    if (currentPage == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
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
    } else {
      // No logo on pages 2 and 3 - use shrink to maintain layout stability
      return const SizedBox.shrink();
    }
  }

  Widget _buildPage(OnboardingPage page) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),),
            child: child,
          ),
        );
      },
      child: Padding(
        key: ValueKey(page.title), // Key for AnimatedSwitcher
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg, // Increased for better vertical rhythm
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration placeholder (Icon)
            Container(
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
            const SizedBox(height: AppSpacing.xl), // Fixed spacing for consistency

            // Title
            Text(
              page.title,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg), // Increased from md

            // Description
            Text(
              page.description,
              style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
