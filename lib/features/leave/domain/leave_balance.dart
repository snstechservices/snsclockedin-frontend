/// Leave balance model for tracking available leave days
class LeaveBalance {
  const LeaveBalance({
    required this.annual,
    required this.sick,
    required this.casual,
    required this.maternity,
    required this.paternity,
    this.unpaidUnlimited = false,
  });

  final double annual;
  final double sick;
  final double casual;
  final double maternity;
  final double paternity;
  final bool unpaidUnlimited;

  /// Create a demo/mock leave balance
  factory LeaveBalance.demo() {
    return const LeaveBalance(
      annual: 15.0,
      sick: 10.0,
      casual: 5.0,
      maternity: 0.0,
      paternity: 0.0,
      unpaidUnlimited: true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'annual': annual,
      'sick': sick,
      'casual': casual,
      'maternity': maternity,
      'paternity': paternity,
      'unpaidUnlimited': unpaidUnlimited,
    };
  }

  /// Create from JSON
  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      annual: (json['annual'] as num).toDouble(),
      sick: (json['sick'] as num).toDouble(),
      casual: (json['casual'] as num).toDouble(),
      maternity: (json['maternity'] as num).toDouble(),
      paternity: (json['paternity'] as num).toDouble(),
      unpaidUnlimited: json['unpaidUnlimited'] as bool? ?? false,
    );
  }
}
