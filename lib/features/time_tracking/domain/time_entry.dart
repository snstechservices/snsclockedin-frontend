
enum TimeEntryStatus {
  present,
  late,
  absent,
  onLeave,
  halfDay,
}

class TimeEntry {
  final String id;
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final TimeEntryStatus status;
  final String? location;

  const TimeEntry({
    required this.id,
    required this.date,
    this.startTime,
    this.endTime,
    required this.status,
    this.location,
  });

  bool get isClockedIn => startTime != null && endTime == null;

  Duration get duration {
    if (startTime == null) return Duration.zero;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }
}
