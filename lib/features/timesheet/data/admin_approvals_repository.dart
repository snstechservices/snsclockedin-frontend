import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';
import 'package:uuid/uuid.dart';

/// Result class for fetch operations that includes stale cache flag
class FetchResult<T> {
  const FetchResult({
    required this.data,
    required this.isStale,
  });

  final T data;
  final bool isStale;
}

/// Abstract repository interface for admin timesheet approvals
abstract class AdminApprovalsRepositoryInterface {
  Future<FetchResult<List<AttendanceRecord>>> fetchPending({bool forceRefresh = false});
  Future<FetchResult<List<AttendanceRecord>>> fetchApproved({bool forceRefresh = false});
  Future<void> approve(String attendanceId, {String? comment});
  Future<void> reject(String attendanceId, {required String reason});
  Future<void> bulkAutoApprove();
}

/// Mock repository for admin timesheet approvals (for development/testing)
/// Returns mock data without making API calls
class MockAdminApprovalsRepository implements AdminApprovalsRepositoryInterface {
  final List<AttendanceRecord> _pendingRecords = [];
  final List<AttendanceRecord> _approvedRecords = [];
  final _uuid = const Uuid();

  MockAdminApprovalsRepository() {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    
    // Create pending records
    _pendingRecords.addAll([
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user1',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 1)),
        checkInTime: now.subtract(const Duration(days: 1, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 1, hours: 17)),
        status: 'completed',
        approvalStatus: ApprovalStatus.pending,
        breaks: [
          AttendanceBreak(
            breakType: 'lunch',
            startTime: now.subtract(const Duration(days: 1, hours: 13)),
            endTime: now.subtract(const Duration(days: 1, hours: 14)),
            durationMinutes: 60,
          ),
        ],
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user2',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 2)),
        checkInTime: now.subtract(const Duration(days: 2, hours: 8, minutes: 30)),
        checkOutTime: now.subtract(const Duration(days: 2, hours: 17, minutes: 15)),
        status: 'completed',
        approvalStatus: ApprovalStatus.pending,
        breaks: [
          AttendanceBreak(
            breakType: 'tea_break',
            startTime: now.subtract(const Duration(days: 2, hours: 10, minutes: 30)),
            endTime: now.subtract(const Duration(days: 2, hours: 10, minutes: 45)),
            durationMinutes: 15,
          ),
          AttendanceBreak(
            breakType: 'lunch',
            startTime: now.subtract(const Duration(days: 2, hours: 13)),
            endTime: now.subtract(const Duration(days: 2, hours: 14)),
            durationMinutes: 60,
          ),
        ],
        totalBreakTimeMinutes: 75,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user3',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 3)),
        checkInTime: now.subtract(const Duration(days: 3, hours: 9, minutes: 15)),
        checkOutTime: now.subtract(const Duration(days: 3, hours: 18)),
        status: 'completed',
        approvalStatus: ApprovalStatus.pending,
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);

    // Create approved records
    _approvedRecords.addAll([
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user4',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 5)),
        checkInTime: now.subtract(const Duration(days: 5, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 5, hours: 17)),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin1',
        approvalDate: now.subtract(const Duration(days: 4)),
        adminComment: 'Approved',
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      AttendanceRecord(
        id: _uuid.v4(),
        userId: 'user5',
        companyId: 'company1',
        date: now.subtract(const Duration(days: 6)),
        checkInTime: now.subtract(const Duration(days: 6, hours: 8, minutes: 45)),
        checkOutTime: now.subtract(const Duration(days: 6, hours: 17, minutes: 30)),
        status: 'approved',
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin1',
        approvalDate: now.subtract(const Duration(days: 5)),
        adminComment: 'All good',
        breaks: [
          AttendanceBreak(
            breakType: 'lunch',
            startTime: now.subtract(const Duration(days: 6, hours: 13)),
            endTime: now.subtract(const Duration(days: 6, hours: 14)),
            durationMinutes: 60,
          ),
        ],
        totalBreakTimeMinutes: 60,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    ]);
  }

  @override
  Future<FetchResult<List<AttendanceRecord>>> fetchPending({bool forceRefresh = false}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    return FetchResult(data: List.from(_pendingRecords), isStale: false);
  }

  @override
  Future<FetchResult<List<AttendanceRecord>>> fetchApproved({bool forceRefresh = false}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    return FetchResult(data: List.from(_approvedRecords), isStale: false);
  }

  @override
  Future<void> approve(String attendanceId, {String? comment}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Find and move record from pending to approved
    final index = _pendingRecords.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      final record = _pendingRecords[index];
      final approvedRecord = AttendanceRecord(
        id: record.id,
        userId: record.userId,
        companyId: record.companyId,
        date: record.date,
        checkInTime: record.checkInTime,
        checkOutTime: record.checkOutTime,
        status: 'approved',
        breaks: record.breaks,
        totalBreakTimeMinutes: record.totalBreakTimeMinutes,
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin1',
        approvalDate: DateTime.now(),
        adminComment: comment,
        notes: record.notes,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
      );
      _pendingRecords.removeAt(index);
      _approvedRecords.insert(0, approvedRecord);
    }
  }

  @override
  Future<void> reject(String attendanceId, {required String reason}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Find and remove record from pending (rejected records don't stay in pending)
    final index = _pendingRecords.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      _pendingRecords.removeAt(index);
    }
  }

  @override
  Future<void> bulkAutoApprove() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Approve all completed pending records
    final eligible = _pendingRecords.where((r) => r.isCompleted && r.approvalStatus == ApprovalStatus.pending).toList();
    
    for (final record in eligible) {
      final index = _pendingRecords.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        final approvedRecord = AttendanceRecord(
          id: record.id,
          userId: record.userId,
          companyId: record.companyId,
          date: record.date,
          checkInTime: record.checkInTime,
          checkOutTime: record.checkOutTime,
          status: 'approved',
          breaks: record.breaks,
          totalBreakTimeMinutes: record.totalBreakTimeMinutes,
          approvalStatus: ApprovalStatus.approved,
          approvedBy: 'admin1',
          approvalDate: DateTime.now(),
          adminComment: 'Auto-approved',
          notes: record.notes,
          createdAt: record.createdAt,
          updatedAt: DateTime.now(),
        );
        _pendingRecords.removeAt(index);
        _approvedRecords.insert(0, approvedRecord);
      }
    }
  }
}

