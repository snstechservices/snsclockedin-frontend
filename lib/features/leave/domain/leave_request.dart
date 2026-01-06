/// Leave request status
enum LeaveStatus {
  pending,
  approved,
  rejected,
}

/// Leave type enum
enum LeaveType {
  annual,
  sick,
  unpaid,
}

/// Half-day part (AM or PM)
enum HalfDayPart {
  am,
  pm,
}

/// Leave request domain model
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.userId,
    this.userName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.isHalfDay,
    this.halfDayPart,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? userName;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isHalfDay;
  final HalfDayPart? halfDayPart;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;

  /// Get display name for leave type
  String get leaveTypeDisplay {
    switch (leaveType) {
      case LeaveType.annual:
        return 'Annual';
      case LeaveType.sick:
        return 'Sick';
      case LeaveType.unpaid:
        return 'Unpaid';
    }
  }

  /// Get display name for status
  String get statusDisplay {
    switch (status) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  /// Calculate number of days (returns 0 for half day, actual days otherwise)
  int get daysCount {
    if (isHalfDay) return 0;
    return endDate.difference(startDate).inDays + 1;
  }

  /// Get display text for days count
  String get daysDisplay {
    if (isHalfDay) return 'Half Day';
    final days = daysCount;
    return '$days ${days == 1 ? 'day' : 'days'}';
  }
}

