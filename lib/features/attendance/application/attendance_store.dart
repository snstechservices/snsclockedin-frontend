import 'package:flutter/foundation.dart';

/// Clock status enum
enum ClockStatus {
  notClockedIn,
  clockedIn,
  onBreak,
}

/// Attendance store for managing clock status
class AttendanceStore extends ChangeNotifier {
  ClockStatus _status = ClockStatus.notClockedIn;

  /// Current clock status
  ClockStatus get status => _status;

  /// Set clock status (for testing/debugging)
  void setStatus(ClockStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Clock in
  void clockIn() {
    _status = ClockStatus.clockedIn;
    notifyListeners();
  }

  /// Clock out
  void clockOut() {
    _status = ClockStatus.notClockedIn;
    notifyListeners();
  }

  /// Start break
  void startBreak() {
    if (_status == ClockStatus.clockedIn) {
      _status = ClockStatus.onBreak;
      notifyListeners();
    }
  }

  /// End break
  void endBreak() {
    if (_status == ClockStatus.onBreak) {
      _status = ClockStatus.clockedIn;
      notifyListeners();
    }
  }
}

