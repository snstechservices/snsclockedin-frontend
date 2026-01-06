import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_surface_card.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

class DebugMenuScreen extends StatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  State<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends State<DebugMenuScreen> {
  bool _onboardingSeen = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    // Read from AppState cache (synchronous, no delay)
    final appState = context.read<AppState>();
    if (mounted) {
      setState(() {
        _onboardingSeen = appState.hasSeenOnboarding;
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetOnboarding() async {
    // Update AppState cache (which also persists to storage)
    await context.read<AppState>().clearOnboarding();
    await _loadStatus();
    _showSnackBar('Onboarding flag reset');
  }

  Future<void> _markOnboardingSeen() async {
    // Update AppState cache (which also persists to storage)
    await context.read<AppState>().setOnboardingSeen();
    await _loadStatus();
    _showSnackBar('Onboarding marked as seen');
  }

  Future<void> _switchRole(Role role) async {
    final appState = context.read<AppState>();
    
    // Ensure user is authenticated when switching roles
    if (!appState.isAuthenticated) {
      await appState.loginMock(role: role);
    } else {
      appState.setRole(role);
    }
    
    _showSnackBar('Role switched to ${role.value}');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      // In release builds, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Debug Menu'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current values section
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Values',
                    style: AppTypography.lightTextTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    _buildStatusRow(
                      'onboarding_seen_v2',
                      _onboardingSeen.toString(),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Auth Token',
                    appState.accessToken != null
                        ? 'Present'
                        : 'Not implemented',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Navigation buttons
            Text(
              'Navigation',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildActionButton(
              label: 'Go to Onboarding',
              icon: Icons.arrow_forward,
              onPressed: () => context.go('/onboarding'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Go to Login',
              icon: Icons.login,
              onPressed: () => context.go('/login'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Go to Home',
              icon: Icons.home,
              onPressed: () => context.go('/home'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Onboarding controls
            Text(
              'Onboarding Controls',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildActionButton(
              label: 'Reset Onboarding Flag',
              icon: Icons.refresh,
              onPressed: _resetOnboarding,
              backgroundColor: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Mark Onboarding Seen',
              icon: Icons.check_circle,
              onPressed: _markOnboardingSeen,
              backgroundColor: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Role Testing
            Text(
              'Role Testing',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    'Current Role',
                    appState.currentRole.value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildActionButton(
                    label: 'Switch to Employee',
                    icon: Icons.person,
                    onPressed: () => _switchRole(Role.employee),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildActionButton(
                    label: 'Switch to Admin',
                    icon: Icons.admin_panel_settings,
                    onPressed: () => _switchRole(Role.admin),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildActionButton(
                    label: 'Switch to Super Admin',
                    icon: Icons.supervisor_account,
                    onPressed: () => _switchRole(Role.superAdmin),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.lightTextTheme.bodyMedium,
        ),
        Text(
          value,
          style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
      ),
    );
  }
}
