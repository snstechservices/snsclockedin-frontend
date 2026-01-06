import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/motion.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Clock status enum for employee dashboard
enum ClockStatus {
  notClockedIn,
  clockedIn,
  onBreak,
}

/// Employee dashboard screen with greeting, status, and quick actions
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  // Mock data - will be replaced with view model later
  final String _employeeName = 'John Doe';
  final String? _department = 'Engineering'; // Optional department
  ClockStatus _clockStatus = ClockStatus.notClockedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting card with entrance animation
              Entrance(
                child: _buildGreetingCard(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Today's Status card
              _buildStatusCard(),
              const SizedBox(height: AppSpacing.lg),

              // Quick Actions section with entrance animation
              Entrance(
                delay: const Duration(milliseconds: 100),
                child: _buildQuickActionsSection(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Overview placeholder
              _buildOverviewPlaceholder(),
            ],
          ),
        ),
      ),
      floatingActionButton: kDebugMode ? _buildDebugFAB(context) : null,
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _employeeName,
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildRoleChip(),
              if (_department != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _buildDepartmentChip(_department!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        'Employee',
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDepartmentChip(String department) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        department,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    String statusText;
    String helperText;
    Color statusColor;

    switch (_clockStatus) {
      case ClockStatus.notClockedIn:
        statusText = 'Not Clocked In';
        helperText = 'Tap Clock In to start your day';
        statusColor = AppColors.textSecondary;
        break;
      case ClockStatus.clockedIn:
        statusText = 'Clocked In';
        helperText = 'You\'re currently working';
        statusColor = AppColors.success;
        break;
      case ClockStatus.onBreak:
        statusText = 'On Break';
        helperText = 'You\'re currently on break';
        statusColor = AppColors.warning;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Status',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusText,
                style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText,
            style: AppTypography.lightTextTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.lightTextTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        // Large primary Clock In/Out card
        _buildPrimaryActionCard(),
        const SizedBox(height: AppSpacing.md),
        // Two medium cards in a row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.calendar_today,
                label: 'Apply Leave',
                onTap: () => context.go('/e/leave'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionCard(
                icon: Icons.access_time,
                label: 'Timesheet',
                onTap: () => context.go('/e/attendance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Wide Profile card
        _buildActionCard(
          icon: Icons.person,
          label: 'Profile',
          onTap: () => context.go('/e/profile'),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard() {
    final isClockedIn = _clockStatus == ClockStatus.clockedIn;
    final label = isClockedIn ? 'Clock Out' : 'Clock In';
    final icon = isClockedIn ? Icons.logout : Icons.login;

    return InkWell(
      onTap: () {
        // Mock clock in/out action
        setState(() {
          if (_clockStatus == ClockStatus.notClockedIn) {
            _clockStatus = ClockStatus.clockedIn;
          } else if (_clockStatus == ClockStatus.clockedIn) {
            _clockStatus = ClockStatus.notClockedIn;
          }
        });
      },
      borderRadius: AppRadius.mediumAll,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumAll,
      child: Container(
        width: isWide ? double.infinity : null,
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: AppSpacing.xlAll,
      child: Column(
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Overview',
            style: AppTypography.lightTextTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Charts and statistics will appear here',
            style: AppTypography.lightTextTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget? _buildDebugFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showDebugMenu(context),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.bug_report, color: Colors.white),
    );
  }

  void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DebugMenuSheet(),
    );
  }
}

class _DebugMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debug Menu',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Current Role: ${appState.currentRole.value}',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/debug');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Debug Menu'),
              style: ElevatedButton.styleFrom(
                padding: AppSpacing.lgAll,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Quick Role Switch',
              style: AppTypography.lightTextTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.employee),
                    child: const Text('Employee'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.admin),
                    child: const Text('Admin'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _switchRole(context, Role.superAdmin),
                    child: const Text('Super Admin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _switchRole(BuildContext context, Role role) async {
    final appState = context.read<AppState>();
    
    // Ensure user is authenticated when switching roles
    if (!appState.isAuthenticated) {
      await appState.loginMock(role: role);
    } else {
      appState.setRole(role);
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Role switched to ${role.value}')),
    );
    context.go('/home');
  }
}

