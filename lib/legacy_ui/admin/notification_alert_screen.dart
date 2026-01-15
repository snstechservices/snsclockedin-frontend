import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/admin_side_navigation.dart';
// Coach features disabled for this company
// import 'notification_alert_with_coach.dart';
import '../../providers/notification_provider.dart';
import '../../services/global_notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../utils/time_utils.dart';
import 'package:sns_rooster/utils/logger.dart';

class NotificationAlertScreen extends StatefulWidget {
  const NotificationAlertScreen({super.key});

  @override
  State<NotificationAlertScreen> createState() =>
      _NotificationAlertScreenState();
}

class _NotificationAlertScreenState extends State<NotificationAlertScreen> {
  /// Helper function to format notification date with proper UTC handling
  String _formatNotificationDate(
    DateTime dateTime, {
    Map<String, dynamic>? user,
    Map<String, dynamic>? company,
  }) {
    try {
      // Now format using TimeUtils
      // _convertToEffectiveTimezone will call toUtc() on our UTC DateTime (no change),
      // then convert from UTC to company timezone (correct conversion)
      return TimeUtils.formatDateWithFormat(
        dateTime,
        'MMM d, y HH:mm',
        user: user,
        company: company,
      );
    } catch (e) {
      Logger.error('Error formatting notification date: $e');
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: const AdminSideNavigation(currentRoute: '/notification_alerts'),
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // Consolidated menu button with all actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final token = authProvider.token;
              final notificationProvider = Provider.of<NotificationProvider>(
                context,
                listen: false,
              );

              if (token == null) return;

              switch (value) {
                case 'mark_all_read':
                  try {
                    await notificationProvider.markAllAsRead();
                    GlobalNotificationService().showSuccess(
                      'All notifications marked as read successfully',
                    );
                  } catch (e) {
                    GlobalNotificationService().showError(
                      'Error: ${e.toString()}',
                    );
                  }
                  break;
                case 'refresh':
                  try {
                    await notificationProvider.fetchNotifications(
                      refresh: true,
                    );
                    GlobalNotificationService().showSuccess(
                      'Notifications refreshed successfully',
                    );
                  } catch (e) {
                    GlobalNotificationService().showError(
                      'Failed to refresh notifications: ${e.toString()}',
                    );
                  }
                  break;
                case 'clear_all':
                  // Show confirmation dialog
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
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await notificationProvider.deleteAllNotifications();
                      // Refresh notifications to ensure UI is updated
                      await notificationProvider.fetchNotifications(
                        refresh: true,
                      );
                      GlobalNotificationService().showSuccess(
                        'All notifications cleared successfully',
                      );
                    } catch (e) {
                      GlobalNotificationService().showError(
                        'Failed to clear notifications: ${e.toString()}',
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            if (notificationProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifications = notificationProvider.notifications;

            if (notifications.isEmpty) {
              return Center(
                child: Text(
                  'No notifications.',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final companyProvider = Provider.of<CompanyProvider>(
              context,
              listen: false,
            );
            final user = authProvider.user;
            final company = companyProvider.currentCompany?.toJson();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isUnread = !notification.isRead;

                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(
                            Icons.delete,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        onDismissed: (direction) async {
                          final np = Provider.of<NotificationProvider>(
                            context,
                            listen: false,
                          );
                          try {
                            final success = await np.deleteNotification(
                              notification.id,
                            );
                            if (success) {
                              GlobalNotificationService().showSuccess(
                                'Notification deleted successfully',
                              );
                            } else {
                              GlobalNotificationService().showError(
                                'Failed to delete notification',
                              );
                              // Refresh to restore the notification since deletion failed
                              if (mounted) {
                                await np.fetchNotifications(refresh: true);
                              }
                            }
                          } catch (e) {
                            GlobalNotificationService().showError(
                              'Failed to delete notification: ${e.toString()}',
                            );
                            // Re-add the notification to the list since deletion failed
                            // The Dismissible widget already removed it, so we need to refresh
                            if (mounted) {
                              await np.fetchNotifications(refresh: true);
                            }
                          }
                        },
                        child: Card(
                          color: isUnread
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                )
                              : theme.colorScheme.surface,
                          elevation: isUnread ? 4 : 2,
                          child: ListTile(
                            leading: Icon(
                              notification.icon,
                              color: notification.getColor(theme.colorScheme),
                            ),
                            title: Text(
                              notification.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isUnread
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.body),
                                const SizedBox(height: 4),
                                Text(
                                  _formatNotificationDate(
                                    notification.createdAt,
                                    user: user,
                                    company: company,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            trailing: isUnread
                                ? IconButton(
                                    icon: const Icon(Icons.mark_email_read),
                                    tooltip: 'Mark as read',
                                    onPressed: () async {
                                      try {
                                        await Provider.of<NotificationProvider>(
                                          context,
                                          listen: false,
                                        ).markAsRead(notification.id);
                                        GlobalNotificationService().showSuccess(
                                          'Notification marked as read',
                                        );
                                      } catch (e) {
                                        GlobalNotificationService().showError(
                                          'Failed to mark as read: ${e.toString()}',
                                        );
                                      }
                                    },
                                  )
                                : null,
                            onTap: () {
                              if (isUnread) {
                                Provider.of<NotificationProvider>(
                                  context,
                                  listen: false,
                                ).markAsRead(notification.id);
                              }
                              // Handle navigation using deepLink
                              if (notification.deepLink != null &&
                                  notification.deepLink!.isNotEmpty) {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                final userRole = authProvider.user?['role'];
                                final isAdmin = userRole == 'admin';
                                final deepLink = notification.deepLink!;

                                // Check if deepLink is an employee route that should redirect admins
                                if (isAdmin) {
                                  // Map employee routes to admin routes
                                  if (deepLink == '/employee_dashboard' ||
                                      deepLink == '/attendance' ||
                                      (deepLink.startsWith('/employee/') &&
                                          deepLink.contains('attendance'))) {
                                    // For attendance-related notifications, redirect admins to admin attendance
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/admin_attendance');
                                    return;
                                  } else if (deepLink.startsWith(
                                        '/employee/leave/',
                                      ) ||
                                      deepLink == '/leave_request') {
                                    // For leave notifications, redirect admins to leave management
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/admin/leave_management');
                                    return;
                                  } else if (deepLink == '/timesheet') {
                                    // For timesheet notifications, redirect admins to admin timesheet
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/admin_timesheet');
                                    return;
                                  }
                                }

                                // For employees or other routes, use the deepLink as-is
                                Navigator.of(context).pushNamed(deepLink);
                              } else {
                                // Fallback navigation based on notification type
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                final userRole = authProvider.user?['role'];
                                final isAdmin = userRole == 'admin';

                                // Map of routes based on user role and notification type
                                final routeMap = {
                                  'leave': {
                                    'admin': '/admin/leave_management',
                                    'employee': '/leave_request',
                                  },
                                  'timesheet': {
                                    'admin': '/admin_timesheet',
                                    'employee': '/timesheet',
                                  },
                                  'attendance': {
                                    'admin': '/admin_attendance',
                                    'employee': '/attendance',
                                  },
                                };

                                final route = routeMap[notification.type];
                                if (route != null) {
                                  final targetRoute = isAdmin
                                      ? route['admin']
                                      : route['employee'];
                                  if (targetRoute != null) {
                                    Navigator.of(
                                      context,
                                    ).pushNamed(targetRoute);
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swipe_left,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Swipe left on a notification to delete it',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
