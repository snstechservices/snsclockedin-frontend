import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/role/role.dart';
import 'package:sns_clocked_in/core/ui/app_card.dart';
import 'package:sns_clocked_in/core/ui/app_screen_scaffold.dart';
import 'package:sns_clocked_in/core/ui/segmented_filter_bar.dart';
import 'package:sns_clocked_in/core/ui/stat_card.dart';
import 'package:sns_clocked_in/core/ui/status_badge.dart';
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
  AppNotification? _deletedNotification;
  NotificationTab _tab = NotificationTab.all;

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
    _tab = notificationsStore.currentTab;

    final totalCount = notificationsStore.all.length;
    final unreadCount = notificationsStore.unreadCount;
    final readCount = totalCount - unreadCount;

    return AppScreenScaffold(
      skipScaffold: true,
      child: Column(
        children: [
          // Quick Stats at top (always visible, match pattern)
          _buildQuickStatsSection(
            totalCount,
            unreadCount,
            readCount,
            onMarkAllRead: notificationsStore.unreadCount > 0
                ? () {
                    notificationsStore.markAllRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                : null,
          ),
          // Tabs with SegmentedFilterBar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedFilterBar<NotificationTab>(
              selected: _tab,
              onChanged: (value) {
                notificationsStore.setTab(value);
              },
              options: [
                FilterOption(label: 'All', value: NotificationTab.all),
                FilterOption(
                  label: 'Unread${notificationsStore.unreadCount > 0 ? ' (${notificationsStore.unreadCount})' : ''}',
                  value: NotificationTab.unread,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

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
    );
  }

  Widget _buildQuickStatsSection(
    int total,
    int unread,
    int read, {
    VoidCallback? onMarkAllRead,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Notifications Summary',
                style: AppTypography.lightTextTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onMarkAllRead != null)
                TextButton.icon(
                  onPressed: onMarkAllRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: AppTypography.lightTextTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total',
                  value: total.toString(),
                  color: AppColors.primary,
                  icon: Icons.notifications,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Unread',
                  value: unread.toString(),
                  color: AppColors.warning,
                  icon: Icons.notifications_active,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  title: 'Read',
                  value: read.toString(),
                  color: AppColors.success,
                  icon: Icons.done_all,
                  dense: true,
                  borderColor: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ],
      ),
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
                    _deletedNotification = null;
                  });
                }
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          onTap: () {
            if (isUnread) {
              store.markRead(notification.id);
            }
          },
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon/Badge column
                Column(
                  children: [
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
                    const SizedBox(height: AppSpacing.xs),
                    StatusBadge(
                      label: notification.type.name,
                      type: _badgeTypeFor(notification.type),
                      compact: true,
                    ),
                  ],
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

  StatusBadgeType _badgeTypeFor(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return StatusBadgeType.info;
      case NotificationType.success:
        return StatusBadgeType.approved;
      case NotificationType.warning:
        return StatusBadgeType.warning;
      case NotificationType.error:
        return StatusBadgeType.rejected;
    }
  }
}

