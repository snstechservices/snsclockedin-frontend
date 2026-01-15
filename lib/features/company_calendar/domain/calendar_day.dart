/// Day type enum for company calendar
enum DayType {
  working,
  holiday,
  weekend,
  nonWorking,
  override,
}

/// Company calendar day model
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.type,
    this.name,
    this.description,
    this.isRecurring = false,
  });

  final DateTime date;
  final DayType type;
  final String? name; // Holiday name, non-working day name, etc.
  final String? description;
  final bool isRecurring;

  /// Get display name for day type
  String get typeDisplay {
    switch (type) {
      case DayType.working:
        return 'Working Day';
      case DayType.holiday:
        return 'Holiday';
      case DayType.weekend:
        return 'Weekend';
      case DayType.nonWorking:
        return 'Non-Working Day';
      case DayType.override:
        return 'Override Working Day';
    }
  }

  /// Get color for day type
  String get colorHex {
    switch (type) {
      case DayType.working:
        return '#4CAF50'; // Green
      case DayType.holiday:
        return '#F44336'; // Red
      case DayType.weekend:
        return '#F44336'; // Red
      case DayType.nonWorking:
        return '#FF9800'; // Orange
      case DayType.override:
        return '#2196F3'; // Blue
    }
  }

  /// Create from JSON
  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: DateTime.parse(json['date'] as String),
      type: DayType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DayType.working,
      ),
      name: json['name'] as String?,
      description: json['description'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.name,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      'isRecurring': isRecurring,
    };
  }
}

/// Company calendar configuration
class CompanyCalendarConfig {
  const CompanyCalendarConfig({
    required this.workingDays,
    this.workingHours,
  });

  final List<String> workingDays; // ['Monday', 'Tuesday', ...]
  final Map<String, String>? workingHours; // {'start': '09:00', 'end': '17:00'}

  /// Create from JSON
  factory CompanyCalendarConfig.fromJson(Map<String, dynamic> json) {
    return CompanyCalendarConfig(
      workingDays: List<String>.from(json['workingDays'] as List),
      workingHours: json['workingHours'] != null
          ? Map<String, String>.from(json['workingHours'] as Map)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'workingDays': workingDays,
      if (workingHours != null) 'workingHours': workingHours,
    };
  }
}
