import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/navigation/nav_config.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';

/// Left-side navigation drawer widget matching legacy design
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.items,
    required this.currentLocation,
    required this.role,
    this.userName,
    this.userEmail,
    this.companyName,
    this.avatarUrl,
    this.onLogout,
  });

  /// Navigation items to display
  final List<NavItem> items;

  /// Current route location
  final String currentLocation;

  /// User's role
  final Role role;

  /// User's display name (optional)
  final String? userName;

  /// User's email (optional)
  final String? userEmail;

  /// Company name (optional)
  final String? companyName;

  /// Avatar image URL (optional, falls back to initials)
  final String? avatarUrl;

  /// Logout callback (optional)
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with avatar, name, email, and company chip
            _buildHeader(context),
            // Navigation items
            Expanded(
              child: _buildNavItems(context),
            ),
            // Footer: Help & Support, Logout
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final displayName = userName ?? 'User Name';
    final email = userEmail ?? 'user@example.com';
    final company = companyName;
    final initials = _getInitials(displayName);
    final roleLabel = role == Role.admin
        ? 'Admin'
        : role == Role.superAdmin
            ? 'Super Admin'
            : 'Employee';

    // Determine profile route based on role
    final profileRoute = role == Role.employee ? '/e/profile' : '/a/settings';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (role == Role.admin) {
          context.go('/a/settings');
        } else {
          context.go(profileRoute);
        }
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Text(
                        initials,
                        style: AppTypography.lightTextTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: AppTypography.lightTextTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildChip(roleLabel),
                        if (company != null && company.isNotEmpty)
                          _buildChip(company!),
                      ],
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

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildNavItems(BuildContext context) {
    // Group items by section
    final Map<String?, List<NavItem>> groupedItems = {};
    for (final item in items) {
      final section = item.section;
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    // Sort sections: null/empty first, then alphabetically
    final sections = groupedItems.keys.toList()
      ..sort((a, b) {
        if (a == null || a.isEmpty) return -1;
        if (b == null || b.isEmpty) return 1;
        return a.compareTo(b);
      });

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final section in sections) ...[
          if (section != null && section.isNotEmpty)
            _buildSectionHeader(section),
          ...groupedItems[section]!.map((item) => _buildNavItem(context, item)),
          if (section != null && section.isNotEmpty)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String sectionTitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        sectionTitle.toUpperCase(),
        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, NavItem item) {
    final isSelected = _isItemSelected(item);
    final isNotifications = item.route.contains('/notifications');
    int unreadCount = 0;
    if (isNotifications) {
      try {
        unreadCount = context.watch<NotificationsStore>().unreadCount;
      } catch (e) {
        // Store not available, default to 0
        unreadCount = 0;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: AppRadius.smAll,
      ),
      child: Stack(
        children: [
          if (isSelected)
            Positioned(
              left: 0,
              top: 6,
              bottom: 6,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ListTile(
            dense: true,
            minLeadingWidth: 24,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            leading: Icon(
              item.icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.muted,
            ),
            title: Text(
              item.label,
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
            trailing: isNotifications && unreadCount > 0
                ? SizedBox(
                    width: unreadCount > 99 ? 40 : 28,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: unreadCount > 99 ? AppSpacing.sm : AppSpacing.xs,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: unreadCount > 99 ? 32 : 24,
                        minHeight: 20,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              context.go(item.route);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Support section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'SUPPORT',
              style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
          ),
          ListTile(
            dense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: const Icon(
              Icons.help_outline,
              size: 24,
              color: AppColors.textPrimary,
            ),
            title: Text(
              'Help & Support',
              style: AppTypography.lightTextTheme.bodyMedium,
            ),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to help & support screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon')),
              );
            },
          ),
          if (onLogout != null) ...[
            ListTile(
              dense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              leading: const Icon(
                Icons.logout,
                size: 24,
                color: AppColors.error,
              ),
              title: Text(
                'Logout',
                style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogout?.call();
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[parts.length - 1].substring(0, 1))
        .toUpperCase();
  }

  bool _isItemSelected(NavItem item) {
    return currentLocation == item.route ||
        currentLocation.startsWith('${item.route}/');
  }
}
