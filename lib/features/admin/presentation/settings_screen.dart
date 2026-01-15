import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/section_header.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Admin settings screen
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _weeklyDigest = false;
  bool _showPhone = true;
  bool _showDepartment = true;
  bool _require2fa = false;
  bool _strongPasswords = true;

  void _showInfoSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      skipScaffold: true,
      child: SingleChildScrollView(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Appearance'),
            _buildSectionCard(
              children: [
                _buildSwitchTile(
                  title: 'Dark mode',
                  subtitle: 'Use darker colors throughout the app',
                  value: _darkMode,
                  onChanged: (value) => setState(() => _darkMode = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Notifications'),
            _buildSectionCard(
              children: [
                _buildSwitchTile(
                  title: 'Email notifications',
                  subtitle: 'Receive important updates via email',
                  value: _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),
                _buildSwitchTile(
                  title: 'Push notifications',
                  subtitle: 'Allow real-time alerts on device',
                  value: _pushNotifications,
                  onChanged: (value) => setState(() => _pushNotifications = value),
                ),
                _buildSwitchTile(
                  title: 'Weekly summary',
                  subtitle: 'Get a weekly activity digest',
                  value: _weeklyDigest,
                  onChanged: (value) => setState(() => _weeklyDigest = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Profile Visibility'),
            _buildSectionCard(
              children: [
                _buildSwitchTile(
                  title: 'Show phone number',
                  subtitle: 'Allow employees to display phone number',
                  value: _showPhone,
                  onChanged: (value) => setState(() => _showPhone = value),
                ),
                _buildSwitchTile(
                  title: 'Show department',
                  subtitle: 'Allow employees to display department',
                  value: _showDepartment,
                  onChanged: (value) => setState(() => _showDepartment = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Security'),
            _buildSectionCard(
              children: [
                _buildSwitchTile(
                  title: 'Require 2FA',
                  subtitle: 'Enforce two-factor authentication',
                  value: _require2fa,
                  onChanged: (value) => setState(() => _require2fa = value),
                ),
                _buildSwitchTile(
                  title: 'Strong passwords',
                  subtitle: 'Require minimum length and complexity',
                  value: _strongPasswords,
                  onChanged: (value) => setState(() => _strongPasswords = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Manage security policy',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Password expiry, lockout rules, and sessions',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showInfoSnack('Security policy editor coming soon'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('System'),
            _buildSectionCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Export settings',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Download a snapshot of current configuration',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () => _showInfoSnack('Export coming soon'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Reset demo data',
                    style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Clear locally seeded data for testing',
                    style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.restart_alt_outlined),
                  onTap: () => _showInfoSnack('Demo data reset coming soon'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return AppCard(
      padding: AppSpacing.mdAll,
      child: Column(
        children: children
            .expand(
              (child) => [
                child,
                const Divider(height: AppSpacing.lg),
              ],
            )
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

