import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sns_clocked_in/features/timesheet_admin/data/admin_timesheet_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:uuid/uuid.dart';

/// Admin timesheet store for managing pending and approved timesheets
class AdminTimesheetStore extends ChangeNotifier {
  AdminTimesheetStore({
    required AdminTimesheetRepository repository,
  }) : _repository = repository;

  final AdminTimesheetRepository _repository;

  // State
  List<AttendanceRecord> _pendingRecords = [];
  List<AttendanceRecord> _approvedRecords = [];
  bool _isLoadingPending = false;
  bool _isLoadingApproved = false;
  String? _errorPending;
  String? _errorApproved;
  int _selectedTab = 0; // 0 = all records, 1 = pending, 2 = approved
  
  // Filter state
  String? _selectedEmployeeId;
  DateTimeRange? _dateRange;

  // Getters
  List<AttendanceRecord> get pendingRecords => List.unmodifiable(_pendingRecords);
  List<AttendanceRecord> get approvedRecords => List.unmodifiable(_approvedRecords);
  bool get isLoadingPending => _isLoadingPending;
  bool get isLoadingApproved => _isLoadingApproved;
  bool get isLoading => _isLoadingPending || _isLoadingApproved;
  String? get errorPending => _errorPending;
  String? get errorApproved => _errorApproved;
  String? get error => _errorPending ?? _errorApproved;
  int get selectedTab => _selectedTab;
  String? get selectedEmployeeId => _selectedEmployeeId;
  DateTimeRange? get dateRange => _dateRange;
  
  /// Get all records (pending + approved) for "All Records" tab
  List<AttendanceRecord> get allRecords {
    return [..._pendingRecords, ..._approvedRecords];
  }
  
  /// Get filtered all records based on employee and date range
  List<AttendanceRecord> get filteredAllRecords {
    var records = allRecords;
    
    // Filter by employee
    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      records = records.where((r) => r.userId == _selectedEmployeeId).toList();
    }
    
    // Filter by date range
    if (_dateRange != null) {
      records = records.where((r) {
        final recordDate = DateTime(r.date.year, r.date.month, r.date.day);
        final rangeStart = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final rangeEnd = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        // Include records that fall within the range (inclusive)
        return recordDate.compareTo(rangeStart) >= 0 && recordDate.compareTo(rangeEnd) <= 0;
      }).toList();
    }
    
