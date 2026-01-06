import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/entrance.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin dashboard screen (mock data, no backend)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Mocked data placeholders
  final String _adminName = 'Alex Johnson';
  final String _companyName = 'S&S Accounting';
  final int _employees = 42;
  final int _onLeave = 3;
  final int _pendingApprovals = 7;
  final int _attendancePercent = 88;

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      floatingActionButton: kDebugMode ? _buildDebugFAB(context) : null,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              child: _buildHeaderCard(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSummaryGrid(),
            const SizedBox(height: AppSpacing.xl),
            Entrance(
              delay: const Duration(milliseconds: 100),
              child: _buildActions(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildOverviewPlaceholder(),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return AppCard(
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
            _adminName,
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildChip(
                label: 'Admin',
                color: AppColors.primary.withValues(alpha: 0.12),
                textColor: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(
                label: _companyName,
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                textColor: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Today',
                style: AppTypography.lightTextTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final spacing = AppSpacing.md;
        final itemWidth = (availableWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _summaryCard(
              'Employees',
              _employees.toString(),
              Icons.people_outline,
              itemWidth,
            ),
            _summaryCard(
              'On Leave Today',
              _onLeave.toString(),
              Icons.beach_access,
              itemWidth,
            ),
            _summaryCard(
              'Pending Approvals',
              _pendingApprovals.toString(),
              Icons.approval,
              itemWidth,
            ),
            _summaryCard(
              'Attendance Rate',
              '$_attendancePercent%',
              Icons.access_time,
              itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    double width,
  ) {
    return AppCard(
      width: width,
      padding: AppSpacing.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.lightTextTheme.headlineMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Actions'),
        _primaryActionCard(
          label: 'My Attendance',
          icon: Icons.access_time,
          onTap: () => context.go('/a/attendance'),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 2-column grid: Row 1 (Employees, Leave), Row 2 (Reports full width)
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _secondaryActionCard(
                    label: 'Employees',
                    icon: Icons.people_outline,
                    onTap: () => context.go('/a/employees'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _secondaryActionCard(
                    label: 'Leave',
                    icon: Icons.calendar_today,
                    onTap: () => context.go('/a/leave'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _secondaryActionCard(
              label: 'Reports',
              icon: Icons.bar_chart,
              onTap: () => context.go('/a/reports'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryActionCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumAll,
      child: Container(
        padding: AppSpacing.lgAll,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.mediumAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
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

  Widget _secondaryActionCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: AppSpacing.lgAll,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    );
  }

  Widget _buildOverviewPlaceholder() {
    return AppCard(
      padding: AppSpacing.xlAll,
      child: Column(
          children: [
            Icon(Icons.show_chart, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Overview',
              style: AppTypography.lightTextTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reports and charts will appear here',
              style: AppTypography.lightTextTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
    );
  }

  Widget? _buildDebugFAB(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: FloatingActionButton.small(
        onPressed: () => _showDebugMenu(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
      ),
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