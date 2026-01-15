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
    this.department,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.isHalfDay,
    this.halfDayPart,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.adminComment,
    this.attachments,
  });

  final String id;
  final String userId;
  final String? userName;
  final String? department;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isHalfDay;
  final HalfDayPart? halfDayPart;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? adminComment;
  final List<String>? attachments;

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

  /// Convert to JSON for API/cache
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'department': department,
      'leaveType': leaveType.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isHalfDay': isHalfDay,
      'halfDayPart': halfDayPart?.name,
      'reason': reason,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'rejectionReason': rejectionReason,
      'adminComment': adminComment,
      'attachments': attachments,
    };
  }

  /// Create from JSON
  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      department: json['department'] as String?,
      leaveType: LeaveType.values.firstWhere(
        (e) => e.name == json['leaveType'],
        orElse: () => LeaveType.annual,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      isHalfDay: json['isHalfDay'] as bool? ?? false,
      halfDayPart: json['halfDayPart'] != null
          ? HalfDayPart.values.firstWhere(
              (e) => e.name == json['halfDayPart'],
              orElse: () => HalfDayPart.am,
            )
          : null,
      reason: json['reason'] as String,
      status: LeaveStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LeaveStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
      adminComment: json['adminComment'] as String?,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List<dynamic>).map((e) => e as String).toList()
          : null,
    );
  }
}

