import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/timesheet/data/timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:uuid/uuid.dart';

// TODO: Hook into ConnectivityService when available in v2
// When connection is restored, call store.onConnectivityRestored()
// Example:
//   connectivityService.addConnectivityListener((isOnline) {
//     if (isOnline && wasOffline) {
//       store.onConnectivityRestored();
//     }
//   });

/// Date range preset for timesheet view
enum TimesheetRangePreset {
  today,
  thisWeek,
  thisMonth,
  custom,
}

/// Timesheet store for managing timesheet state
/// Matches legacy behavior with cache-first loading
class TimesheetStore extends ChangeNotifier {
  TimesheetStore({
    required TimesheetRepository repository,
    required String companyId,
    required String userId,
  })  : _repository = repository,
        _companyId = companyId,
        _userId = userId;

  final TimesheetRepository _repository;
  final String _companyId;
  final String _userId;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  TimesheetRangePreset _currentPreset = TimesheetRangePreset.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  List<AttendanceRecord> _records = [];
  AttendanceSummary? _summary;
  DateTime? _lastUpdatedAt;
  bool _isFromCache = false;
  bool _isStale = false;
  bool _hasLoadedOnce = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TimesheetRangePreset get currentPreset => _currentPreset;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  List<AttendanceRecord> get records => List.unmodifiable(_records);
  AttendanceSummary? get summary => _summary;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get isFromCache => _isFromCache;
  bool get isStale => _isStale;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Get current date range based on preset
  ({DateTime start, DateTime end}) get currentRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_currentPreset) {
      case TimesheetRangePreset.today:
        return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
      case TimesheetRangePreset.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        return (start: weekStart, end: weekEnd);
      case TimesheetRangePreset.thisMonth:
        final monthStart = DateTime(today.year, today.month, 1);
        final monthEnd = DateTime(today.year, today.month + 1, 1).subtract(const Duration(seconds: 1));
        return (start: monthStart, end: monthEnd);
      case TimesheetRangePreset.custom:
        if (_customStartDate == null || _customEndDate == null) {
          // Fallback to today if custom dates not set
          return (start: today, end: today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
        }
        return (start: _customStartDate!, end: _customEndDate!);
    }
  }

  /// Set date range preset
  void setRangePreset(TimesheetRangePreset preset) {
    if (_currentPreset != preset) {
      _currentPreset = preset;
      notifyListeners();
      load();
    }
  }

  /// Set custom date range
  void setCustomRange(DateTime start, DateTime end) {
    _customStartDate = start;
    _customEndDate = end;
    _currentPreset = TimesheetRangePreset.custom;
    notifyListeners();
    load();
  }

  /// Load timesheet data (records + summary)
  Future<void> load({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _isFromCache = false;
    _isStale = false;
    notifyListeners();

    try {
      final range = currentRange;
      
      // Load records and summary in parallel
      final results = await Future.wait([
        _repository.fetchMyTimesheet(
          companyId: _companyId,
          userId: _userId,
          start: range.start,
          end: range.end,
          forceRefresh: forceRefresh,
        ),
        _repository.fetchSummary(
          companyId: _companyId,
          userId: _userId,
          forceRefresh: forceRefresh,
        ),
      ]);

      final recordsResult = results[0] as FetchResult<List<AttendanceRecord>>;
      _records = recordsResult.data;
      _isStale = recordsResult.isStale;
      _isFromCache = recordsResult.isStale;
      
      _summary = results[1] as AttendanceSummary;
      _lastUpdatedAt = DateTime.now();
      _errorMessage = null;
      _hasLoadedOnce = true;
    } catch (e) {
      _errorMessage = e.toString();
      // If we have cached records, mark as stale and mark as loaded
      if (_records.isNotEmpty) {
        _isStale = true;
        _isFromCache = true;
        _hasLoadedOnce = true; // We have data, so we've loaded once
      } else {
        _records = [];
        _summary = null;
        // Don't set hasLoadedOnce = false here - keep it true if it was already true
        // Only set to true if we actually got some data (even if stale)
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh timesheet data (force refresh from network)
  /// Never resets hasLoadedOnce on failure
  Future<void> refresh() async {
    final previousHasLoadedOnce = _hasLoadedOnce;
    await load(forceRefresh: true);
    // Ensure hasLoadedOnce is never reset on failure
    if (!_hasLoadedOnce && previousHasLoadedOnce) {
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  /// Auto-refresh when connectivity is restored
  /// Call this from a connectivity listener when connection is restored
  /// Matches legacy behavior: wait 1 second then refresh
  Future<void> onConnectivityRestored() async {
    await Future.delayed(const Duration(seconds: 1));
    await refresh();
  }

  /// Get summary statistics
  /// Returns API summary if available, otherwise computes from records
  AttendanceSummary get computedSummary {
    if (_summary != null) {
      return _summary!;
    }

    // Fallback: compute from records if summary not loaded
    final totalRecords = _records.length;
    final approved = _records.where((r) => r.approvalStatus == ApprovalStatus.approved).length;
    final pending = _records.where((r) => r.approvalStatus == ApprovalStatus.pending).length;
    final rejected = _records.where((r) => r.approvalStatus == ApprovalStatus.rejected).length;
    final completed = _records.where((r) => r.isCompleted).length;
    final clockedIn = _records.where((r) => r.isClockedIn).length;

    return AttendanceSummary(
      totalRecords: totalRecords,
      approved: approved,
      pending: pending,
      rejected: rejected,
      completed: completed,
      clockedIn: clockedIn,
    );
  }

  /// Get records grouped by date (local date)
  Map<DateTime, List<AttendanceRecord>> get groupedRecords {
    final grouped = <DateTime, List<AttendanceRecord>>{};
    
    for (final record in _records) {
      // Use local date (without time) as key
      final localDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      
      grouped.putIfAbsent(localDate, () => []).add(record);
    }
    
    // Sort by date (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <DateTime, List<AttendanceRecord>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  /// Debug-only seed that reuses seedDemo
  void seedDebugData() {
    if (!kDebugMode) return;
    if (_records.isNotEmpty) return;
    seedDemo();
  }

  /// Seed demo data for UI testing
  void seedDemo() {
    final now = DateTime.now();
    final uuid = const Uuid();
    
    _records = [
      // Today - approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: _userId,
        companyId: _companyId,
        date: now,
        checkInTime: DateTime(now.year, now.month, now.day, 9, 0),
        checkOutTime: DateTime(now.year, now.month, now.day, 17, 30),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 30,
      ),
      // Yesterday - pending
      AttendanceRecord(
        id: uuid.v4(),
        userId: _userId,
        companyId: _companyId,
        date: now.subtract(const Duration(days: 1)),
        checkInTime: DateTime(now.year, now.month, now.day - 1, 8, 45),
        checkOutTime: DateTime(now.year, now.month, now.day - 1, 17, 15),
        status: 'pending',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 45,
      ),
      // 2 days ago - clocked in (no checkout)
      AttendanceRecord(
        id: uuid.v4(),
        userId: _userId,
        companyId: _companyId,
        date: now.subtract(const Duration(days: 2)),
        checkInTime: DateTime(now.year, now.month, now.day - 2, 9, 15),
        checkOutTime: null,
        status: 'clocked_in',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 0,
      ),
      // 3 days ago - rejected
      AttendanceRecord(
        id: uuid.v4(),
        userId: _userId,
        companyId: _companyId,
        date: now.subtract(const Duration(days: 3)),
        checkInTime: DateTime(now.year, now.month, now.day - 3, 10, 0),
        checkOutTime: DateTime(now.year, now.month, now.day - 3, 16, 0),
        status: 'rejected',
        approvalStatus: ApprovalStatus.rejected,
        rejectionReason: 'Incomplete work hours',
        totalBreakTimeMinutes: 60,
      ),
      // 4 days ago - approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: _userId,
        companyId: _companyId,
        date: now.subtract(const Duration(days: 4)),
        checkInTime: DateTime(now.year, now.month, now.day - 4, 8, 30),
        checkOutTime: DateTime(now.year, now.month, now.day - 4, 17, 0),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 30,
      ),
    ];
    
    // Compute summary from records
    _summary = computedSummary;
    _lastUpdatedAt = DateTime.now();
    _isFromCache = false;
    _isStale = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear demo data
  /// Resets all state including loading flags and hasLoadedOnce
  void clearDemo() {
    _records = [];
    _summary = null;
    _lastUpdatedAt = null;
    _isFromCache = false;
    _isStale = false;
    _errorMessage = null;
    _isLoading = false;
    _hasLoadedOnce = false;
    notifyListeners();
  }
}

