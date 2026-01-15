import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';

/// Result class for fetch operations that includes stale cache flag
class FetchResult<T> {
  const FetchResult({
    required this.data,
    required this.isStale,
  });

  final T data;
  final bool isStale;
}

/// Abstract repository interface for leave requests
abstract class LeaveRepositoryInterface {
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(String userId, {bool forceRefresh = false});
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({bool forceRefresh = false});
  Future<void> submitLeaveRequest(LeaveRequest request);
  Future<void> approveLeave(String leaveId, {String? comment});
  Future<void> rejectLeave(String leaveId, {required String reason});
}

/// Mock repository for leave requests (for development/testing)
/// Returns mock data without making API calls
class MockLeaveRepository implements LeaveRepositoryInterface {
  final List<LeaveRequest> _leaves = [];
  final _uuid = const Uuid();

  MockLeaveRepository() {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    _leaves.addAll([
      LeaveRequest(
        id: 'demo-leave-1',
        userId: 'user1',
        userName: 'John Doe',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 7)),
        isHalfDay: false,
        reason: 'Family vacation',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LeaveRequest(
        id: 'demo-leave-2',
        userId: 'user1',
        userName: 'John Doe',
        leaveType: LeaveType.sick,
        startDate: now.subtract(const Duration(days: 3)),
        endDate: now.subtract(const Duration(days: 3)),
        isHalfDay: true,
        halfDayPart: HalfDayPart.am,
        reason: 'Medical appointment',
        status: LeaveStatus.approved,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LeaveRequest(
        id: 'demo-leave-3',
        userId: 'user2',
        userName: 'Jane Smith',
        leaveType: LeaveType.unpaid,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 10)),
        isHalfDay: false,
        reason: 'Personal emergency',
        status: LeaveStatus.rejected,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      LeaveRequest(
        id: 'demo-leave-4',
        userId: 'user3',
        userName: 'Bob Johnson',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 12)),
        isHalfDay: false,
        reason: 'Holiday trip',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(String userId, {bool forceRefresh = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final userLeaves = _leaves.where((l) => l.userId == userId).toList();
    return FetchResult(data: List.from(userLeaves), isStale: false);
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({bool forceRefresh = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final pending = _leaves.where((l) => l.status == LeaveStatus.pending).toList();
    return FetchResult(data: List.from(pending), isStale: false);
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final newRequest = LeaveRequest(
      id: request.id.isEmpty ? _uuid.v4() : request.id,
      userId: request.userId,
      userName: request.userName,
      leaveType: request.leaveType,
      startDate: request.startDate,
      endDate: request.endDate,
      isHalfDay: request.isHalfDay,
      halfDayPart: request.halfDayPart,
      reason: request.reason,
      status: request.status,
      createdAt: request.createdAt,
    );
    _leaves.insert(0, newRequest);
  }

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _leaves.indexWhere((l) => l.id == leaveId);
    if (index != -1) {
      final old = _leaves[index];
      _leaves[index] = LeaveRequest(
        id: old.id,
        userId: old.userId,
        userName: old.userName,
        leaveType: old.leaveType,
        startDate: old.startDate,
        endDate: old.endDate,
        isHalfDay: old.isHalfDay,
        halfDayPart: old.halfDayPart,
        reason: old.reason,
        status: LeaveStatus.approved,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _leaves.indexWhere((l) => l.id == leaveId);
    if (index != -1) {
      final old = _leaves[index];
      _leaves[index] = LeaveRequest(
        id: old.id,
        userId: old.userId,
        userName: old.userName,
        leaveType: old.leaveType,
        startDate: old.startDate,
        endDate: old.endDate,
        isHalfDay: old.isHalfDay,
        halfDayPart: old.halfDayPart,
        reason: old.reason,
        status: LeaveStatus.rejected,
        createdAt: old.createdAt,
      );
    }
  }
}

/// Repository for leave requests with cache-first strategy
/// Cache TTL: 1 minute (matches legacy patterns)
class LeaveRepository implements LeaveRepositoryInterface {
  LeaveRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  /// Cache TTL for leave requests (1 minute per legacy rules)
  static const Duration _cacheTtl = Duration(minutes: 1);

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchUserLeaves(String userId, {bool forceRefresh = false}) async {
    final cacheKey = 'user_leaves_$userId';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${cached.length} cached user leaves for $userId');
        }
        return FetchResult(data: cached, isStale: false);
      }
    }

    // Try network request
    try {
      final response = await _apiClient.get('/leave/requests', queryParameters: {'userId': userId});

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final leaveList = data['data'] as List<dynamic>? ?? [];

          final leaves = leaveList
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();

          // Update cache
          _cache.set<List<LeaveRequest>>(
            cacheKey,
            leaves,
            ttl: _cacheTtl,
            toJson: (leaves) => {
              'data': leaves.map((l) => l.toJson()).toList(),
            },
          );

          return FetchResult(data: leaves, isStale: false);
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[LeaveRepository] Network error: ${e.message}');
      }

      // Try stale cache on network error
      final staleCache = _cache.getStale<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If we have stale cache, always return it
      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${staleCache.length} stale user leaves for $userId');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      // No stale cache available - return empty list
      if (kDebugMode) {
        debugPrint('[LeaveRepository] No cache available, returning empty list for $userId');
      }
      return FetchResult(data: <LeaveRequest>[], isStale: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LeaveRepository] Unexpected error: $e');
      }

      final staleCache = _cache.getStale<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${staleCache.length} stale leaves from catch block for $userId');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      return FetchResult(data: <LeaveRequest>[], isStale: false);
    }
  }

