/// Notification type enum
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// App notification domain model
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final String? actionRoute;

  /// Get display label for notification type
  String get typeLabel {
    switch (type) {
      case NotificationType.info:
        return 'Info';
      case NotificationType.success:
        return 'Success';
      case NotificationType.warning:
        return 'Warning';
      case NotificationType.error:
        return 'Error';
    }
  }

  /// Get relative time display (Today, Yesterday, or formatted date)
  String get relativeTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      // Format as "MMM dd, yyyy" or similar
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
    }
  }

  /// Get time with hour:minute format
  String get timeDisplay {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Copy with method for immutability
  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    NotificationType? type,
    bool? isRead,
    String? actionRoute,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }
}

