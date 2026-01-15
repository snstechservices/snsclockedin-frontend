import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_balance.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';

/// Store for employee leave requests using repository pattern
/// Prevents auto API calls when demo/seeded data exists
class LeaveStore extends ChangeNotifier {
  LeaveStore({
    required LeaveRepositoryInterface repository,
    SimpleCache? cache,
  })  : _repository = repository,
        _cache = cache ?? SimpleCache();

  final LeaveRepositoryInterface _repository;
  final SimpleCache _cache;

  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = false;
  String? _error;
  bool _usingStale = false;
  bool _hasEverLoaded = false;

  List<LeaveRequest> get leaveRequests => List.unmodifiable(_leaveRequests);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get usingStale => _usingStale;

  /// Get leave balance (demo/mock data for now)
  LeaveBalance get leaveBalance => LeaveBalance.demo();

  List<LeaveRequest> getLeaveRequestsByUserId(String userId) {
    return _leaveRequests.where((r) => r.userId == userId).toList();
  }

  List<LeaveRequest> getLeaveRequestsByStatus(LeaveStatus? status) {
    if (status == null) {
      return _leaveRequests;
    }
    return _leaveRequests.where((request) => request.status == status).toList();
  }

  /// Load leave requests for a user
  /// Multi-layer guards prevent API calls when demo/seeded data exists
  Future<void> loadLeaves(String userId, {bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint('[LeaveStore] loadLeaves(userId: $userId, forceRefresh: $forceRefresh)');
    }

    // If not forcing refresh, check cache and store first
    if (!forceRefresh) {
      // If we already have records in store, use them
      if (_leaveRequests.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[LeaveStore] SKIP API: Store has ${_leaveRequests.length} leave requests');
        }
        _error = null;
        _isLoading = false;
        _usingStale = false;
        notifyListeners();
        return;
      }

      // No store records, try cache
      try {
        final cacheKey = 'user_leaves_$userId';
        var cached = _cache.get<List<LeaveRequest>>(
          cacheKey,
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );

        // If no fresh cache, try stale cache
        if (cached == null) {
          cached = _cache.getStale<List<LeaveRequest>>(
            cacheKey,
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
          if (cached != null) {
            _usingStale = true;
          }
        }

        if (cached != null) {
          if (kDebugMode) {
            debugPrint('[LeaveStore] SKIP API: Found ${cached.length} records in cache');
          }
          _leaveRequests = cached;
          _error = null;
          _isLoading = false;
          _hasEverLoaded = true;
          notifyListeners();
          return;
        }
      } catch (e) {
        // Cache read failed, will try repository below
      }

      // If cache exists (from seeding) and not forcing refresh, don't call API
      final cacheKey = 'user_leaves_$userId';
      if (_cache.exists(cacheKey)) {
        if (kDebugMode) {
          debugPrint('[LeaveStore] SKIP API: Cache exists (from seeding), reading from cache');
        }
        try {
          final cached = _cache.getStale<List<LeaveRequest>>(
            cacheKey,
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
          if (cached != null) {
            _leaveRequests = cached;
            _usingStale = cached.isEmpty ? false : true;
          } else {
            _leaveRequests = [];
            _usingStale = true;
          }
        } catch (e) {
          _leaveRequests = [];
          _usingStale = true;
        }
        _error = null;
        _isLoading = false;
        _hasEverLoaded = true;
        notifyListeners();
        return;
      }

      // Final guard: If we have demo data and not forcing refresh, don't call API
      if (_leaveRequests.any((r) => r.id.startsWith('demo-'))) {
        if (kDebugMode) {
          debugPrint('[LeaveStore] SKIP API: Demo data detected in store');
        }
        _error = null;
        _isLoading = false;
        _usingStale = false;
        _hasEverLoaded = true;
        notifyListeners();
        return;
      }

      // Final check: If not forcing refresh and we have no data and no cache, just return empty
      if (!_cache.exists(cacheKey) && _leaveRequests.isEmpty) {
        if (kDebugMode) {
          debugPrint('[LeaveStore] SKIP API: No cache + no data + not forcing refresh, returning empty');
        }
        _leaveRequests = [];
        _error = null;
        _isLoading = false;
        _usingStale = false;
        notifyListeners();
        return;
      }
    }

    // All guards passed - making API call
    if (kDebugMode) {
      debugPrint('[LeaveStore] CALLING API: /leave/requests (forceRefresh: $forceRefresh)');
    }
    _isLoading = true;
    _error = null;
    _usingStale = false;
    notifyListeners();

    try {
      final result = await _repository.fetchUserLeaves(userId, forceRefresh: forceRefresh);
      _hasEverLoaded = true;
      if (result.data.isNotEmpty) {
        _leaveRequests = result.data;
        _usingStale = result.isStale;
        _error = null;
      } else if (forceRefresh) {
        // Force refresh returned empty - preserve existing records if we have them
        if (_leaveRequests.isEmpty) {
          _leaveRequests = [];
        }
        _usingStale = result.isStale;
        _error = null;
      } else {
        _usingStale = result.isStale;
        _error = null;
      }
    } catch (e) {
      // Network error - preserve existing records
      if (_leaveRequests.isEmpty) {
        _error = e.toString();
      } else {
        _error = null;
        _usingStale = true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLeave(LeaveRequest request) async {
    _isLoading = true;
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (request.id.startsWith('demo-')) {
      _leaveRequests.insert(0, request);
      // Update cache
      final cacheKey = 'user_leaves_${request.userId}';
      _cache.set<List<LeaveRequest>>(
        cacheKey,
        _leaveRequests,
        ttl: const Duration(hours: 24),
        toJson: (leaves) => {
          'data': leaves.map((l) => l.toJson()).toList(),
        },
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await _repository.submitLeaveRequest(request);
      // Refresh list
      await loadLeaves(request.userId, forceRefresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveLeave(String id) async {
    await _updateStatus(id, LeaveStatus.approved);
  }

  Future<void> rejectLeave(String id, {String? reason}) async {
    await _updateStatus(id, LeaveStatus.rejected, reason: reason);
  }

  Future<void> _updateStatus(String id, LeaveStatus status, {String? reason}) async {
    // Handle demo data in-memory
    final index = _leaveRequests.indexWhere((r) => r.id == id);
    if (index != -1 && _leaveRequests[index].id.startsWith('demo-')) {
      final old = _leaveRequests[index];
      _leaveRequests[index] = LeaveRequest(
        id: old.id,
        userId: old.userId,
        userName: old.userName,
        leaveType: old.leaveType,
        startDate: old.startDate,
        endDate: old.endDate,
        isHalfDay: old.isHalfDay,
        halfDayPart: old.halfDayPart,
        reason: old.reason,
        status: status,
        createdAt: old.createdAt,
      );
      // Update cache
      final cacheKey = 'user_leaves_${old.userId}';
      _cache.set<List<LeaveRequest>>(
        cacheKey,
        _leaveRequests,
        ttl: const Duration(hours: 24),
        toJson: (leaves) => {
          'data': leaves.map((l) => l.toJson()).toList(),
        },
      );
      notifyListeners();
      return;
    }

    try {
      if (status == LeaveStatus.approved) {
        await _repository.approveLeave(id);
      } else {
        await _repository.rejectLeave(id, reason: reason ?? 'No reason provided');
      }
      // Refresh list
      final userId = _leaveRequests.firstWhere((r) => r.id == id, orElse: () => _leaveRequests.first).userId;
      await loadLeaves(userId, forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Seed demo data for testing
  void seedDemo() {
    final now = DateTime.now();
    _leaveRequests = [
      LeaveRequest(
        id: 'demo-leave-1',
        userId: 'current_user',
        userName: 'Demo User',
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
        userId: 'current_user',
        userName: 'Demo User',
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
        userId: 'current_user',
        userName: 'Demo User',
        leaveType: LeaveType.unpaid,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 10)),
        isHalfDay: false,
        reason: 'Personal emergency',
        status: LeaveStatus.rejected,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
    ];

    // Write to cache so data persists through navigation
    final cacheKey = 'user_leaves_current_user';
    _cache.set<List<LeaveRequest>>(
      cacheKey,
      _leaveRequests,
      ttl: const Duration(hours: 24),
      toJson: (leaves) => {
        'data': leaves.map((l) => l.toJson()).toList(),
      },
    );

    _error = null;
    _usingStale = false;
    _hasEverLoaded = true;
    notifyListeners();
  }

  /// Clear demo data (reset to empty)
  void clearDemo() {
    _leaveRequests = [];
    _error = null;
    _usingStale = false;
    _hasEverLoaded = false;
    notifyListeners();
  }

  // Deprecated compatibility method
  @Deprecated('Use loadLeaves instead')
  void seedSampleData() {
    seedDemo();
  }

  /// Debug-only seed that reuses seedDemo
  void seedDebugData() {
    if (!kDebugMode) return;
    if (_leaveRequests.isNotEmpty) return;
    seedDemo();
  }
}
