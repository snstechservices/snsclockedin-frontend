import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart'
    show AttendanceRecord, AttendanceSummary;

/// Result class for fetch operations that includes stale cache flag
class FetchResult<T> {
  const FetchResult({
    required this.data,
    required this.isStale,
  });

  final T data;
  final bool isStale;
}

/// Repository for timesheet data with cache-first strategy
/// Matches legacy caching rules from TIMESHEET_LEGACY_AUDIT_REPORT.md
class TimesheetRepository {
  TimesheetRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  /// Cache TTL for attendance history (1 minute per legacy rules)
  static const Duration _cacheTtl = Duration(minutes: 1);

  /// Cache TTL for attendance summary (5 minutes per legacy rules)
  static const Duration _summaryCacheTtl = Duration(minutes: 5);

  /// Fetch user's own timesheet with date range
  /// Matches legacy behavior:
  /// - Cache-first with 1 minute TTL
  /// - Fallback to cached data on network error
  /// - Return cached even if expired when offline
  Future<FetchResult<List<AttendanceRecord>>> fetchMyTimesheet({
    required String companyId,
    required String userId,
    required DateTime start,
    required DateTime end,
    bool forceRefresh = false,
  }) async {
    // Generate cache key
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();
    final cacheKey = 'attendance_history_${companyId}_${userId}_${startIso}_${endIso}';

    // Step 1: Check cache if not forcing refresh
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

    // Step 2: Try network request
    try {
      final response = await _apiClient.get(
        '/attendance/timesheet',
        queryParameters: {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      );

      // Parse response
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final attendanceData = data['data'] as Map<String, dynamic>;
          final attendanceList = attendanceData['attendance'] as List<dynamic>? ?? [];

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
      // Network error - check if we have stale cache
      final staleCache = _cache.getStale<List<AttendanceRecord>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If offline or network error, return stale cache if available
      if (_isOfflineError(e) && staleCache != null) {
        return FetchResult(data: staleCache, isStale: true);
      }

      // If no stale cache, return empty list (matches legacy behavior)
      if (staleCache == null) {
        return FetchResult(data: <AttendanceRecord>[], isStale: false);
      }

      // Re-throw if it's not an offline scenario
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to fetch timesheet: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Other errors - try stale cache
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
        return FetchResult(data: staleCache, isStale: true);
      }

      // Re-throw if no cache available
      throw ApiException(message: 'Failed to fetch timesheet: $e');
    }
  }

  /// Fetch attendance summary for user
  /// GET /attendance/summary/{userId}
  /// Cache TTL: 5 minutes per legacy rules
  Future<AttendanceSummary> fetchSummary({
    required String companyId,
    required String userId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'attendance_summary_${companyId}_${userId}';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<AttendanceSummary>(
        cacheKey,
        fromJson: (json) => AttendanceSummary.fromJson(json),
      );
      if (cached != null) {
        return cached;
      }
    }

    // Try network request
    try {
      final response = await _apiClient.get('/attendance/summary/$userId');

      // Parse response
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final summaryData = data['data'] as Map<String, dynamic>;
          final summary = AttendanceSummary.fromJson(summaryData);

          // Update cache
          _cache.set<AttendanceSummary>(
            cacheKey,
            summary,
            ttl: _summaryCacheTtl,
            toJson: (summary) => summary.toJson(),
          );

          return summary;
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Network error - check if we have stale cache
      final staleCache = _cache.getStale<AttendanceSummary>(
        cacheKey,
        fromJson: (json) => AttendanceSummary.fromJson(json),
      );

      // If offline or network error, return stale cache if available
      if (_isOfflineError(e) && staleCache != null) {
        return staleCache;
      }

      // If no stale cache, return empty summary (matches legacy behavior)
      if (staleCache == null) {
        return const AttendanceSummary(
          totalRecords: 0,
          approved: 0,
          completed: 0,
          clockedIn: 0,
          pending: 0,
          rejected: 0,
        );
      }

      // Re-throw if it's not an offline scenario
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to fetch summary: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Other errors - try stale cache
      final staleCache = _cache.getStale<AttendanceSummary>(
        cacheKey,
        fromJson: (json) => AttendanceSummary.fromJson(json),
      );

      if (staleCache != null) {
        return staleCache;
      }

      // Return empty summary if no cache available
      return const AttendanceSummary(
        totalRecords: 0,
        approved: 0,
        completed: 0,
        clockedIn: 0,
        pending: 0,
        rejected: 0,
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