/// Repository for admin timesheet approvals with cache-first strategy
/// Matches legacy endpoints and caching rules (TTL: 1 minute)
class AdminApprovalsRepository implements AdminApprovalsRepositoryInterface {
  AdminApprovalsRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  /// Cache TTL for admin approvals lists (1 minute per legacy rules)
  static const Duration _cacheTtl = Duration(minutes: 1);

  /// Fetch pending timesheets (admin only)
  /// GET /attendance/pending
  /// Cache-first with 1 minute TTL, fallback to stale cache if offline
  Future<FetchResult<List<AttendanceRecord>>> fetchPending({bool forceRefresh = false}) async {
    print('[AdminApprovalsRepository] ===== fetchPending CALLED =====');
    print('[AdminApprovalsRepository] forceRefresh: $forceRefresh');
    const cacheKey = 'admin_pending_timesheets';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        return FetchResult(data: cached, isStale: false);
      }
    }

    // Try network request
    print('[AdminApprovalsRepository] ⚠⚠⚠ MAKING API CALL to /attendance/pending ⚠⚠⚠');
    try {
      final response = await _apiClient.get('/attendance/pending');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final attendanceList = data['data'] as List<dynamic>? ?? [];

          final records = attendanceList
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();

          // Update cache
          _cache.set<List<AttendanceRecord>>(
            cacheKey,
            records,
            ttl: _cacheTtl,
            toJson: (records) => {
              'data': records.map((r) => r.toJson()).toList(),
            },
          );

          return FetchResult(data: records, isStale: false);
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Try stale cache on network error (always prefer stale cache over throwing error)
      final staleCache = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If we have stale cache, always return it (better UX than showing error)
      if (staleCache != null) {
        return FetchResult(data: staleCache, isStale: true);
      }

      // No stale cache available - return empty list instead of throwing
      // This allows the UI to show empty state gracefully
      return FetchResult(data: <AttendanceRecord>[], isStale: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsRepository] Unexpected error: $e');
      }
      
      final staleCache = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[AdminApprovalsRepository] Returning ${staleCache.length} stale records from catch block for $cacheKey');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      // Last resort: return empty list instead of throwing
      if (kDebugMode) {
        debugPrint('[AdminApprovalsRepository] No cache available, returning empty list for $cacheKey');
      }
      return FetchResult(data: <AttendanceRecord>[], isStale: false);
    }
  }

  /// Fetch approved timesheets (admin only)
  /// GET /attendance/approved
  /// Cache-first with 1 minute TTL, fallback to stale cache if offline
  Future<FetchResult<List<AttendanceRecord>>> fetchApproved({bool forceRefresh = false}) async {
    print('[AdminApprovalsRepository] ===== fetchApproved CALLED =====');
    print('[AdminApprovalsRepository] forceRefresh: $forceRefresh');
    const cacheKey = 'admin_approved_timesheets';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        return FetchResult(data: cached, isStale: false);
      }
    }

    // Try network request
    print('[AdminApprovalsRepository] ⚠⚠⚠ MAKING API CALL to /attendance/approved ⚠⚠⚠');
    try {
      final response = await _apiClient.get('/attendance/approved');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final attendanceList = data['data'] as List<dynamic>? ?? [];

          final records = attendanceList
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();

          // Update cache
          _cache.set<List<AttendanceRecord>>(
            cacheKey,
            records,
            ttl: _cacheTtl,
            toJson: (records) => {
              'data': records.map((r) => r.toJson()).toList(),
            },
          );

          return FetchResult(data: records, isStale: false);
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Try stale cache on network error (always prefer stale cache over throwing error)
      final staleCache = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If we have stale cache, always return it (better UX than showing error)
      if (staleCache != null) {
        return FetchResult(data: staleCache, isStale: true);
      }

      // No stale cache available - return empty list instead of throwing
      // This allows the UI to show empty state gracefully
      return FetchResult(data: <AttendanceRecord>[], isStale: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsRepository] Unexpected error: $e');
      }
      
      final staleCache = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[AdminApprovalsRepository] Returning ${staleCache.length} stale records from catch block for $cacheKey');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      // Last resort: return empty list instead of throwing
      if (kDebugMode) {
        debugPrint('[AdminApprovalsRepository] No cache available, returning empty list for $cacheKey');
      }
      return FetchResult(data: <AttendanceRecord>[], isStale: false);
    }
  }

  /// Approve a timesheet (admin only)
  /// POST /attendance/{id}/approve
  Future<void> approve(String attendanceId, {String? comment}) async {
    try {
      await _apiClient.post(
        '/attendance/$attendanceId/approve',
        data: {
          if (comment != null && comment.isNotEmpty) 'adminComment': comment,
        },
      );

      // Clear cache after approval
      _cache.remove('admin_pending_timesheets');
      _cache.remove('admin_approved_timesheets');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to approve timesheet: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Reject a timesheet (admin only)
  /// POST /attendance/{id}/reject
  Future<void> reject(String attendanceId, {required String reason}) async {
    try {
      await _apiClient.post(
        '/attendance/$attendanceId/reject',
        data: {
          'adminComment': reason,
        },
      );

      // Clear cache after rejection
      _cache.remove('admin_pending_timesheets');
      _cache.remove('admin_approved_timesheets');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to reject timesheet: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Bulk auto-approve timesheets (admin only)
  /// POST /attendance/bulk-auto-approve
  /// Only approves eligible items (completed/checked out only)
  Future<void> bulkAutoApprove() async {
    try {
      await _apiClient.post(
        '/attendance/bulk-auto-approve',
      );

      // Clear cache after bulk approval
      _cache.remove('admin_pending_timesheets');
      _cache.remove('admin_approved_timesheets');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to bulk approve timesheets: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Check if error indicates offline state
  /// Note: This method is kept for reference but not used in current implementation
  /// We now always return stale cache if available, regardless of error type
  @Deprecated('Not used - always return stale cache if available')
  bool _isOfflineError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.error is SocketException) ||
        (error.message?.contains('Failed host lookup') ?? false) ||
        (error.message?.contains('Network is unreachable') ?? false);
  }
}



