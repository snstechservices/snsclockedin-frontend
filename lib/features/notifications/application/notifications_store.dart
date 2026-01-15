import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/notifications/domain/app_notification.dart';

/// Notification filter tab
enum NotificationTab {
  all,
  unread,
}

/// Notifications store for managing notification list
class NotificationsStore extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  NotificationTab _currentTab = NotificationTab.all;

  /// Get all notifications
  List<AppNotification> get all => List.unmodifiable(_notifications);

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Get current tab
  NotificationTab get currentTab => _currentTab;

  /// Get filtered notifications based on current tab
  List<AppNotification> get filteredBy {
    switch (_currentTab) {
      case NotificationTab.all:
        return all;
      case NotificationTab.unread:
        return _notifications.where((n) => !n.isRead).toList();
    }
  }

  /// Set current tab
  void setTab(NotificationTab tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      notifyListeners();
    }
  }

  /// Mark notification as read
  void markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllRead() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Delete notification
  void delete(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  /// Add notification (for future integrations)
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Set unread count directly (for testing)
  void setUnreadCount(int count) {
    // Ensure we have enough notifications to match the count
    final now = DateTime.now();
    while (_notifications.length < count) {
      _notifications.add(
        AppNotification(
          id: 'demo-${_notifications.length + 1}',
          title: 'Demo Notification ${_notifications.length + 1}',
          body: 'This is a demo notification for testing.',
          createdAt: now.subtract(Duration(hours: _notifications.length)),
          type: NotificationType.info,
          isRead: false,
        ),
      );
    }
    // Mark notifications as read/unread to match count
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: i >= count);
    }
    notifyListeners();
  }

  /// Initialize with sample data
  void seedSampleData() {
    if (_notifications.isNotEmpty) return; // Already seeded

    final now = DateTime.now();
    _notifications.addAll([
      AppNotification(
        id: '1',
        title: 'Leave Request Approved',
        body: 'Your leave request for Jan 20-22 has been approved.',
        createdAt: now.subtract(const Duration(hours: 2)),
        type: NotificationType.success,
        isRead: false,
      ),
      AppNotification(
        id: '2',
        title: 'Timesheet Reminder',
        body: 'Please submit your timesheet for last week.',
        createdAt: now.subtract(const Duration(hours: 5)),
        type: NotificationType.warning,
        isRead: false,
      ),
      AppNotification(
        id: '3',
        title: 'System Maintenance',
        body: 'Scheduled maintenance on Jan 25, 2:00 AM - 4:00 AM.',
        createdAt: now.subtract(const Duration(days: 1)),
        type: NotificationType.info,
        isRead: true,
      ),
      AppNotification(
        id: '4',
        title: 'Attendance Alert',
        body: 'You forgot to clock out yesterday. Please update your attendance.',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        type: NotificationType.error,
        isRead: false,
      ),
      AppNotification(
        id: '5',
        title: 'New Policy Update',
        body: 'The company has updated its leave policy. Please review.',
        createdAt: now.subtract(const Duration(days: 2)),
        type: NotificationType.info,
        isRead: true,
      ),
      AppNotification(
        id: '6',
        title: 'Leave Request Pending',
        body: 'Your leave request is pending approval from your manager.',
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
        type: NotificationType.info,
        isRead: true,
      ),
      AppNotification(
        id: '7',
        title: 'Welcome!',
        body: 'Welcome to SNS Clocked In. Get started by clocking in.',
        createdAt: now.subtract(const Duration(days: 3)),
        type: NotificationType.success,
        isRead: true,
      ),
      AppNotification(
        id: '8',
        title: 'Holiday Notice',
        body: 'Company will be closed on Jan 26 for Republic Day.',
        createdAt: now.subtract(const Duration(days: 4)),
        type: NotificationType.info,
        isRead: true,
      ),
    ]);
    notifyListeners();
  }

  /// Seed demo data for testing (sets unread count to 7)
  void seedDemo() {
    final now = DateTime.now();
    _notifications.clear();
    _notifications.addAll([
      AppNotification(
        id: 'demo-1',
        title: 'Leave Request Approved',
        body: 'Your leave request for Jan 20-22 has been approved.',
        createdAt: now.subtract(const Duration(hours: 2)),
        type: NotificationType.success,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-2',
        title: 'Timesheet Reminder',
        body: 'Please submit your timesheet for last week.',
        createdAt: now.subtract(const Duration(hours: 5)),
        type: NotificationType.warning,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-3',
        title: 'Attendance Alert',
        body: 'You forgot to clock out yesterday. Please update your attendance.',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        type: NotificationType.error,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-4',
        title: 'New Policy Update',
        body: 'The company has updated its leave policy. Please review.',
        createdAt: now.subtract(const Duration(days: 2)),
        type: NotificationType.info,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-5',
        title: 'Leave Request Pending',
        body: 'Your leave request is pending approval from your manager.',
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
        type: NotificationType.info,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-6',
        title: 'Welcome!',
        body: 'Welcome to SNS Clocked In. Get started by clocking in.',
        createdAt: now.subtract(const Duration(days: 3)),
        type: NotificationType.success,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-7',
        title: 'Holiday Notice',
        body: 'Company will be closed on Jan 26 for Republic Day.',
        createdAt: now.subtract(const Duration(days: 4)),
        type: NotificationType.info,
        isRead: false,
      ),
      AppNotification(
        id: 'demo-8',
        title: 'System Maintenance',
        body: 'Scheduled maintenance on Jan 25, 2:00 AM - 4:00 AM.',
        createdAt: now.subtract(const Duration(days: 1)),
        type: NotificationType.info,
        isRead: true,
      ),
    ]);
    notifyListeners();
  }

  /// Clear demo data (sets unread count to 0)
  void clearDemo() {
    _notifications.clear();
    notifyListeners();
  }
}

