import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:sns_clocked_in/features/time_tracking/domain/time_entry.dart';

abstract class TimeTrackingRepository {
  Future<List<TimeEntry>> getRecentEntries();
  Future<TimeEntry?> getClassedInEntry();
  Future<TimeEntry> clockIn({required String location});
  Future<TimeEntry> clockOut();
}

class MockTimeTrackingRepository implements TimeTrackingRepository {
  final _uuid = const Uuid();
  TimeEntry? _currentEntry;
  
  // Mock data store
  final List<TimeEntry> _history = [];

  MockTimeTrackingRepository() {
    // Populate some mock history
    final now = DateTime.now();
    _history.addAll([
      TimeEntry(
        id: '1',
        date: now.subtract(const Duration(days: 1)),
        startTime: now.subtract(const Duration(days: 1, hours: 9)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        status: TimeEntryStatus.present,
        location: 'Office HQ',
      ),
      TimeEntry(
        id: '2',
        date: now.subtract(const Duration(days: 2)),
        startTime: now.subtract(const Duration(days: 2, hours: 9, minutes: 15)),
        endTime: now.subtract(const Duration(days: 2, hours: 0, minutes: 45)),
        status: TimeEntryStatus.late,
        location: 'Office HQ',
      ),
    ]);
  }

  @override
  Future<List<TimeEntry>> getRecentEntries() async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network
    return List.from(_history); // Return copy
  }

  @override
  Future<TimeEntry?> getClassedInEntry() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _currentEntry;
  }

  @override
  Future<TimeEntry> clockIn({required String location}) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final now = DateTime.now();
    final newEntry = TimeEntry(
      id: _uuid.v4(),
      date: now,
      startTime: now,
      status: TimeEntryStatus.present, // simplistic logic
      location: location,
    );
    
    _currentEntry = newEntry;
    return newEntry;
  }

  @override
  Future<TimeEntry> clockOut() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_currentEntry == null) {
      throw Exception('Not clocked in');
    }

    final completedEntry = TimeEntry(
      id: _currentEntry!.id,
      date: _currentEntry!.date,
      startTime: _currentEntry!.startTime,
      endTime: DateTime.now(),
      status: _currentEntry!.status,
      location: _currentEntry!.location,
    );

    _history.insert(0, completedEntry);
    _currentEntry = null;
    return completedEntry;
  }
}