  @override
  Future<FetchResult<List<LeaveRequest>>> fetchPendingLeaves({bool forceRefresh = false}) async {
    const cacheKey = 'admin_pending_leaves';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${cached.length} cached pending leaves');
        }
        return FetchResult(data: cached, isStale: false);
      }
    }

    // Try network request
    try {
      final response = await _apiClient.get('/leave/pending');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final leaveList = data['data'] as List<dynamic>? ?? [];

          final leaves = leaveList
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();

          // Update cache
          _cache.set<List<LeaveRequest>>(
            cacheKey,
            leaves,
            ttl: _cacheTtl,
            toJson: (leaves) => {
              'data': leaves.map((l) => l.toJson()).toList(),
            },
          );

          return FetchResult(data: leaves, isStale: false);
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[LeaveRepository] Network error: ${e.message}');
      }

      // Try stale cache on network error
      final staleCache = _cache.getStale<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If we have stale cache, always return it
      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${staleCache.length} stale pending leaves');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      // No stale cache available - return empty list
      if (kDebugMode) {
        debugPrint('[LeaveRepository] No cache available, returning empty list for pending');
      }
      return FetchResult(data: <LeaveRequest>[], isStale: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LeaveRepository] Unexpected error: $e');
      }

      final staleCache = _cache.getStale<List<LeaveRequest>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      if (staleCache != null) {
        if (kDebugMode) {
          debugPrint('[LeaveRepository] Returning ${staleCache.length} stale leaves from catch block');
        }
        return FetchResult(data: staleCache, isStale: true);
      }

      return FetchResult(data: <LeaveRequest>[], isStale: false);
    }
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    try {
      await _apiClient.post(
        '/leave/requests',
        data: request.toJson(),
      );

      // Clear user's cache after submission
      _cache.remove('user_leaves_${request.userId}');
      _cache.remove('admin_pending_leaves');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to submit leave request: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> approveLeave(String leaveId, {String? comment}) async {
    try {
      await _apiClient.post(
        '/leave/$leaveId/approve',
        data: {
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );

      // Clear caches after approval
      _cache.clear(); // Clear all leave caches
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to approve leave: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> rejectLeave(String leaveId, {required String reason}) async {
    try {
      await _apiClient.post(
        '/leave/$leaveId/reject',
        data: {
          'reason': reason,
        },
      );

      // Clear caches after rejection
      _cache.clear(); // Clear all leave caches
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to reject leave: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

