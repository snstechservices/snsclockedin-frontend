import 'package:flutter/material.dart';

/// Attendance event type for timeline
enum AttendanceEventType {
  clockIn,
  clockOut,
  breakStart,
  breakEnd,
}

/// Attendance event for timeline display
class AttendanceEvent {
  const AttendanceEvent({
    required this.type,
    required this.time,
    this.location,
  });

  final AttendanceEventType type;
  final DateTime time;
  final String? location;

  String get label {
    switch (type) {
      case AttendanceEventType.clockIn:
        return 'Clock In';
      case AttendanceEventType.clockOut:
        return 'Clock Out';
      case AttendanceEventType.breakStart:
        return 'Break Start';
      case AttendanceEventType.breakEnd:
        return 'Break End';
    }
  }

  IconData get icon {
    switch (type) {
      case AttendanceEventType.clockIn:
        return Icons.login;
      case AttendanceEventType.clockOut:
        return Icons.logout;
      case AttendanceEventType.breakStart:
        return Icons.coffee;
      case AttendanceEventType.breakEnd:
        return Icons.coffee_outlined;
    }
  }

  Color get color {
    switch (type) {
      case AttendanceEventType.clockIn:
        return const Color(0xFF4CAF50); // Green
      case AttendanceEventType.clockOut:
        return const Color(0xFFF44336); // Red
      case AttendanceEventType.breakStart:
        return const Color(0xFFFF9800); // Orange
      case AttendanceEventType.breakEnd:
        return const Color(0xFF2196F3); // Blue
    }
  }

  String get timeDisplay {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

