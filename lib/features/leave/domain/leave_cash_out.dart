/// Cash out status enum
enum CashOutStatus {
  pending,
  approved,
  rejected,
}

/// Leave cash out domain model
class LeaveCashOut {
  const LeaveCashOut({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.amount,
    required this.status,
    required this.date,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveType;
  final double amount;
  final CashOutStatus status;
  final DateTime date;

  /// Get display name for status
  String get statusDisplay {
    switch (status) {
      case CashOutStatus.pending:
        return 'Pending';
      case CashOutStatus.approved:
        return 'Approved';
      case CashOutStatus.rejected:
        return 'Rejected';
    }
  }

  /// Convert to JSON for API/cache
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'amount': amount,
      'status': status.name,
      'date': date.toIso8601String(),
    };
  }

  /// Create from JSON
  factory LeaveCashOut.fromJson(Map<String, dynamic> json) {
    return LeaveCashOut(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String,
      leaveType: json['leaveType'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: CashOutStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CashOutStatus.pending,
      ),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
