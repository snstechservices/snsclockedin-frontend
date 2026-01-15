import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/leave/data/leave_repository.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_request.dart';

/// Admin leave approvals store for managing pending leave requests
/// Uses optimistic updates for better UX
class AdminLeaveApprovalsStore extends ChangeNotifier {
  AdminLeaveApprovalsStore({
    required LeaveRepositoryInterface repository,
    SimpleCache? cache,
  })  : _repository = repository,
        _cache = cache ?? SimpleCache();

  final LeaveRepositoryInterface _repository;
  final SimpleCache _cache;

  // State
  List<LeaveRequest> _allLeaves = []; // Contains all leaves (pending, approved, rejected)
  bool _isLoading = false;
  String? _error;
  bool _usingStale = false;
  int _selectedTab = 0; // 0 = pending, 1 = approved, 2 = rejected
  final Set<String> _loadingLeaveIds = {}; // Track which leaves are being processed
  bool _hasEverLoaded = false;
  LeaveStatus? _selectedFilter; // Persist filter selection

  // Getters
  List<LeaveRequest> get pendingLeaves => List.unmodifiable(_allLeaves); // Returns all leaves (UI filters by status)
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get usingStale => _usingStale;
  int get selectedTab => _selectedTab;
  LeaveStatus? get selectedFilter => _selectedFilter;
  bool isLeaveLoading(String leaveId) => _loadingLeaveIds.contains(leaveId);
  
  /// Get pending count for badge
  int get pendingCount => _allLeaves.where((l) => l.status == LeaveStatus.pending).length;

  /// Get approved count for stat card
  int get approvedCount => _allLeaves.where((l) => l.status == LeaveStatus.approved).length;

  /// Get rejected count for stat card
  int get rejectedCount => _allLeaves.where((l) => l.status == LeaveStatus.rejected).length;

