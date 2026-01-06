import 'package:flutter/material.dart';
import 'package:sns_clocked_in/core/role/role.dart';

/// Navigation item configuration
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  /// Display label for the navigation item
  final String label;

  /// Icon for the navigation item
  final IconData icon;

  /// Route path for the navigation item
  final String route;
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
      label: 'Leave',
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
}

