import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/storage/onboarding_storage.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/leave/application/leave_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_approvals_store.dart';
import 'package:sns_clocked_in/features/leave/application/admin_leave_balances_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_accrual_store.dart';
import 'package:sns_clocked_in/features/leave/application/leave_cash_out_store.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/time_tracking/application/time_tracking_store.dart';
import 'package:sns_clocked_in/features/timesheet/application/admin_approvals_store.dart';
import 'package:sns_clocked_in/features/timesheet/application/timesheet_store.dart';

/// Debug harness screen for testing UI flows without backend
/// Only available in debug builds
class DebugHarnessScreen extends StatefulWidget {
  const DebugHarnessScreen({super.key});

  @override
  State<DebugHarnessScreen> createState() => _DebugHarnessScreenState();
}

class _DebugHarnessScreenState extends State<DebugHarnessScreen> {
  bool _onboardingSeen = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final onboardingSeen = await OnboardingStorage.isSeen();
    if (mounted) {
      setState(() {
        _onboardingSeen = onboardingSeen;
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
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return AppScreenScaffold(
        title: 'Debug',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Not available',
                style: AppTypography.lightTextTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Debug harness is only available in debug builds.',
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final appState = context.watch<AppState>();
    final currentLocation = GoRouterState.of(context).uri.path;

    return AppScreenScaffold(
      title: 'Debug Harness',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current State Section
            const SectionHeader('Current State'),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    'Onboarding seen',
                    _isLoading ? 'Loading...' : _onboardingSeen.toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Authenticated',
                    appState.isAuthenticated.toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Current role',
                    appState.currentRole.value,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Company ID',
                    appState.companyId ?? 'none',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Companies (mock)',
                    appState.companies.length.toString(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatusRow(
                    'Current location',
                    currentLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Quick Actions Section
            const SectionHeader('Quick Actions'),
            _buildActionButton(
              label: 'Go to /home',
              icon: Icons.home,
              onPressed: () => context.go('/home'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Go to /login',
              icon: Icons.login,
              onPressed: () => context.go('/login'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Go to /onboarding',
              icon: Icons.school,
              onPressed: () => context.go('/onboarding'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Go to /unsupported',
              icon: Icons.block,
              onPressed: () => context.go('/unsupported'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Company Mode (single vs multi)
            const SectionHeader('Company Mode (Mock)'),
            _buildActionButton(
              label: 'Force single-company (skip selector)',
              icon: Icons.apartment,
              onPressed: () {
                final state = context.read<AppState>();
                state.setMockCompanyMode(singleCompany: true);
                _showSnackBar('Set to single-company mode. Login again to apply.');
              },
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Force multi-company (show selector)',
              icon: Icons.apartment_outlined,
              onPressed: () {
                final state = context.read<AppState>();
                state.setMockCompanyMode(singleCompany: false);
                _showSnackBar('Set to multi-company mode. Login again to apply.');
              },
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Auth + Role Simulation Section
            const SectionHeader('Auth + Role Simulation'),
            _buildActionButton(
              label: 'Login as Employee',
              icon: Icons.person,
              onPressed: () => _loginAsRole(Role.employee),
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Login as Admin',
              icon: Icons.admin_panel_settings,
              onPressed: () => _loginAsRole(Role.admin),
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Login as Super Admin',
              icon: Icons.supervisor_account,
              onPressed: () => _loginAsRole(Role.superAdmin),
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Logout',
              icon: Icons.logout,
              onPressed: _logout,
              backgroundColor: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Onboarding Controls Section
            const SectionHeader('Onboarding Controls'),
            _buildActionButton(
              label: 'Mark onboarding seen',
              icon: Icons.check_circle,
              onPressed: _markOnboardingSeen,
              backgroundColor: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildActionButton(
              label: 'Reset onboarding (seen=false)',
              icon: Icons.refresh,
              onPressed: _resetOnboarding,
              backgroundColor: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Seed Mock Data Section
            const SectionHeader('Seed Mock Data'),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Seed demo data',
                    icon: Icons.add_circle,
                    onPressed: _seedDemoData,
                    backgroundColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildActionButton(
                    label: 'Clear demo data',
                    icon: Icons.delete_outline,
                    onPressed: _clearDemoData,
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Component Showcase Section
            const SectionHeader('Component Showcase'),
            _buildActionButton(
              label: 'View Component Showcase',
              icon: Icons.palette,
              onPressed: () => context.push('/debug/component-showcase'),
              backgroundColor: AppColors.secondary,
            ),
          ],
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

  Future<void> _loginAsRole(Role role) async {
    final appState = context.read<AppState>();
    await appState.debugAuthenticateAs(role);
    _showSnackBar('Logged in as ${role.value}');
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _logout() async {
    final appState = context.read<AppState>();
    await appState.debugLogoutAndResetRole();
    _showSnackBar('Logged out');
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _markOnboardingSeen() async {
    final appState = context.read<AppState>();
    await appState.setOnboardingSeen();
    await _loadStatus();
    _showSnackBar('Onboarding marked as seen');
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _resetOnboarding() async {
    final appState = context.read<AppState>();
    await appState.clearOnboarding();
    await _loadStatus();
    _showSnackBar('Onboarding reset');
    if (mounted) {
      context.go('/home');
    }
  }

  void _seedDemoData() {
    // Seed time tracking
    final timeTrackingStore = context.read<TimeTrackingStore>();
    timeTrackingStore.seedDemo();

    // Seed leave requests
    final leaveStore = context.read<LeaveStore>();
    leaveStore.seedDemo();
    
    // Seed admin leave approvals
    try {
      final adminLeaveStore = context.read<AdminLeaveApprovalsStore>();
      adminLeaveStore.seedDemo();
    } catch (e) {
      // Store might not be available
    }

    // Seed admin leave balances
    try {
      final adminBalancesStore = context.read<AdminLeaveBalancesStore>();
      adminBalancesStore.seedDemo();
    } catch (e) {
      // Store might not be available
    }

    // Seed accrual logs
    try {
      final accrualStore = context.read<LeaveAccrualStore>();
      accrualStore.seedDemo();
    } catch (e) {
      // Store might not be available
    }

    // Seed cash out agreements
    try {
      final cashOutStore = context.read<LeaveCashOutStore>();
      cashOutStore.seedDemo();
    } catch (e) {
      // Store might not be available
    }

    // Seed admin approvals (if admin)
    final appState = context.read<AppState>();
    if (appState.currentRole == Role.admin || appState.currentRole == Role.superAdmin) {
      final approvalsStore = context.read<AdminApprovalsStore>();
      approvalsStore.seedDemo();
    }

    // Seed notifications
    final notificationsStore = context.read<NotificationsStore>();
    notificationsStore.seedDemo();

    // Seed timesheet
    try {
      final timesheetStore = context.read<TimesheetStore>();
      timesheetStore.seedDemo();
    } catch (e) {
      // Store might not be available
    }

    _showSnackBar('Demo data seeded');
  }

  void _clearDemoData() {
    // Clear time tracking
    final timeTrackingStore = context.read<TimeTrackingStore>();
    timeTrackingStore.clearDemo();

    // Clear leave requests
    final leaveStore = context.read<LeaveStore>();
    leaveStore.clearDemo();
    
    // Clear admin leave approvals
    try {
      final adminLeaveStore = context.read<AdminLeaveApprovalsStore>();
      adminLeaveStore.clearDemo();
    } catch (e) {
      // Store might not be available
    }

    // Clear admin leave balances
    try {
      final adminBalancesStore = context.read<AdminLeaveBalancesStore>();
      adminBalancesStore.clearDemo();
    } catch (e) {
      // Store might not be available
    }

    // Clear accrual logs
    try {
      final accrualStore = context.read<LeaveAccrualStore>();
      accrualStore.clearDemo();
    } catch (e) {
      // Store might not be available
    }

    // Clear cash out agreements
    try {
      final cashOutStore = context.read<LeaveCashOutStore>();
      cashOutStore.clearDemo();
    } catch (e) {
      // Store might not be available
    }

    // Clear admin approvals
    final approvalsStore = context.read<AdminApprovalsStore>();
    approvalsStore.clearDemo();

    // Clear notifications
    final notificationsStore = context.read<NotificationsStore>();
    notificationsStore.clearDemo();

    // Clear timesheet
    try {
      final timesheetStore = context.read<TimesheetStore>();
      timesheetStore.clearDemo();
    } catch (e) {
      // Store might not be available
    }

    _showSnackBar('Demo data cleared');
  }
}
