/// Leave accrual log domain model
class LeaveAccrualLog {
  const LeaveAccrualLog({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.hoursAccrued,
    required this.date,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final double hoursAccrued;
  final DateTime date;

  /// Convert to JSON for API/cache
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'hoursAccrued': hoursAccrued,
      'date': date.toIso8601String(),
    };
  }

  /// Create from JSON
  factory LeaveAccrualLog.fromJson(Map<String, dynamic> json) {
    return LeaveAccrualLog(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String,
      leaveType: json['leaveType'] as String,
      hoursAccrued: (json['hoursAccrued'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
