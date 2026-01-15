import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/role/role.dart';

/// Navigation item configuration
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.section,
  });

  /// Display label for the navigation item
  final String label;

  /// Icon for the navigation item
  final IconData icon;

  /// Route path for the navigation item
  final String route;

  /// Optional section/group label (e.g., "MOST USED", "MANAGEMENT", "ACCOUNT")
  final String? section;
}

/// Navigation items per role
class NavConfig {
  NavConfig._();

  // Employee: Main bottom nav items (4 items)
  static const List<NavItem> employeeMainNavItems = [
    NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/e/dashboard',
    ),
    NavItem(
      label: 'Attendance',
      icon: Icons.access_time,
      route: '/e/attendance',
    ),
    NavItem(
      label: 'Leave',
      icon: Icons.calendar_today,
      route: '/e/leave',
    ),
    NavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      route: '/e/profile',
    ),
  ];

  // Employee: "More" sheet items
  static const List<NavItem> employeeMoreNavItems = [
    NavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      route: '/e/notifications',
    ),
  ];

  // Admin: Main bottom nav items (4 items)
  static const List<NavItem> adminMainNavItems = [
    NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/a/dashboard',
    ),
    NavItem(
      label: 'Attendance',
      icon: Icons.access_time,
      route: '/a/attendance',
    ),
    NavItem(
      label: 'Leave Management',
      icon: Icons.calendar_today,
      route: '/a/leave',
    ),
    NavItem(
      label: 'Employees',
      icon: Icons.people_outline,
      route: '/a/employees',
    ),
  ];

  // Admin: "More" sheet items
  static const List<NavItem> adminMoreNavItems = [
    NavItem(
      label: 'Company Calendar',
      icon: Icons.calendar_today,
      route: '/a/calendar',
    ),
    NavItem(
      label: 'Break Types',
      icon: Icons.coffee,
      route: '/a/break-types',
    ),
    NavItem(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      route: '/a/reports',
    ),
    NavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      route: '/a/settings',
    ),
  ];

  // Admin: Drawer navigation items with sections (for legacy-style drawer)
  static const List<NavItem> adminDrawerNavItems = [
    // MOST USED section
    NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard,
      route: '/a/dashboard',
      section: 'MOST USED',
    ),
    NavItem(
      label: 'Organization Management',
      icon: Icons.account_tree,
      route: '/a/organization',
      section: 'MOST USED',
    ),
    NavItem(
      label: 'Employee Management',
      icon: Icons.people,
      route: '/a/employees',
      section: 'MOST USED',
    ),
    NavItem(
      label: 'Leave Management',
      icon: Icons.beach_access,
      route: '/a/leave',
      section: 'MOST USED',
    ),
    NavItem(
      label: 'Company Calendar',
      icon: Icons.calendar_today,
      route: '/a/calendar',
      section: 'MOST USED',
    ),
    // MANAGEMENT section
    NavItem(
      label: 'Attendance',
      icon: Icons.access_time,
      route: '/a/attendance',
      section: 'MANAGEMENT',
    ),
    NavItem(
      label: 'Break Types',
      icon: Icons.coffee,
      route: '/a/break-types',
      section: 'MANAGEMENT',
    ),
    NavItem(
      label: 'Reports',
      icon: Icons.assessment,
      route: '/a/reports',
      section: 'MANAGEMENT',
    ),
    NavItem(
      label: 'Settings',
      icon: Icons.settings,
      route: '/a/settings',
      section: 'MANAGEMENT',
    ),
  ];

  /// All navigation items for employee role (for backward compatibility)
  static List<NavItem> get employeeNavItems => [
        ...employeeMainNavItems,
        ...employeeMoreNavItems,
      ];

  /// All navigation items for admin role (for backward compatibility)
  static List<NavItem> get adminNavItems => [
        ...adminMainNavItems,
        ...adminMoreNavItems,
      ];

  /// Navigation items for super admin role
  static const List<NavItem> superAdminNavItems = [
    NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/sa/dashboard',
    ),
    NavItem(
      label: 'Companies',
      icon: Icons.business_outlined,
      route: '/sa/companies',
    ),
    NavItem(
      label: 'Users',
      icon: Icons.people_outline,
      route: '/sa/users',
    ),
    NavItem(
      label: 'System',
      icon: Icons.settings_outlined,
      route: '/sa/system',
    ),
    NavItem(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      route: '/sa/reports',
    ),
  ];

  /// Get navigation items for a specific role
  static List<NavItem> navItemsForRole(Role role) {
    switch (role) {
      case Role.superAdmin:
        return superAdminNavItems;
      case Role.admin:
        return adminNavItems;
      case Role.employee:
        return employeeNavItems;
    }
  }

  /// Get all navigation items (main + more) for a specific role
  static List<NavItem> allNavItemsForRole(Role role) {
    switch (role) {
      case Role.superAdmin:
        return superAdminNavItems;
      case Role.admin:
        return adminNavItems;
      case Role.employee:
        return employeeNavItems;
    }
  }

  /// Get drawer navigation items for a specific role (with sections)
  static List<NavItem> drawerNavItemsForRole(Role role) {
    switch (role) {
      case Role.superAdmin:
        return superAdminNavItems;
      case Role.admin:
        return adminDrawerNavItems;
      case Role.employee:
        return employeeNavItems;
    }
  }

  /// Get drawer navigation items for v2 (with sections)
  /// Employee: Main (Dashboard, Attendance, Leave), Account (Profile, Notifications)
  /// Admin: Main (Dashboard, Attendance, Leave), Management (Employees, Reports, Settings)
  static List<NavItem> drawerNavItemsV2ForRole(Role role) {
    switch (role) {
      case Role.employee:
        return [
          // Main section
          NavItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            route: '/e/dashboard',
            section: 'Main',
          ),
          NavItem(
            label: 'Attendance',
            icon: Icons.access_time,
            route: '/e/attendance',
            section: 'Main',
          ),
          NavItem(
            label: 'Leave',
            icon: Icons.calendar_today,
            route: '/e/leave',
            section: 'Main',
          ),
          NavItem(
            label: 'Timesheet',
            icon: Icons.access_time_filled,
            route: '/e/timesheet',
            section: 'Main',
          ),
          // Account section
          NavItem(
            label: 'Profile',
            icon: Icons.person_outline,
            route: '/e/profile',
            section: 'Account',
          ),
          NavItem(
            label: 'Notifications',
            icon: Icons.notifications_outlined,
            route: '/e/notifications',
            section: 'Account',
          ),
        ];
      case Role.admin:
        return [
          // Main section
          NavItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            route: '/a/dashboard',
            section: 'Main',
          ),
          NavItem(
            label: 'Attendance',
            icon: Icons.access_time,
            route: '/a/attendance',
            section: 'Main',
          ),
          NavItem(
            label: 'Leave Management',
            icon: Icons.calendar_today,
            route: '/a/leave',
            section: 'Main',
          ),
          // Management section
          NavItem(
            label: 'Employees',
            icon: Icons.people_outline,
            route: '/a/employees',
            section: 'Management',
          ),
          NavItem(
            label: 'Company Calendar',
            icon: Icons.calendar_today,
            route: '/a/calendar',
            section: 'Management',
          ),
          NavItem(
            label: 'Break Types',
            icon: Icons.coffee,
            route: '/a/break-types',
            section: 'Management',
          ),
          NavItem(
            label: 'Timesheets',
            icon: Icons.access_time_filled,
            route: '/a/timesheets',
            section: 'Management',
          ),
          NavItem(
            label: 'Reports',
            icon: Icons.assessment_outlined,
            route: '/a/reports',
            section: 'Management',
          ),
          NavItem(
            label: 'Settings',
            icon: Icons.settings_outlined,
            route: '/a/settings',
            section: 'Management',
          ),
        ];
      case Role.superAdmin:
        return superAdminNavItems;
    }
  }

  /// Get the section title for a given route path
  /// Returns the label of the matching nav item, or null if not found
  static String? getTitleForRoute(String routePath, Role role) {
    // Check main nav items first
    final items = allNavItemsForRole(role);
    for (final item in items) {
      if (routePath == item.route || routePath.startsWith('${item.route}/')) {
        return item.label;
      }
    }
    // Also check drawer nav items (v2) for routes like Timesheet
    final drawerItems = drawerNavItemsV2ForRole(role);
    for (final item in drawerItems) {
      if (routePath == item.route || routePath.startsWith('${item.route}/')) {
        return item.label;
      }
    }
    return null;
  }
}

