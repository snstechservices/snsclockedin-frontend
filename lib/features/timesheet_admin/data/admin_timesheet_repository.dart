import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

/// Repository for admin timesheet operations
/// Matches legacy endpoints from TIMESHEET_LEGACY_AUDIT_REPORT.md
class AdminTimesheetRepository {
  AdminTimesheetRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  /// Cache TTL for admin timesheet lists (1 minute per legacy rules)
  static const Duration _cacheTtl = Duration(minutes: 1);

  /// Fetch pending timesheets (admin only)
  /// GET /attendance/pending
  Future<List<AttendanceRecord>> fetchPending({bool forceRefresh = false}) async {
    print('[AdminTimesheetRepository] ===== fetchPending CALLED =====');
    print('[AdminTimesheetRepository] forceRefresh: $forceRefresh');
    const cacheKey = 'pending_timesheets';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      // Try stale cache first (doesn't remove expired entries)
      var cached = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        print('[AdminTimesheetRepository] Using stale cache: ${cached.length} records');
        return cached;
      }
      
      // Try fresh cache
      cached = _cache.get<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        print('[AdminTimesheetRepository] Using fresh cache: ${cached.length} records');
        return cached;
      }
      
      // No readable cache - skip API call (offline protection)
      print('[AdminTimesheetRepository] ✗✗✗ NO CACHE - SKIPPING API CALL (OFFLINE PROTECTION) ✗✗✗');
      return [];
    }

    // Try network request (only if forceRefresh is true)
    print('[AdminTimesheetRepository] ⚠⚠⚠ MAKING API CALL to /attendance/pending ⚠⚠⚠');
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

          return records;
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
        return staleCache;
      }

      // No stale cache available - return empty list instead of throwing
      // This allows the UI to show empty state gracefully
      return [];
    } catch (e) {
      // Try stale cache on any other error
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
        return staleCache;
      }

      // Last resort: return empty list instead of throwing
      return [];
    }
  }

  /// Fetch approved timesheets (admin only)
  /// GET /attendance/approved
  Future<List<AttendanceRecord>> fetchApproved({bool forceRefresh = false}) async {
    print('[AdminTimesheetRepository] ===== fetchApproved CALLED =====');
    print('[AdminTimesheetRepository] forceRefresh: $forceRefresh');
    const cacheKey = 'approved_timesheets';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      // Try stale cache first (doesn't remove expired entries)
      var cached = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        print('[AdminTimesheetRepository] Using stale cache: ${cached.length} records');
        return cached;
      }
      
      // Try fresh cache
      cached = _cache.get<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        print('[AdminTimesheetRepository] Using fresh cache: ${cached.length} records');
        return cached;
      }
      
      // No readable cache - skip API call (offline protection)
      print('[AdminTimesheetRepository] ✗✗✗ NO CACHE - SKIPPING API CALL (OFFLINE PROTECTION) ✗✗✗');
      return [];
    }

    // Try network request (only if forceRefresh is true)
    print('[AdminTimesheetRepository] ⚠⚠⚠ MAKING API CALL to /attendance/approved ⚠⚠⚠');
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

          return records;
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
        return staleCache;
      }

      // No stale cache available - return empty list instead of throwing
      // This allows the UI to show empty state gracefully
      return [];
    } catch (e) {
      // Try stale cache on any other error
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
        return staleCache;
      }

      // Last resort: return empty list instead of throwing
      return [];
    }
  }

  /// Approve a timesheet (admin only)
  /// PUT /attendance/{id}/approve
  Future<void> approveTimesheet(
    String attendanceId, {
    String? adminComment,
  }) async {
    try {
      await _apiClient.put(
        '/attendance/$attendanceId/approve',
        data: {
          if (adminComment != null && adminComment.isNotEmpty) 'adminComment': adminComment,
        },
      );

      // Clear cache after approval
      _cache.remove('pending_timesheets');
      _cache.remove('approved_timesheets');
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
  /// PUT /attendance/{id}/reject
  Future<void> rejectTimesheet(
    String attendanceId, {
    required String reason,
  }) async {
    try {
      await _apiClient.put(
        '/attendance/$attendanceId/reject',
        data: {
          'adminComment': reason,
        },
      );

      // Clear cache after rejection
      _cache.remove('pending_timesheets');
      _cache.remove('approved_timesheets');
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
  Future<Map<String, dynamic>> bulkAutoApprove({
    List<String>? recordIds,
  }) async {
    try {
      final response = await _apiClient.post(
        '/attendance/bulk-auto-approve',
        data: {
          if (recordIds != null && recordIds.isNotEmpty) 'recordIds': recordIds,
        },
      );

      // Clear cache after bulk approval
      _cache.remove('pending_timesheets');
      _cache.remove('approved_timesheets');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>? ?? {};
        }
      }

      throw ApiException(message: 'Invalid response format');
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
  bool _isOfflineError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.error is SocketException);
  }
}