  /// Set selected tab
  void setSelectedTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      notifyListeners();
    }
  }

  /// Set selected filter (persists across rebuilds)
  void setSelectedFilter(LeaveStatus? status) {
    if (_selectedFilter != status) {
      _selectedFilter = status;
      notifyListeners();
    }
  }

  /// Get leaves by status
  List<LeaveRequest> getLeavesByStatus(LeaveStatus status) {
    return _allLeaves.where((l) => l.status == status).toList();
  }

  /// Load pending leave requests
  /// Multi-layer guards prevent API calls when demo/seeded data exists
  Future<void> loadPending({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint('[AdminLeaveApprovalsStore] loadPending(forceRefresh: $forceRefresh)');
    }

    // If not forcing refresh, check cache and store first
    if (!forceRefresh) {
      // If we already have records in store, use them
      if (_allLeaves.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[AdminLeaveApprovalsStore] SKIP API: Store has ${_allLeaves.length} leaves');
        }
        _error = null;
        _isLoading = false;
        _usingStale = false;
        notifyListeners();
        return;
      }

      // No store records, try cache
      try {
        const cacheKey = 'admin_pending_leaves';
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
            debugPrint('[AdminLeaveApprovalsStore] SKIP API: Found ${cached.length} records in cache');
          }
          _allLeaves = cached;
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
      const cacheKey = 'admin_pending_leaves';
      if (_cache.exists(cacheKey)) {
        if (kDebugMode) {
          debugPrint('[AdminLeaveApprovalsStore] SKIP API: Cache exists (from seeding), reading from cache');
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
            _allLeaves = cached;
            _usingStale = cached.isEmpty ? false : true;
          } else {
            _allLeaves = [];
            _usingStale = true;
          }
        } catch (e) {
          _allLeaves = [];
          _usingStale = true;
        }
        _error = null;
        _isLoading = false;
        _hasEverLoaded = true;
        notifyListeners();
        return;
      }

      // Final guard: If we have demo data and not forcing refresh, don't call API
      if (_allLeaves.any((r) => r.id.startsWith('demo-'))) {
        if (kDebugMode) {
          debugPrint('[AdminLeaveApprovalsStore] SKIP API: Demo data detected in store');
        }
        _error = null;
        _isLoading = false;
        _usingStale = false;
        _hasEverLoaded = true;
        notifyListeners();
        return;
      }

      // Final check: If not forcing refresh and we have no data and no cache, just return empty
      if (!_cache.exists(cacheKey) && _allLeaves.isEmpty) {
        if (kDebugMode) {
          debugPrint('[AdminLeaveApprovalsStore] SKIP API: No cache + no data + not forcing refresh, returning empty');
        }
        _allLeaves = [];
        _error = null;
        _isLoading = false;
        _usingStale = false;
        notifyListeners();
        return;
      }
    }

    // All guards passed - making API call
    if (kDebugMode) {
      debugPrint('[AdminLeaveApprovalsStore] CALLING API: /leave/pending (forceRefresh: $forceRefresh)');
    }
    _isLoading = true;
    _error = null;
    _usingStale = false;
    notifyListeners();

    try {
      final result = await _repository.fetchPendingLeaves(forceRefresh: forceRefresh);
      _hasEverLoaded = true;
      if (result.data.isNotEmpty) {
        // Merge with existing leaves, updating status if leave already exists
        for (final leave in result.data) {
          final index = _allLeaves.indexWhere((l) => l.id == leave.id);
          if (index >= 0) {
            // Update existing leave
            _allLeaves[index] = leave;
          } else {
            // Add new leave
            _allLeaves.add(leave);
          }
        }
        _allLeaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _usingStale = result.isStale;
        _error = null;
      } else if (forceRefresh) {
        // Force refresh returned empty - preserve existing records if we have them
        // Don't clear, just mark as stale if needed
        _usingStale = result.isStale;
        _error = null;
      } else {
        _usingStale = result.isStale;
        _error = null;
      }
    } catch (e) {
      // Network error - preserve existing records
      if (_allLeaves.isEmpty) {
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

  /// Approve a leave request (optimistic update)
  Future<void> approveOne(BuildContext context, LeaveRequest leave, {String? comment}) async {
    _loadingLeaveIds.add(leave.id);
    notifyListeners();

    // Optimistic update: update status in place instead of removing
    final index = _allLeaves.indexWhere((l) => l.id == leave.id);
    if (index >= 0) {
      _allLeaves[index] = LeaveRequest(
        id: leave.id,
        userId: leave.userId,
        userName: leave.userName,
        department: leave.department,
        leaveType: leave.leaveType,
        startDate: leave.startDate,
        endDate: leave.endDate,
        isHalfDay: leave.isHalfDay,
        halfDayPart: leave.halfDayPart,
        reason: leave.reason,
        status: LeaveStatus.approved, // Update status
        createdAt: leave.createdAt,
        rejectionReason: leave.rejectionReason,
        adminComment: comment, // Store admin comment if provided
        attachments: leave.attachments,
      );
    }
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (leave.id.startsWith('demo-')) {
      // Update cache
      const cacheKey = 'admin_pending_leaves';
      _cache.set<List<LeaveRequest>>(
        cacheKey,
        _allLeaves,
        ttl: const Duration(hours: 24),
        toJson: (leaves) => {
          'data': leaves.map((l) => l.toJson()).toList(),
        },
      );
      _error = null;
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
      return;
    }

    try {
      await _repository.approveLeave(leave.id, comment: comment);
      // Refresh list
      await loadPending(forceRefresh: true);
      _error = null;
    } catch (e) {
      // Handle 401 unauthorized
      if (e is ApiException && e.statusCode == 401) {
        if (context.mounted) {
          context.read<AppState>().logout();
          context.go('/login');
        }
        _error = 'Unauthorized';
        _loadingLeaveIds.remove(leave.id);
        notifyListeners();
        return;
      }
      // Rollback optimistic update on error
      final rollbackIndex = _allLeaves.indexWhere((l) => l.id == leave.id);
      if (rollbackIndex >= 0) {
        _allLeaves[rollbackIndex] = leave; // Restore original leave
      } else {
        _allLeaves.add(leave); // Add back if somehow removed
        _allLeaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _error = e.toString();
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
      rethrow;
    } finally {
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
    }
  }

  /// Reject a leave request (optimistic update)
  Future<void> rejectOne(
    BuildContext context,
    LeaveRequest leave, {
    required String reason,
  }) async {
    _loadingLeaveIds.add(leave.id);
    notifyListeners();

    // Optimistic update: update status in place instead of removing
    final index = _allLeaves.indexWhere((l) => l.id == leave.id);
    if (index >= 0) {
      _allLeaves[index] = LeaveRequest(
        id: leave.id,
        userId: leave.userId,
        userName: leave.userName,
        department: leave.department,
        leaveType: leave.leaveType,
        startDate: leave.startDate,
        endDate: leave.endDate,
        isHalfDay: leave.isHalfDay,
        halfDayPart: leave.halfDayPart,
        reason: leave.reason,
        status: LeaveStatus.rejected, // Update status
        createdAt: leave.createdAt,
        rejectionReason: reason, // Store rejection reason
        adminComment: leave.adminComment,
        attachments: leave.attachments,
      );
    }
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (leave.id.startsWith('demo-')) {
      // Update cache
      const cacheKey = 'admin_pending_leaves';
      _cache.set<List<LeaveRequest>>(
        cacheKey,
        _allLeaves,
        ttl: const Duration(hours: 24),
        toJson: (leaves) => {
          'data': leaves.map((l) => l.toJson()).toList(),
        },
      );
      _error = null;
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
      return;
    }

    try {
      await _repository.rejectLeave(leave.id, reason: reason);
      // Refresh list
      await loadPending(forceRefresh: true);
      _error = null;
    } catch (e) {
      // Handle 401 unauthorized
      if (e is ApiException && e.statusCode == 401) {
        if (context.mounted) {
          context.read<AppState>().logout();
          context.go('/login');
        }
        _error = 'Unauthorized';
        _loadingLeaveIds.remove(leave.id);
        notifyListeners();
        return;
      }
      // Rollback optimistic update on error
      final rollbackIndex = _allLeaves.indexWhere((l) => l.id == leave.id);
      if (rollbackIndex >= 0) {
        _allLeaves[rollbackIndex] = leave; // Restore original leave
      } else {
        _allLeaves.add(leave); // Add back if somehow removed
        _allLeaves.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _error = e.toString();
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
      rethrow;
    } finally {
      _loadingLeaveIds.remove(leave.id);
      notifyListeners();
    }
  }

  /// Seed demo data for testing
  void seedDemo() {
    final now = DateTime.now();
    _allLeaves = [
      // Pending requests (at least 2)
      LeaveRequest(
        id: 'demo-leave-pending-1',
        userId: 'user-1',
        userName: 'John Doe',
        department: 'Engineering',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 7)),
        isHalfDay: false,
        reason: 'Family vacation to the mountains. Need time off to spend quality time with family and recharge.',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LeaveRequest(
        id: 'demo-leave-pending-2',
        userId: 'user-2',
        userName: 'Jane Smith',
        department: 'Marketing',
        leaveType: LeaveType.sick,
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 10)),
        isHalfDay: true,
        halfDayPart: HalfDayPart.am,
        reason: 'Medical appointment for annual checkup. Will return in the afternoon.',
        status: LeaveStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      // Approved request (1)
      LeaveRequest(
        id: 'demo-leave-approved-1',
        userId: 'user-4',
        userName: 'Alice Williams',
        department: 'Sales',
        leaveType: LeaveType.annual,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.subtract(const Duration(days: 3)),
        isHalfDay: false,
        reason: 'Holiday break with family',
        status: LeaveStatus.approved,
        createdAt: now.subtract(const Duration(days: 10)),
        adminComment: 'Approved - enjoy your holiday!',
      ),
      // Rejected request (1)
      LeaveRequest(
        id: 'demo-leave-rejected-1',
        userId: 'user-5',
        userName: 'Charlie Brown',
        department: 'Operations',
        leaveType: LeaveType.annual,
        startDate: now.add(const Duration(days: 20)),
        endDate: now.add(const Duration(days: 25)),
        isHalfDay: false,
        reason: 'Personal time off for family event',
        status: LeaveStatus.rejected,
        createdAt: now.subtract(const Duration(days: 5)),
        rejectionReason: 'Insufficient leave balance. Please check your available leave days.',
        adminComment: 'Contact HR to discuss alternative arrangements.',
      ),
    ];

    // Write to cache so data persists through navigation
    const cacheKey = 'admin_pending_leaves';
    _cache.set<List<LeaveRequest>>(
      cacheKey,
      _allLeaves,
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

  /// Debug-only seed that reuses seedDemo
  void seedDebugData() {
    if (!kDebugMode) return;
    if (_allLeaves.isNotEmpty) return;
    seedDemo();
  }

  /// Clear demo data (reset to empty)
  void clearDemo() {
    _allLeaves = [];
    _error = null;
    _usingStale = false;
    _hasEverLoaded = false;
    notifyListeners();
  }
}
