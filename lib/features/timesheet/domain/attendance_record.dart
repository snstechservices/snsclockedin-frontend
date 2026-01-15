/// Approval status for attendance records
enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

/// Break entry for attendance records
/// Alias: BreakEntry (matches legacy naming)
typedef BreakEntry = AttendanceBreak;

/// Break information for attendance records
class AttendanceBreak {
  const AttendanceBreak({
    required this.breakType,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
  });

  final String breakType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
}

/// Attendance record for timesheet view
/// Matches legacy API structure from TIMESHEET_LEGACY_AUDIT_REPORT.md
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.breaks = const [],
    this.totalBreakTimeMinutes = 0,
    this.approvalStatus = ApprovalStatus.pending,
    this.adminComment,
    this.approvedBy,
    this.approvalDate,
    this.rejectionReason,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String companyId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // pending|approved|rejected|present|absent|clocked_in|clocked_out|on_break|not_clocked_in
  final List<AttendanceBreak> breaks;
  final int totalBreakTimeMinutes;
  final ApprovalStatus approvalStatus;
  final String? adminComment;
  final String? approvedBy;
  final DateTime? approvalDate;
  final String? rejectionReason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Check if record is completed (has check-out time)
  bool get isCompleted => checkOutTime != null;

  /// Check if currently clocked in (has check-in but no check-out)
  bool get isClockedIn => checkInTime != null && checkOutTime == null;

  /// Calculate work duration (excluding breaks)
  Duration get workDuration {
    if (checkInTime == null) return Duration.zero;
    final end = checkOutTime ?? DateTime.now();
    final totalDuration = end.difference(checkInTime!);
    final breakDuration = Duration(minutes: totalBreakTimeMinutes);
    return totalDuration - breakDuration;
  }

  /// Calculate total duration (including breaks)
  Duration get totalDuration {
    if (checkInTime == null) return Duration.zero;
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime!);
  }

  /// Create from JSON (API response)
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      companyId: json['companyId'] as String,
      date: DateTime.parse(json['date'] as String),
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'] as String)
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      status: json['status'] as String? ?? 'not_clocked_in',
      breaks: (json['breaks'] as List<dynamic>?)
              ?.map((b) => AttendanceBreak(
                    breakType: b['breakType'] as String,
                    startTime: DateTime.parse(b['startTime'] as String),
                    endTime: b['endTime'] != null
                        ? DateTime.parse(b['endTime'] as String)
                        : null,
                    durationMinutes: b['duration'] as int? ?? 0,
                  ))
              .toList() ??
          [],
      totalBreakTimeMinutes: json['totalBreakTime'] as int? ?? 0,
      approvalStatus: _parseApprovalStatus(json['approvalStatus'] as String?),
      adminComment: json['adminComment'] as String?,
      approvedBy: json['approvedBy'] as String?,
      approvalDate: json['approvalDate'] != null
          ? DateTime.parse(json['approvalDate'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  static ApprovalStatus _parseApprovalStatus(String? status) {
    switch (status) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'pending':
      default:
        return ApprovalStatus.pending;
    }
  }

  /// Convert to JSON (for caching)
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'companyId': companyId,
      'date': date.toIso8601String(),
      'checkInTime': checkInTime?.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'status': status,
      'breaks': breaks.map((b) => {
            'breakType': b.breakType,
            'startTime': b.startTime.toIso8601String(),
            'endTime': b.endTime?.toIso8601String(),
            'duration': b.durationMinutes,
          }).toList(),
      'totalBreakTime': totalBreakTimeMinutes,
      'approvalStatus': approvalStatus.name,
      'adminComment': adminComment,
      'approvedBy': approvedBy,
      'approvalDate': approvalDate?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Get display label for approval status
  String get approvalStatusLabel {
    switch (approvalStatus) {
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  /// Get display label for status
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'present':
        return 'Present';
      case 'pending':
        return 'Pending';
      case 'rejected':
      case 'absent':
        return 'Absent';
      case 'clocked_in':
        return 'Clocked In';
      case 'clocked_out':
        return 'Clocked Out';
      case 'on_break':
        return 'On Break';
      case 'not_clocked_in':
        return 'Not Clocked In';
      default:
        return status;
    }
  }

  /// Get employee name (TODO: get from API when available)
  String get employeeName {
    // For now, use userId as placeholder until API includes employee name
    if (userId.length <= 8) {
      return 'Employee $userId';
    }
    return 'Employee ${userId.substring(0, 8)}...';
  }

  /// Get formatted date label (e.g., "15/01/2026")
  String get dateLabel {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  /// Get formatted time range label (e.g., "09:00 → 17:00")
  String get timeRangeLabel {
    String formatTime(DateTime? dt) {
      if (dt == null) return '—';
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final start = formatTime(checkInTime);
    final end = formatTime(checkOutTime);
    return '$start → $end';
  }

  /// Get formatted duration label (e.g., "8h 30m")
  String get durationLabel {
    final duration = workDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Get duration in minutes (for compatibility)
  int get durationMinutes => workDuration.inMinutes;
}

/// Attendance summary statistics
/// Matches GET /attendance/summary/{userId} response
class AttendanceSummary {
  const AttendanceSummary({
    required this.totalRecords,
    required this.approved,
    required this.completed,
    required this.clockedIn,
    required this.pending,
    required this.rejected,
  });

  final int totalRecords;
  final int approved;
  final int completed; // checked out
  final int clockedIn; // incomplete (no check-out)
  final int pending;
  final int rejected;

  /// Create from JSON (API response)
  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalRecords: json['totalRecords'] as int? ?? 0,
      approved: json['approved'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      clockedIn: json['clockedIn'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      rejected: json['rejected'] as int? ?? 0,
    );
  }

  /// Convert to JSON (for caching)
  Map<String, dynamic> toJson() {
    return {
      'totalRecords': totalRecords,
      'approved': approved,
      'completed': completed,
      'clockedIn': clockedIn,
      'pending': pending,
      'rejected': rejected,
    };
  }
}

