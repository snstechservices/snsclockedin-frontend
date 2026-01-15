import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/admin_side_navigation.dart';
import '../../services/global_notification_service.dart';
import '../../utils/time_utils.dart';
import '../../models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sns_rooster/utils/logger.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
        _loadNotificationsForTab(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationsForTab(0);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadNotificationsForTab(int tabIndex) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    String? category;
    String? type;

    switch (tabIndex) {
      case 0: // All
        category = null;
        type = null;
        break;
      case 1: // System
        category = 'system';
        type = null;
        break;
      case 2: // Announcements
        category = 'announcement';
        type = 'announcement';
        break;
    }

    provider.fetchNotifications(refresh: true, category: category, type: type);
  }

  /// Set flag to prevent dashboard reminder when navigating from notification
  Future<void> _setNavigationFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('_navigating_from_notification', true);
      Logger.debug(
        'NotificationScreen: Set _navigating_from_notification flag to prevent reminder',
      );

      Future.delayed(const Duration(seconds: 5), () async {
        await prefs.remove('_navigating_from_notification');
        Logger.debug(
          'NotificationScreen: Cleared _navigating_from_notification flag',
        );
      });
    } catch (e) {
      Logger.debug('NotificationScreen: Error setting navigation flag: $e');
    }
  }

  /// Helper function to format notification date
  String _formatNotificationDate(
    DateTime date, {
    Map<String, dynamic>? user,
    Map<String, dynamic>? company,
  }) {
    try {
      return TimeUtils.formatDateWithFormat(
        date,
        'MMM d, y HH:mm',
        user: user,
        company: company,
      );
    } catch (e) {
      Logger.debug('Error formatting notification date: $e');
      return DateFormat('MMM d, y HH:mm').format(date);
    }
  }

  void _showMenuActions() {
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    final notificationService = GlobalNotificationService();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.done_all),
            title: const Text('Mark All as Read'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await notificationProvider.markAllAsRead();
                notificationService.showSuccess(
                  'All notifications marked as read.',
                );
              } catch (e) {
                notificationService.showError('Error: ${e.toString()}');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await notificationProvider.fetchNotifications(refresh: true);
                notificationService.showSuccess(
                  'Notifications refreshed successfully',
                );
              } catch (e) {
                notificationService.showError('Error: ${e.toString()}');
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear All',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Notifications'),
                  content: const Text(
                    'Are you sure you want to delete all notifications? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  await notificationProvider.deleteAllNotifications();
                  notificationService.showSuccess('All notifications cleared.');
                } catch (e) {
                  notificationService.showError('Error: ${e.toString()}');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) async {
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );

    // Mark as read if unread
    if (!notification.isRead) {
      await notificationProvider.markAsRead(notification.id);
    }

    // Navigate using deepLink if available
    if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
      await _setNavigationFlag();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userRole = authProvider.user?['role'];
      final isAdmin = userRole == 'admin';
      final deepLink = notification.deepLink!;

      // Special handling for employee leave notifications
      // Backend sends '/employee/leave/{leaveId}' but we need to navigate to '/leave_request' with Leave History tab
      if (deepLink.startsWith('/employee/leave/')) {
        if (isAdmin) {
          // Admins should go to leave management instead
          Logger.debug(
            'NotificationScreen: Admin leave notification detected, navigating to leave management',
          );
          Navigator.of(context).pushNamed('/admin/leave_management');
        } else {
          Logger.debug(
            'NotificationScreen: Employee leave notification detected, navigating to Leave History tab',
          );
          Navigator.of(context).pushNamed(
            '/leave_request',
            arguments: {'initialTab': 2},
          ); // Tab index 2 = Leave History
        }
      } else {
        // Check if deepLink is an employee route that should redirect admins
        if (isAdmin) {
          // Map employee routes to admin routes
          if (deepLink == '/employee_dashboard' ||
              deepLink == '/attendance' ||
              (deepLink.startsWith('/employee/') &&
                  deepLink.contains('attendance'))) {
            // For attendance-related notifications, redirect admins to admin attendance
            Logger.debug(
              'NotificationScreen: Admin attendance notification detected, navigating to admin attendance',
            );
            Navigator.of(context).pushNamed('/admin_attendance');
            return;
          } else if (deepLink == '/leave_request') {
            // For leave notifications, redirect admins to leave management
            Logger.debug(
              'NotificationScreen: Admin leave notification detected, navigating to leave management',
            );
            Navigator.of(context).pushNamed('/admin/leave_management');
            return;
          } else if (deepLink == '/timesheet') {
            // For timesheet notifications, redirect admins to admin timesheet
            Logger.debug(
              'NotificationScreen: Admin timesheet notification detected, navigating to admin timesheet',
            );
            Navigator.of(context).pushNamed('/admin_timesheet');
            return;
          }
        }

        // Handle /leave_request for employees - check for initialTab in meta
        if (deepLink == '/leave_request' && !isAdmin) {
          final initialTab = notification.meta['initialTab'] as int?;
          if (initialTab != null) {
            Logger.debug(
              'NotificationScreen: Navigating to leave_request with initialTab: $initialTab',
            );
            Navigator.of(context).pushNamed(
              '/leave_request',
              arguments: {'initialTab': initialTab},
            );
          } else {
            Navigator.of(context).pushNamed('/leave_request');
          }
          return;
        }

        // Handle company calendar route - employees shouldn't access admin calendar
        if (deepLink == '/company_calendar') {
          if (isAdmin) {
            Navigator.of(context).pushNamed('/company_calendar');
          } else {
            // Employees don't have access to admin calendar, just navigate to dashboard
            Navigator.of(context).pushNamed('/employee_dashboard');
          }
        } else {
          // For employees or other routes, use the deepLink as-is
          Navigator.of(context).pushNamed(deepLink);
        }
      }
    } else {
      // Fallback: try to infer route from meta or type
      final meta = notification.meta;
      final route = meta['route'] ?? meta['screen'];

      if (route != null && route is String) {
        await _setNavigationFlag();

        // Check user role for fallback routes too
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userRole = authProvider.user?['role'];
        final isAdmin = userRole == 'admin';

        // Map employee routes to admin routes
        if (isAdmin &&
            (route == '/employee_dashboard' || route == '/attendance')) {
          Navigator.of(context).pushNamed('/admin_attendance');
        } else {
          Navigator.of(context).pushNamed(route);
        }
      }
    }
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    // Debug logging
    Logger.debug(
      '🔍 NotificationScreen: Building list with ${notifications.length} notifications',
    );
    if (notifications.isNotEmpty) {
      Logger.debug(
        '🔍 NotificationScreen: First notification: ${notifications[0].title}, type: ${notifications[0].type}, category: ${notifications[0].meta['category']}',
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Group notifications by date
    final groupedNotifications = <String, List<AppNotification>>{};
    for (final notification in notifications) {
      final dateKey = notification.formattedDate;
      groupedNotifications.putIfAbsent(dateKey, () => []).add(notification);
    }

    final sortedDates = groupedNotifications.keys.toList()
      ..sort((a, b) {
        // Sort: Today > Yesterday > dates (descending)
        if (a == 'Today') return -1;
        if (b == 'Today') return 1;
        if (a == 'Yesterday') return -1;
        if (b == 'Yesterday') return 1;
        return b.compareTo(a);
      });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;
    final company = companyProvider.currentCompany?.toJson();

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = sortedDates[dateIndex];
        final dateNotifications = groupedNotifications[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            // Notifications for this date
            ...dateNotifications.map(
              (notification) => _buildNotificationCard(
                notification,
                user: user,
                company: company,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(
    AppNotification notification, {
    Map<String, dynamic>? user,
    Map<String, dynamic>? company,
  }) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: theme.colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.mark_email_read, color: theme.colorScheme.onPrimary),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Mark as read
          final provider = Provider.of<NotificationProvider>(
            context,
            listen: false,
          );
          await provider.markAsRead(notification.id);
          GlobalNotificationService().showSuccess(
            'Notification marked as read',
          );
          return false; // Don't dismiss, just update
        } else {
          // Delete
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Notification'),
                  content: const Text(
                    'Are you sure you want to delete this notification?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ) ??
              false;
        }
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          try {
            final provider = Provider.of<NotificationProvider>(
              context,
              listen: false,
            );
            await provider.deleteNotification(notification.id);
            GlobalNotificationService().showSuccess('Notification deleted');
          } catch (e) {
            GlobalNotificationService().showError(
              'Failed to delete: ${e.toString()}',
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        color: isUnread
            ? theme.colorScheme.secondary.withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        elevation: isUnread ? 4 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: notification
                .getColor(theme.colorScheme)
                .withValues(alpha: 0.1),
            child: Icon(
              notification.icon,
              color: notification.getColor(theme.colorScheme),
            ),
          ),
          title: Text(
            notification.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (notification.priority == 'critical' ||
                      notification.priority == 'high')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: notification.priority == 'critical'
                            ? theme.colorScheme.error.withValues(alpha: 0.2)
                            : theme.colorScheme.tertiary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notification.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: notification.priority == 'critical'
                              ? theme.colorScheme.error
                              : theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  if (notification.priority == 'critical' ||
                      notification.priority == 'high')
                    const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatNotificationDate(
                          notification.createdAt,
                          user: user,
                          company: company,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: isUnread
              ? IconButton(
                  icon: const Icon(Icons.mark_email_read),
                  tooltip: 'Mark as read',
                  onPressed: () {
                    Provider.of<NotificationProvider>(
                      context,
                      listen: false,
                    ).markAsRead(notification.id);
                  },
                )
              : null,
          onTap: () => _handleNotificationTap(notification),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMenuActions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          indicatorWeight: 2.0,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'System'),
            Tab(text: 'Announcements'),
          ],
        ),
      ),
      drawer: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          final isAdmin = user?['role'] == 'admin';

          // Use AdminSideNavigation for admins, AppDrawer for employees
          if (isAdmin) {
            return const AdminSideNavigation(currentRoute: '/notifications');
          } else {
            return const AppDrawer();
          }
        },
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.isLoading &&
              notificationProvider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Debug: Log all notifications from provider
          Logger.debug(
            '🔍 NotificationScreen: Provider has ${notificationProvider.notifications.length} notifications',
          );
          Logger.debug(
            '🔍 NotificationScreen: Selected tab index: $_selectedTabIndex',
          );

          List<AppNotification> filteredNotifications =
              notificationProvider.notifications;

          // Apply tab-specific filtering (only filter if not "All" tab)
          // Note: Backend already filters by category/type, so we only need minimal client-side filtering
          switch (_selectedTabIndex) {
            case 0: // All - show everything
              // No filtering needed - backend returns all for this tab
              break;
            case 1: // System
              // Backend already filtered by category='system', but we can add extra filtering
              filteredNotifications = filteredNotifications.where((n) {
                final category = n.meta['category'] ?? '';
                final type = n.type;
                return category == 'system' ||
                    type == 'system' ||
                    type == 'event' ||
                    [
                      'attendance',
                      'leave',
                      'payroll',
                      'timesheet',
                    ].contains(type);
              }).toList();
              break;
            case 2: // Announcements
              // Backend already filtered by category='announcement', but verify
              filteredNotifications = filteredNotifications.where((n) {
                final category = n.meta['category'] ?? '';
                final type = n.type;
                return category == 'announcement' || type == 'announcement';
              }).toList();
              break;
          }

          Logger.debug(
            '🔍 NotificationScreen: After filtering: ${filteredNotifications.length} notifications',
          );

          return _buildNotificationList(filteredNotifications);
        },
      ),
    );
  }
}
