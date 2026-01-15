import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import 'package:sns_clocked_in/features/time_tracking/domain/time_entry.dart';

/// Record of a completed break
class BreakRecord {
  const BreakRecord({
    required this.startTime,
    required this.endTime,
    required this.breakType,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String breakType;

  Duration get duration => endTime.difference(startTime);
}

class TimeTrackingStore extends ChangeNotifier {
  final TimeTrackingRepository _repository;
  
  TimeEntry? _currentEntry;
  List<TimeEntry> _recentEntries = [];
  bool _isLoading = false;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  String? _currentBreakType;
  List<DateTime> _breaksToday = [];
  
  // Track completed breaks (with start, end, and type)
  final List<BreakRecord> _completedBreaks = [];

  TimeTrackingStore({
    required TimeTrackingRepository repository,
  }) : _repository = repository;

  TimeEntry? get currentEntry => _currentEntry;
  List<TimeEntry> get recentEntries => _recentEntries;
  bool get isLoading => _isLoading;
  bool get isClockedIn => _currentEntry != null;
  bool get isOnBreak => _isOnBreak;
  Duration get currentDuration => _currentDuration;
  DateTime? get breakStartTime => _breakStartTime;
  String? get currentBreakType => _currentBreakType;
  int get breaksTodayCount => _breaksToday.length;
  List<BreakRecord> get completedBreaks => List.unmodifiable(_completedBreaks);
  BreakRecord? get lastBreak => _completedBreaks.isNotEmpty ? _completedBreaks.last : null;
  
  /// Get elapsed break duration
  Duration get breakElapsedDuration {
    if (_breakStartTime == null) return Duration.zero;
    return DateTime.now().difference(_breakStartTime!);
  }

  Future<void> loadInitialData() async {
    _setLoading(true);
    try {
      final results = await Future.wait([
        _repository.getClassedInEntry(),
        _repository.getRecentEntries(),
      ]);
      
      _currentEntry = results[0] as TimeEntry?;
      _recentEntries = results[1] as List<TimeEntry>;
      
      if (_currentEntry != null) {
        _startTimer();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleClockStatus() async {
    if (_isLoading) return;

    _setLoading(true);
    try {
      if (isClockedIn) {
        await _repository.clockOut();
        _currentEntry = null;
        _stopTimer();
        // Refresh history
        _recentEntries = await _repository.getRecentEntries();
      } else {
        // Mock location
        final entry = await _repository.clockIn(location: 'Office HQ');
        _currentEntry = entry;
        _startTimer();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling clock status: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _startTimer() {
    _stopTimer();
    _updateDuration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDuration();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _currentDuration = Duration.zero;
  }

  void _updateDuration() {
    if (_currentEntry?.startTime != null) {
      _currentDuration = DateTime.now().difference(_currentEntry!.startTime!);
      notifyListeners();
    }
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> startBreak({String? breakType}) async {
    if (_isLoading || !isClockedIn || _isOnBreak) return;

    _setLoading(true);
    try {
      // TODO: Call API endpoint POST /attendance/start-break with breakType
      // For now, just update local state
      _isOnBreak = true;
      _breakStartTime = DateTime.now();
      _currentBreakType = breakType ?? 'Break';
      // Track break start time for today's count
      _breaksToday.add(_breakStartTime!);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> endBreak() async {
    if (_isLoading || !_isOnBreak) return;

    _setLoading(true);
    try {
      // Save completed break to history
      if (_breakStartTime != null) {
        _completedBreaks.add(BreakRecord(
          startTime: _breakStartTime!,
          endTime: DateTime.now(),
          breakType: _currentBreakType ?? 'Break',
        ));
      }
      
      _isOnBreak = false;
      _breakStartTime = null;
      _currentBreakType = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Seed demo data for testing
  void seedDemo() {
    final now = DateTime.now();
    _currentEntry = TimeEntry(
      id: 'demo-current',
      date: now,
      startTime: now.subtract(const Duration(hours: 2)),
      status: TimeEntryStatus.present,
      location: 'Office HQ',
    );
    _recentEntries = [
      TimeEntry(
        id: 'demo-1',
        date: now.subtract(const Duration(days: 1)),
        startTime: now.subtract(const Duration(days: 1, hours: 9)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        status: TimeEntryStatus.present,
        location: 'Office HQ',
      ),
      TimeEntry(
        id: 'demo-2',
        date: now.subtract(const Duration(days: 2)),
        startTime: now.subtract(const Duration(days: 2, hours: 9, minutes: 15)),
        endTime: now.subtract(const Duration(days: 2, hours: 0, minutes: 45)),
        status: TimeEntryStatus.late,
        location: 'Office HQ',
      ),
    ];
    _isOnBreak = false;
    _breakStartTime = null;
    _currentBreakType = null;
    _breaksToday = [];
    _completedBreaks.clear();
    _startTimer();
    notifyListeners();
  }

  /// Debug-only seed that reuses seedDemo
  void seedDebugData() {
    if (!kDebugMode) return;
    if (_currentEntry != null || _recentEntries.isNotEmpty) return;
    seedDemo();
  }

  /// Clear demo data (reset to defaults)
  void clearDemo() {
    _currentEntry = null;
    _recentEntries = [];
    _isOnBreak = false;
    _breakStartTime = null;
    _currentBreakType = null;
    _breaksToday = [];
    _completedBreaks.clear();
    _stopTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