    return records;
  }
  
  /// Get filtered pending records
  List<AttendanceRecord> get filteredPendingRecords {
    var records = _pendingRecords;
    
    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      records = records.where((r) => r.userId == _selectedEmployeeId).toList();
    }
    
    if (_dateRange != null) {
      records = records.where((r) {
        final recordDate = DateTime(r.date.year, r.date.month, r.date.day);
        final rangeStart = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final rangeEnd = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        // Include records that fall within the range (inclusive)
        return recordDate.compareTo(rangeStart) >= 0 && recordDate.compareTo(rangeEnd) <= 0;
      }).toList();
    }
    
    return records;
  }
  
  /// Get filtered approved records
  List<AttendanceRecord> get filteredApprovedRecords {
    var records = _approvedRecords;
    
    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      records = records.where((r) => r.userId == _selectedEmployeeId).toList();
    }
    
    if (_dateRange != null) {
      records = records.where((r) {
        final recordDate = DateTime(r.date.year, r.date.month, r.date.day);
        final rangeStart = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final rangeEnd = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        // Include records that fall within the range (inclusive)
        return recordDate.compareTo(rangeStart) >= 0 && recordDate.compareTo(rangeEnd) <= 0;
      }).toList();
    }
    
    return records;
  }

  /// Set selected tab (0 = all records, 1 = pending, 2 = approved)
  void setSelectedTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      notifyListeners();
    }
  }
  
  /// Set employee filter
  void setEmployeeFilter(String? employeeId) {
    if (_selectedEmployeeId != employeeId) {
      _selectedEmployeeId = employeeId;
      notifyListeners();
    }
  }
  
  /// Set date range filter
  void setDateRange(DateTimeRange? range) {
    if (_dateRange != range) {
      _dateRange = range;
      notifyListeners();
    }
  }
  
  /// Clear all filters
  void clearFilters() {
    _selectedEmployeeId = null;
    _dateRange = null;
    notifyListeners();
  }

  /// Get eligible records for bulk auto-approve (completed/checked out only)
  List<AttendanceRecord> get eligibleForBulkApprove {
    return _pendingRecords.where((r) => r.isCompleted).toList();
  }

  /// Get total records count (pending + approved)
  int get totalCount => _pendingRecords.length + _approvedRecords.length;

  /// Get present/completed records count (has check-out)
  int get presentCount {
    return _pendingRecords.where((r) => r.isCompleted).length +
        _approvedRecords.where((r) => r.isCompleted).length;
  }

  /// Get on break records count (has active breaks)
  int get onBreakCount {
    return _pendingRecords.where((r) => r.breaks.any((b) => b.endTime == null)).length +
        _approvedRecords.where((r) => r.breaks.any((b) => b.endTime == null)).length;
  }

  /// Load pending timesheets
  Future<void> loadPending({bool forceRefresh = false}) async {
    _isLoadingPending = true;
    _errorPending = null;
    notifyListeners();

    try {
      final records = await _repository.fetchPending(forceRefresh: forceRefresh);
      // In debug mode, preserve seed data if API returns empty
      if (kDebugMode && records.isEmpty && _pendingRecords.isNotEmpty) {
        // Keep existing seed data
        _errorPending = null;
      } else {
        _pendingRecords = records;
        _errorPending = null;
      }
    } catch (e) {
      // In debug mode, preserve seed data on error
      if (kDebugMode && _pendingRecords.isNotEmpty) {
        _errorPending = null; // Don't show error if we have seed data
      } else {
        _errorPending = e.toString();
        _pendingRecords = [];
      }
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Load approved timesheets
  Future<void> loadApproved({bool forceRefresh = false}) async {
    _isLoadingApproved = true;
    _errorApproved = null;
    notifyListeners();

    try {
      final records = await _repository.fetchApproved(forceRefresh: forceRefresh);
      // In debug mode, preserve seed data if API returns empty
      if (kDebugMode && records.isEmpty && _approvedRecords.isNotEmpty) {
        // Keep existing seed data
        _errorApproved = null;
      } else {
        _approvedRecords = records;
        _errorApproved = null;
      }
    } catch (e) {
      // In debug mode, preserve seed data on error
      if (kDebugMode && _approvedRecords.isNotEmpty) {
        _errorApproved = null; // Don't show error if we have seed data
      } else {
        _errorApproved = e.toString();
        _approvedRecords = [];
      }
    } finally {
      _isLoadingApproved = false;
      notifyListeners();
    }
  }

  /// Refresh all (pending + approved)
  Future<void> refreshAll() async {
    await Future.wait([
      loadPending(forceRefresh: true),
      loadApproved(forceRefresh: true),
    ]);
  }

  /// Approve a timesheet (optimistic update)
  Future<void> approve(String attendanceId, {String? comment}) async {
    return approveOne(attendanceId, comment: comment);
  }

  /// Approve a timesheet (optimistic update)
  Future<void> approveOne(String attendanceId, {String? comment}) async {
    // Optimistic update: remove from pending immediately
    final record = _pendingRecords.firstWhere(
      (r) => r.id == attendanceId,
      orElse: () => throw Exception('Record not found'),
    );
    _pendingRecords.removeWhere((r) => r.id == attendanceId);
    notifyListeners();

    try {
      await _repository.approveTimesheet(attendanceId, adminComment: comment);
      // Refresh both lists in background
      await Future.wait([
        loadPending(forceRefresh: true),
        loadApproved(forceRefresh: true),
      ]);
      _errorPending = null;
      _errorApproved = null;
    } catch (e) {
      // Rollback optimistic update on error
      _pendingRecords.add(record);
      _pendingRecords.sort((a, b) => b.date.compareTo(a.date));
      _errorPending = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Reject a timesheet (optimistic update)
  Future<void> reject(String attendanceId, {required String reason}) async {
    return rejectOne(attendanceId, reason: reason);
  }

  /// Reject a timesheet (optimistic update)
  Future<void> rejectOne(String attendanceId, {required String reason}) async {
    // Optimistic update: remove from pending immediately
    final record = _pendingRecords.firstWhere(
      (r) => r.id == attendanceId,
      orElse: () => throw Exception('Record not found'),
    );
    _pendingRecords.removeWhere((r) => r.id == attendanceId);
    notifyListeners();

    try {
      await _repository.rejectTimesheet(attendanceId, reason: reason);
      // Refresh pending list in background
      await loadPending(forceRefresh: true);
      _errorPending = null;
    } catch (e) {
      // Rollback optimistic update on error
      _pendingRecords.add(record);
      _pendingRecords.sort((a, b) => b.date.compareTo(a.date));
      _errorPending = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Bulk auto-approve eligible records (completed/checked out only)
  Future<Map<String, dynamic>> bulkAutoApprove() async {
    final eligible = eligibleForBulkApprove;
    if (eligible.isEmpty) {
      throw Exception('No eligible records for bulk approval');
    }

    final recordIds = eligible.map((r) => r.id).toList();

    try {
      final result = await _repository.bulkAutoApprove(recordIds: recordIds);
      
      // Optimistic update: remove approved records from pending
      _pendingRecords.removeWhere((r) => recordIds.contains(r.id));
      notifyListeners();

      // Refresh both lists in background
      await Future.wait([
        loadPending(forceRefresh: true),
        loadApproved(forceRefresh: true),
      ]);

      _errorPending = null;
      _errorApproved = null;
      return result;
    } catch (e) {
      _errorPending = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Seed debug data for testing (only in debug mode)
  void seedDebugData() {
    if (!kDebugMode) return;
    if (_pendingRecords.isNotEmpty || _approvedRecords.isNotEmpty) return;
    
    final uuid = const Uuid();
    final now = DateTime.now();
    final companyId = 'company-1';

    // Create sample pending records with different employees and dates
    _pendingRecords = [
      // Today - Employee 1 - Completed (eligible for bulk approve)
      AttendanceRecord(
        id: uuid.v4(),
        userId: '1', // John Doe
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day),
        checkInTime: DateTime(now.year, now.month, now.day, 9, 0),
        checkOutTime: DateTime(now.year, now.month, now.day, 17, 30),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 30,
        breaks: [
          AttendanceBreak(
            breakType: 'Lunch',
            startTime: DateTime(now.year, now.month, now.day, 12, 30),
            endTime: DateTime(now.year, now.month, now.day, 13, 0),
            durationMinutes: 30,
          ),
        ],
        createdAt: DateTime(now.year, now.month, now.day, 9, 0),
      ),
      // Yesterday - Employee 2 - Completed (eligible for bulk approve)
      AttendanceRecord(
        id: uuid.v4(),
        userId: '2', // Jane Smith
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 1),
        checkInTime: DateTime(now.year, now.month, now.day - 1, 8, 45),
        checkOutTime: DateTime(now.year, now.month, now.day - 1, 17, 15),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 45,
        breaks: [
          AttendanceBreak(
            breakType: 'Lunch',
            startTime: DateTime(now.year, now.month, now.day - 1, 12, 0),
            endTime: DateTime(now.year, now.month, now.day - 1, 12, 45),
            durationMinutes: 45,
          ),
        ],
        createdAt: DateTime(now.year, now.month, now.day - 1, 8, 45),
      ),
      // 2 days ago - Employee 3 - Clocked in (not eligible - no checkout)
      AttendanceRecord(
        id: uuid.v4(),
        userId: '3', // Bob Johnson
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 2),
        checkInTime: DateTime(now.year, now.month, now.day - 2, 9, 15),
        checkOutTime: null,
        status: 'clocked_in',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 0,
        breaks: [
          AttendanceBreak(
            breakType: 'Coffee',
            startTime: DateTime(now.year, now.month, now.day - 2, 10, 30),
            endTime: null, // Active break
            durationMinutes: 0,
          ),
        ],
        createdAt: DateTime(now.year, now.month, now.day - 2, 9, 15),
      ),
      // 3 days ago - Employee 1 - Completed
      AttendanceRecord(
        id: uuid.v4(),
        userId: '1', // John Doe
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 3),
        checkInTime: DateTime(now.year, now.month, now.day - 3, 8, 30),
        checkOutTime: DateTime(now.year, now.month, now.day - 3, 17, 0),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 60,
        breaks: [
          AttendanceBreak(
            breakType: 'Lunch',
            startTime: DateTime(now.year, now.month, now.day - 3, 12, 0),
            endTime: DateTime(now.year, now.month, now.day - 3, 13, 0),
            durationMinutes: 60,
          ),
        ],
        createdAt: DateTime(now.year, now.month, now.day - 3, 8, 30),
      ),
      // 4 days ago - Employee 4 - Completed
      AttendanceRecord(
        id: uuid.v4(),
        userId: '4', // Alice Williams
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 4),
        checkInTime: DateTime(now.year, now.month, now.day - 4, 9, 30),
        checkOutTime: DateTime(now.year, now.month, now.day - 4, 18, 0),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 30,
        createdAt: DateTime(now.year, now.month, now.day - 4, 9, 30),
      ),
    ];

    // Create sample approved records
    _approvedRecords = [
      // Today - Employee 2 - Approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: '2', // Jane Smith
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day),
        checkInTime: DateTime(now.year, now.month, now.day, 8, 0),
        checkOutTime: DateTime(now.year, now.month, now.day, 16, 30),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 30,
        approvedBy: 'admin-1',
        approvalDate: DateTime(now.year, now.month, now.day, 17, 0),
        adminComment: 'Approved',
        createdAt: DateTime(now.year, now.month, now.day, 8, 0),
        updatedAt: DateTime(now.year, now.month, now.day, 17, 0),
      ),
      // Yesterday - Employee 3 - Approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: '3', // Bob Johnson
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 1),
        checkInTime: DateTime(now.year, now.month, now.day - 1, 9, 0),
        checkOutTime: DateTime(now.year, now.month, now.day - 1, 17, 30),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 45,
        approvedBy: 'admin-1',
        approvalDate: DateTime(now.year, now.month, now.day - 1, 18, 0),
        adminComment: 'Approved',
        createdAt: DateTime(now.year, now.month, now.day - 1, 9, 0),
        updatedAt: DateTime(now.year, now.month, now.day - 1, 18, 0),
      ),
      // 2 days ago - Employee 1 - Approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: '1', // John Doe
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 2),
        checkInTime: DateTime(now.year, now.month, now.day - 2, 8, 15),
        checkOutTime: DateTime(now.year, now.month, now.day - 2, 17, 0),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 30,
        approvedBy: 'admin-1',
        approvalDate: DateTime(now.year, now.month, now.day - 2, 17, 30),
        adminComment: 'Approved',
        createdAt: DateTime(now.year, now.month, now.day - 2, 8, 15),
        updatedAt: DateTime(now.year, now.month, now.day - 2, 17, 30),
      ),
      // 3 days ago - Employee 4 - Approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: '4', // Alice Williams
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 3),
        checkInTime: DateTime(now.year, now.month, now.day - 3, 9, 0),
        checkOutTime: DateTime(now.year, now.month, now.day - 3, 16, 45),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 45,
        approvedBy: 'admin-1',
        approvalDate: DateTime(now.year, now.month, now.day - 3, 17, 0),
        adminComment: 'Approved',
        createdAt: DateTime(now.year, now.month, now.day - 3, 9, 0),
        updatedAt: DateTime(now.year, now.month, now.day - 3, 17, 0),
      ),
      // 5 days ago - Employee 2 - Approved
      AttendanceRecord(
        id: uuid.v4(),
        userId: '2', // Jane Smith
        companyId: companyId,
        date: DateTime(now.year, now.month, now.day - 5),
        checkInTime: DateTime(now.year, now.month, now.day - 5, 8, 30),
        checkOutTime: DateTime(now.year, now.month, now.day - 5, 17, 15),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        totalBreakTimeMinutes: 30,
        approvedBy: 'admin-1',
        approvalDate: DateTime(now.year, now.month, now.day - 5, 17, 30),
        adminComment: 'Approved',
        createdAt: DateTime(now.year, now.month, now.day - 5, 8, 30),
        updatedAt: DateTime(now.year, now.month, now.day - 5, 17, 30),
      ),
    ];

    // Sort records by date (newest first)
    _pendingRecords.sort((a, b) => b.date.compareTo(a.date));
    _approvedRecords.sort((a, b) => b.date.compareTo(a.date));

    _errorPending = null;
    _errorApproved = null;
    notifyListeners();
  }
}

