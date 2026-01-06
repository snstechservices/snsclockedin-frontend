import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/features/notifications/application/notifications_store.dart';
import 'package:sns_clocked_in/features/notifications/domain/app_notification.dart';
import 'package:sns_clocked_in/design_system/app_colors.dart';
import 'package:sns_clocked_in/design_system/app_radius.dart';
import 'package:sns_clocked_in/design_system/app_spacing.dart';
import 'package:sns_clocked_in/design_system/app_typography.dart';

/// Notifications screen for employee and admin
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.roleScope,
  });

  final Role roleScope;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _deletedNotificationId;
  AppNotification? _deletedNotification;

  @override
  void initState() {
    super.initState();
    // Seed sample data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsStore>().seedSampleData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsStore = context.watch<NotificationsStore>();
    final notifications = notificationsStore.filteredBy;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.lightTextTheme.headlineMedium,
        ),
        actions: [
          if (notificationsStore.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () {
                notificationsStore.markAllRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: AppSpacing.lgAll,
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabChip(
                      'All',
                      NotificationTab.all,
                      notificationsStore,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildTabChip(
                      'Unread',
                      NotificationTab.unread,
                      notificationsStore,
                      badgeCount: notificationsStore.unreadCount,
                    ),
                  ),
                ],
              ),
            ),

            // Notifications List
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState(notificationsStore.currentTab)
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        top: AppSpacing.sm,
                        bottom: AppSpacing.xl,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationCard(
                          notifications[index],
                          notificationsStore,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(
    String label,
    NotificationTab tab,
    NotificationsStore store, {
    int? badgeCount,
  }) {
    final isSelected = store.currentTab == tab;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount != null && badgeCount > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                badgeCount.toString(),
                style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          store.setTab(tab);
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildEmptyState(NotificationTab tab) {
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab == NotificationTab.unread
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tab == NotificationTab.unread
                  ? 'No Unread Notifications'
                  : 'No Notifications',
              style: AppTypography.lightTextTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tab == NotificationTab.unread
                  ? 'You\'re all caught up!'
                  : 'You don\'t have any notifications yet.',
              style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    AppNotification notification,
    NotificationsStore store,
  ) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.mediumAll,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        setState(() {
          _deletedNotificationId = notification.id;
          _deletedNotification = notification;
        });
        store.delete(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (_deletedNotification != null) {
                  store.addNotification(_deletedNotification!);
                  setState(() {
                    _deletedNotificationId = null;
                    _deletedNotification = null;
                  });
                }
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
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
        child: InkWell(
          onTap: () {
            if (isUnread) {
              store.markRead(notification.id);
            }
          },
          borderRadius: AppRadius.mediumAll,
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification.type).withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(
                    _getTypeIcon(notification.type),
                    color: _getTypeColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTypography.lightTextTheme.bodyLarge?.copyWith(
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification.body,
                        style: AppTypography.lightTextTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${notification.relativeTime} at ${notification.timeDisplay}',
                        style: AppTypography.lightTextTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return AppColors.primary;
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return AppColors.error;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.error:
        return Icons.error_outline;
    }
  }
}

