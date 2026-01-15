import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/state/app_state.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/timesheet/data/admin_approvals_repository.dart';
import 'package:sns_clocked_in/features/timesheet/domain/attendance_record.dart';

/// Admin approvals store for managing pending and approved timesheets
/// Uses optimistic updates for better UX
class AdminApprovalsStore extends ChangeNotifier {
  AdminApprovalsStore({
    required AdminApprovalsRepositoryInterface repository,
    SimpleCache? cache,
  })  : _repository = repository,
        _cache = cache ?? SimpleCache() {
    print('[AdminApprovalsStore] CONSTRUCTOR CALLED - Store instance created');
  }

  final AdminApprovalsRepositoryInterface _repository;
  final SimpleCache _cache;

  // State
  List<AttendanceRecord> _pendingRecords = [];
  List<AttendanceRecord> _approvedRecords = [];
  bool _isLoadingPending = false;
  bool _isLoadingApproved = false;
  String? _errorPending;
  String? _errorApproved;
  bool _usingStalePending = false;
  bool _usingStaleApproved = false;
  int _selectedTab = 0; // 0 = pending, 1 = approved
  final Set<String> _loadingRecordIds = {}; // Track which records are being processed
  bool _isBulkApproving = false;
  bool _hasEverLoadedPending = false; // Track if we've ever successfully loaded pending
  bool _hasEverLoadedApproved = false; // Track if we've ever successfully loaded approved

  // Getters
  List<AttendanceRecord> get pendingRecords => List.unmodifiable(_pendingRecords);
  List<AttendanceRecord> get approvedRecords => List.unmodifiable(_approvedRecords);
  bool get isLoadingPending => _isLoadingPending;
  bool get isLoadingApproved => _isLoadingApproved;
  bool get isLoading => _isLoadingPending || _isLoadingApproved;
  String? get errorPending => _errorPending;
  String? get errorApproved => _errorApproved;
  String? get error => _errorPending ?? _errorApproved;
  bool get usingStalePending => _usingStalePending;
  bool get usingStaleApproved => _usingStaleApproved;
  int get selectedTab => _selectedTab;
  bool isRecordLoading(String recordId) => _loadingRecordIds.contains(recordId);
  bool get isBulkApproving => _isBulkApproving;

  /// Set selected tab
  void setSelectedTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      notifyListeners();
    }
  }

  /// Get eligible records for bulk auto-approve
  /// Must be completed (has checkout time) AND pending approval
  List<AttendanceRecord> get eligibleForBulkApprove {
    return _pendingRecords.where((r) =>
      r.isCompleted && r.approvalStatus == ApprovalStatus.pending,
    ).toList();
  }

  /// Load pending timesheets
  Future<void> loadPending({bool forceRefresh = false}) async {
    // ALWAYS print debug logs (not conditional on kDebugMode) to ensure visibility
    print('[AdminApprovalsStore] ===== loadPending CALLED =====');
    print('[AdminApprovalsStore] forceRefresh: $forceRefresh');
    print('[AdminApprovalsStore] _pendingRecords.length: ${_pendingRecords.length}');
    print('[AdminApprovalsStore] _hasEverLoadedPending: $_hasEverLoadedPending');
    print('[AdminApprovalsStore] Cache exists: ${_cache.exists('admin_pending_timesheets')}');
    
    if (kDebugMode) {
      debugPrint('[AdminApprovalsStore] loadPending(forceRefresh: $forceRefresh)');
      debugPrint('[AdminApprovalsStore] Cache exists check: ${_cache.exists('admin_pending_timesheets')}');
      debugPrint('[AdminApprovalsStore] Store records count: ${_pendingRecords.length}');
      debugPrint('[AdminApprovalsStore] Has ever loaded: $_hasEverLoadedPending');
    }
    
    // CRITICAL GUARD: If not forcing refresh and we have no data, try cache FIRST
    // If we can read from cache (even if empty), use it and return
    // If we can't read from cache at all, skip API call (offline protection)
    // This must be checked FIRST before any other logic
    print('[AdminApprovalsStore] Guard check: !forceRefresh=${!forceRefresh}, _pendingRecords.isEmpty=${_pendingRecords.isEmpty}');
    if (!forceRefresh && _pendingRecords.isEmpty) {
      print('[AdminApprovalsStore] GUARD MATCHED - checking cache...');
      // Try to read from cache (stale first, then fresh)
      List<AttendanceRecord>? cached;
      bool isStale = false;
      
      try {
        // Try stale cache first (doesn't remove expired entries)
        cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_pending_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (cached != null) {
          isStale = true;
        } else {
          // Try fresh cache (removes expired entries)
          cached = _cache.get<List<AttendanceRecord>>(
            'admin_pending_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
        }
      } catch (e) {
        // Cache read failed
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] Cache read error in guard: $e');
        }
        cached = null;
      }
      
      // If we successfully read from cache (even if empty list), use it
      if (cached != null) {
        print('[AdminApprovalsStore] ✓ CACHE FOUND: ${cached.length} records (stale: $isStale) - SKIPPING API');
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Using cached data (${cached.length} records, stale: $isStale)');
        }
        _pendingRecords = cached;
        _usingStalePending = isStale;
        _errorPending = null;
        _isLoadingPending = false;
        _hasEverLoadedPending = true;
        notifyListeners();
        return;
      }
      
      // If we couldn't read from cache at all, skip API call (offline protection)
      print('[AdminApprovalsStore] ✗ NO CACHE READABLE - SKIPPING API CALL (OFFLINE PROTECTION)');
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: No cache readable + no data + not forcing refresh, returning empty (CRITICAL OFFLINE PROTECTION)');
      }
      _pendingRecords = [];
      _errorPending = null;
      _isLoadingPending = false;
      _usingStalePending = false;
      notifyListeners();
      return;
    } else {
      print('[AdminApprovalsStore] GUARD NOT MATCHED - continuing to next checks...');
    }
    
    // If not forcing refresh, check cache and store first (avoids API calls when offline)
    // NOTE: This block should rarely be reached if the guard above works correctly
    if (!forceRefresh) {
      // If we already have records in store, use them (seeded data or previous load)
      if (_pendingRecords.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Store has ${_pendingRecords.length} pending records');
        }
        // Try to update from cache if available, but don't clear existing records
        try {
          var cached = _cache.get<List<AttendanceRecord>>(
            'admin_pending_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
          if (cached != null && cached.isNotEmpty) {
            _pendingRecords = cached;
            _usingStalePending = false;
          }
        } catch (e) {
          // Cache read failed, keep existing records
        }
        _errorPending = null;
        _isLoadingPending = false;
        notifyListeners();
        return;
      }
      
      // No store records, try cache
      // IMPORTANT: Check stale cache FIRST before checking if cache exists
      // This is because get() removes expired entries, which would make exists() return false
      try {
        // Try stale cache first (doesn't remove expired entries)
        var cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_pending_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        
        if (cached != null) {
          // We have stale cache data, use it
          _usingStalePending = true;
          if (kDebugMode) {
            debugPrint('[AdminApprovalsStore] SKIP API: Found ${cached.length} records in stale cache');
          }
          _pendingRecords = cached;
          _errorPending = null;
          _isLoadingPending = false;
          _hasEverLoadedPending = true;
          notifyListeners();
          return;
        }
        
        // Try fresh cache (removes expired entries)
        cached = _cache.get<List<AttendanceRecord>>(
          'admin_pending_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        
        if (cached != null) {
          // We have fresh cache data, use it
          if (kDebugMode) {
            debugPrint('[AdminApprovalsStore] SKIP API: Found ${cached.length} records in fresh cache');
          }
          _pendingRecords = cached;
          _errorPending = null;
          _isLoadingPending = false;
          _usingStalePending = false;
          _hasEverLoadedPending = true;
          notifyListeners();
          return;
        }
        
      } catch (e) {
        // Cache read failed, will check if cache exists below
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] Cache read error: $e');
        }
      }
      
      // If cache exists (even if expired and couldn't be read), don't call API unless forcing refresh
      // This prevents API calls when we have any cache entry (even expired/invalid)
      if (_cache.exists('admin_pending_timesheets')) {
        // Cache exists but couldn't be read - use empty list instead of calling API
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Cache exists but unreadable, using empty list');
        }
        _pendingRecords = [];
        _errorPending = null;
        _isLoadingPending = false;
        _usingStalePending = true;
        _hasEverLoadedPending = true;
        notifyListeners();
        return;
      }
    }

    // Final guard: If we have demo data and not forcing refresh, don't call API
    if (!forceRefresh && _pendingRecords.any((r) => r.id.startsWith('demo-'))) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Demo data detected in store');
      }
      _isLoadingPending = false;
      _errorPending = null;
      _usingStalePending = false;
      _hasEverLoadedPending = true;
      notifyListeners();
      return;
    }
    
    // If we've loaded before and cache exists, don't call API unless forcing refresh
    if (!forceRefresh && _hasEverLoadedPending && _cache.exists('admin_pending_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Already loaded before + cache exists');
      }
      _pendingRecords = [];
      _errorPending = null;
      _isLoadingPending = false;
      _usingStalePending = true;
      notifyListeners();
      return;
    }
    
    // If cache exists (from seeding) and not forcing refresh, don't call API
    if (!forceRefresh && _cache.exists('admin_pending_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Cache exists (from seeding), reading from cache');
      }
      // Cache exists - try to read it one more time, or use empty
      try {
        final cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_pending_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (cached != null) {
          _pendingRecords = cached;
          _usingStalePending = cached.isEmpty ? false : true;
        } else {
          _pendingRecords = [];
          _usingStalePending = true;
        }
      } catch (e) {
        _pendingRecords = [];
        _usingStalePending = true;
      }
      _errorPending = null;
      _isLoadingPending = false;
      _hasEverLoadedPending = true;
      notifyListeners();
      return;
    }

    // Final check: If not forcing refresh and we have no cache, just return empty
    // This prevents API calls when offline or when no backend is available
    // CRITICAL: Never call API if no cache exists and we're not forcing refresh
    // This is the most important guard to prevent "Failed host lookup" errors
    if (!forceRefresh && !_cache.exists('admin_pending_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: No cache exists + not forcing refresh, returning empty (offline protection)');
      }
      _pendingRecords = [];
      _errorPending = null;
      _isLoadingPending = false;
      _usingStalePending = false;
      // Don't set _hasEverLoadedPending here - allow retry on next navigation if cache gets populated
      notifyListeners();
      return;
    }

    // All guards passed - making API call
    if (kDebugMode) {
      debugPrint('[AdminApprovalsStore] CALLING API: /attendance/pending (forceRefresh: $forceRefresh)');
    }
    _isLoadingPending = true;
    _errorPending = null;
    _usingStalePending = false;
    notifyListeners();

    // FINAL GUARD: Never call API if not forcing refresh and we have no READABLE cache
    // This is the last line of defense before the repository call
    // We check if cache is actually readable, not just if it exists (exists() returns true for expired entries)
    if (!forceRefresh) {
      // Try to actually read from cache (both stale and fresh) to see if we have ANY usable data
      List<AttendanceRecord>? readableCache;
      try {
        readableCache = _cache.getStale<List<AttendanceRecord>>(
          'admin_pending_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (readableCache == null) {
          readableCache = _cache.get<List<AttendanceRecord>>(
            'admin_pending_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
        }
      } catch (e) {
        readableCache = null;
      }
      
      print('[AdminApprovalsStore] FINAL GUARD: forceRefresh=$forceRefresh, readableCache=${readableCache != null}');
      if (readableCache == null) {
        print('[AdminApprovalsStore] ✗✗✗ FINAL GUARD BLOCKED API CALL - No readable cache ✗✗✗');
        _pendingRecords = [];
        _errorPending = null;
        _isLoadingPending = false;
        _usingStalePending = false;
        notifyListeners();
        return;
      }
    }

    print('[AdminApprovalsStore] ⚠⚠⚠ CALLING REPOSITORY.fetchPending() ⚠⚠⚠');
    try {
      final result = await _repository.fetchPending(forceRefresh: forceRefresh);
      _hasEverLoadedPending = true;
      // If we got data, always update
      if (result.data.isNotEmpty) {
        _pendingRecords = result.data;
        _usingStalePending = result.isStale;
        _errorPending = null;
      } else if (forceRefresh) {
        // Force refresh returned empty - this means API failed and no cache
        // Preserve existing records if we have them (seeded data or previous cache)
        // Only clear if we truly have no data
        if (_pendingRecords.isEmpty) {
          _pendingRecords = [];
        }
        // If we're using stale data, keep the stale flag
        _usingStalePending = result.isStale;
        // Don't set error if we have existing records to show
        if (_pendingRecords.isEmpty) {
          _errorPending = null; // Empty state, not an error
        } else {
          _errorPending = null; // We have data to show, no error
        }
      } else {
        // Not forcing refresh and got empty - preserve existing records
        _usingStalePending = result.isStale;
        _errorPending = null;
      }
    } catch (e) {
      // Network error - preserve existing records (seeded data or stale cache)
      // Only set error if we have no data to show
      if (_pendingRecords.isEmpty) {
        _errorPending = e.toString();
      } else {
        // We have data to show, just mark as stale
        _errorPending = null;
        _usingStalePending = true;
      }
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Load approved timesheets
  Future<void> loadApproved({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint('[AdminApprovalsStore] loadApproved(forceRefresh: $forceRefresh)');
      debugPrint('[AdminApprovalsStore] Cache exists check: ${_cache.exists('admin_approved_timesheets')}');
      debugPrint('[AdminApprovalsStore] Store records count: ${_approvedRecords.length}');
      debugPrint('[AdminApprovalsStore] Has ever loaded: $_hasEverLoadedApproved');
    }
    
    // CRITICAL GUARD: If not forcing refresh and we have no data, try cache FIRST
    // If we can read from cache (even if empty), use it and return
    // If we can't read from cache at all, skip API call (offline protection)
    // This must be checked FIRST before any other logic
    if (!forceRefresh && _approvedRecords.isEmpty) {
      // Try to read from cache (stale first, then fresh)
      List<AttendanceRecord>? cached;
      bool isStale = false;
      
      try {
        // Try stale cache first (doesn't remove expired entries)
        cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_approved_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (cached != null) {
          isStale = true;
        } else {
          // Try fresh cache (removes expired entries)
          cached = _cache.get<List<AttendanceRecord>>(
            'admin_approved_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
        }
      } catch (e) {
        // Cache read failed
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] Cache read error in guard: $e');
        }
        cached = null;
      }
      
      // If we successfully read from cache (even if empty list), use it
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Using cached data (${cached.length} records, stale: $isStale)');
        }
        _approvedRecords = cached;
        _usingStaleApproved = isStale;
        _errorApproved = null;
        _isLoadingApproved = false;
        _hasEverLoadedApproved = true;
        notifyListeners();
        return;
      }
      
      // If we couldn't read from cache at all, skip API call (offline protection)
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: No cache readable + no data + not forcing refresh, returning empty (CRITICAL OFFLINE PROTECTION)');
      }
      _approvedRecords = [];
      _errorApproved = null;
      _isLoadingApproved = false;
      _usingStaleApproved = false;
      notifyListeners();
      return;
    }
    
    // If not forcing refresh, check cache and store first (avoids API calls when offline)
    if (!forceRefresh) {
      // If we already have records in store, use them (seeded data or previous load)
      if (_approvedRecords.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Store has ${_approvedRecords.length} approved records');
        }
        // Try to update from cache if available, but don't clear existing records
        try {
          var cached = _cache.get<List<AttendanceRecord>>(
            'admin_approved_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
          if (cached != null && cached.isNotEmpty) {
            _approvedRecords = cached;
            _usingStaleApproved = false;
          }
        } catch (e) {
          // Cache read failed, keep existing records
        }
        _errorApproved = null;
        _isLoadingApproved = false;
        notifyListeners();
        return;
      }
      
      // No store records, try cache
      try {
        // IMPORTANT: Check stale cache FIRST before checking fresh cache
        // This is because get() removes expired entries, which would make exists() return false
        // Try stale cache first (doesn't remove expired entries)
        var cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_approved_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        
        if (cached != null) {
          _usingStaleApproved = true;
        } else {
          // Try fresh cache (removes expired entries)
          cached = _cache.get<List<AttendanceRecord>>(
            'admin_approved_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
        }
        
        if (cached != null) {
          // We have cached data (fresh or stale, even if empty), use it
          if (kDebugMode) {
            debugPrint('[AdminApprovalsStore] SKIP API: Found ${cached.length} records in ${_usingStaleApproved ? "stale" : "fresh"} cache');
          }
          _approvedRecords = cached;
          _errorApproved = null;
          _isLoadingApproved = false;
          _hasEverLoadedApproved = true;
          notifyListeners();
          return;
        }
      } catch (e) {
        // Cache read failed, will check if cache exists below
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] Cache read error: $e');
        }
      }
      
      // If cache exists (even if empty or expired), don't call API unless forcing refresh
      if (_cache.exists('admin_approved_timesheets')) {
        // Cache exists but couldn't be read - use empty list instead of calling API
        if (kDebugMode) {
          debugPrint('[AdminApprovalsStore] SKIP API: Cache exists but unreadable, using empty list');
        }
        _approvedRecords = [];
        _errorApproved = null;
        _isLoadingApproved = false;
        _usingStaleApproved = true;
        _hasEverLoadedApproved = true;
        notifyListeners();
        return;
      }
    }

    // Final guard: If we have demo data and not forcing refresh, don't call API
    if (!forceRefresh && _approvedRecords.any((r) => r.id.startsWith('demo-'))) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Demo data detected in store');
      }
      _isLoadingApproved = false;
      _errorApproved = null;
      _usingStaleApproved = false;
      _hasEverLoadedApproved = true;
      notifyListeners();
      return;
    }
    
    // If we've loaded before and cache exists, don't call API unless forcing refresh
    if (!forceRefresh && _hasEverLoadedApproved && _cache.exists('admin_approved_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Already loaded before + cache exists');
      }
      _approvedRecords = [];
      _errorApproved = null;
      _isLoadingApproved = false;
      _usingStaleApproved = true;
      notifyListeners();
      return;
    }
    
    // If cache exists (from seeding) and not forcing refresh, don't call API
    if (!forceRefresh && _cache.exists('admin_approved_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: Cache exists (from seeding), reading from cache');
      }
      // Cache exists - try to read it one more time, or use empty
      try {
        final cached = _cache.getStale<List<AttendanceRecord>>(
          'admin_approved_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (cached != null) {
          _approvedRecords = cached;
          _usingStaleApproved = cached.isEmpty ? false : true;
        } else {
          _approvedRecords = [];
          _usingStaleApproved = true;
        }
      } catch (e) {
        _approvedRecords = [];
        _usingStaleApproved = true;
      }
      _errorApproved = null;
      _isLoadingApproved = false;
      _hasEverLoadedApproved = true;
      notifyListeners();
      return;
    }

    // Final check: If not forcing refresh and we have no cache, just return empty
    // This prevents API calls when offline or when no backend is available
    // CRITICAL: Never call API if no cache exists and we're not forcing refresh
    // This is the most important guard to prevent "Failed host lookup" errors
    if (!forceRefresh && !_cache.exists('admin_approved_timesheets')) {
      if (kDebugMode) {
        debugPrint('[AdminApprovalsStore] SKIP API: No cache exists + not forcing refresh, returning empty (offline protection)');
      }
      _approvedRecords = [];
      _errorApproved = null;
      _isLoadingApproved = false;
      _usingStaleApproved = false;
      // Don't set _hasEverLoadedApproved here - allow retry on next navigation if cache gets populated
      notifyListeners();
      return;
    }

    // All guards passed - making API call
    if (kDebugMode) {
      debugPrint('[AdminApprovalsStore] CALLING API: /attendance/approved (forceRefresh: $forceRefresh)');
    }
    _isLoadingApproved = true;
    _errorApproved = null;
    _usingStaleApproved = false;
    notifyListeners();

    // FINAL GUARD: Never call API if not forcing refresh and we have no READABLE cache
    // This is the last line of defense before the repository call
    // We check if cache is actually readable, not just if it exists (exists() returns true for expired entries)
    if (!forceRefresh) {
      // Try to actually read from cache (both stale and fresh) to see if we have ANY usable data
      List<AttendanceRecord>? readableCache;
      try {
        readableCache = _cache.getStale<List<AttendanceRecord>>(
          'admin_approved_timesheets',
          fromJson: (json) {
            final list = json['data'] as List<dynamic>;
            return list
                .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          },
        );
        if (readableCache == null) {
          readableCache = _cache.get<List<AttendanceRecord>>(
            'admin_approved_timesheets',
            fromJson: (json) {
              final list = json['data'] as List<dynamic>;
              return list
                  .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
                  .toList();
            },
          );
        }
      } catch (e) {
        readableCache = null;
      }
      
      print('[AdminApprovalsStore] FINAL GUARD: forceRefresh=$forceRefresh, readableCache=${readableCache != null}');
      if (readableCache == null) {
        print('[AdminApprovalsStore] ✗✗✗ FINAL GUARD BLOCKED API CALL - No readable cache ✗✗✗');
        _approvedRecords = [];
        _errorApproved = null;
        _isLoadingApproved = false;
        _usingStaleApproved = false;
        notifyListeners();
        return;
      }
    }

    print('[AdminApprovalsStore] ⚠⚠⚠ CALLING REPOSITORY.fetchApproved() ⚠⚠⚠');
    try {
      final result = await _repository.fetchApproved(forceRefresh: forceRefresh);
      _hasEverLoadedApproved = true;
      // If we got data, always update
      if (result.data.isNotEmpty) {
        _approvedRecords = result.data;
        _usingStaleApproved = result.isStale;
        _errorApproved = null;
      } else if (forceRefresh) {
        // Force refresh returned empty - this means API failed and no cache
        // Preserve existing records if we have them (seeded data or previous cache)
        // Only clear if we truly have no data
        if (_approvedRecords.isEmpty) {
          _approvedRecords = [];
        }
        // If we're using stale data, keep the stale flag
        _usingStaleApproved = result.isStale;
        // Don't set error if we have existing records to show
        if (_approvedRecords.isEmpty) {
          _errorApproved = null; // Empty state, not an error
        } else {
          _errorApproved = null; // We have data to show, no error
        }
      } else {
        // Not forcing refresh and got empty - preserve existing records
        _usingStaleApproved = result.isStale;
        _errorApproved = null;
      }
    } catch (e) {
      // Network error - preserve existing records (seeded data or stale cache)
      // Only set error if we have no data to show
      if (_approvedRecords.isEmpty) {
        _errorApproved = e.toString();
      } else {
        // We have data to show, just mark as stale
        _errorApproved = null;
        _usingStaleApproved = true;
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
  Future<void> approveOne(BuildContext context, AttendanceRecord record) async {
    // Track loading state for this record
    _loadingRecordIds.add(record.id);
    notifyListeners();

    // Optimistic update: remove from pending immediately
    _pendingRecords.removeWhere((r) => r.id == record.id);
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (record.id.startsWith('demo-')) {
      final approvedRecord = AttendanceRecord(
        id: record.id,
        userId: record.userId,
        companyId: record.companyId,
        date: record.date,
        checkInTime: record.checkInTime,
        checkOutTime: record.checkOutTime,
        status: record.status,
        breaks: record.breaks,
        totalBreakTimeMinutes: record.totalBreakTimeMinutes,
        approvalStatus: ApprovalStatus.approved,
        adminComment: 'Approved (demo)',
        approvedBy: 'demo-admin',
        approvalDate: DateTime.now(),
        rejectionReason: record.rejectionReason,
        notes: record.notes,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
      );
      _approvedRecords.add(approvedRecord);
      _approvedRecords.sort((a, b) => b.date.compareTo(a.date));
      
      // Update cache
      _cache.set<List<AttendanceRecord>>(
        'admin_pending_timesheets',
        _pendingRecords,
        ttl: const Duration(hours: 24),
        toJson: (records) => {
          'data': records.map((r) => r.toJson()).toList(),
        },
      );
      _cache.set<List<AttendanceRecord>>(
        'admin_approved_timesheets',
        _approvedRecords,
        ttl: const Duration(hours: 24),
        toJson: (records) => {
          'data': records.map((r) => r.toJson()).toList(),
        },
      );
      
      _errorPending = null;
      _errorApproved = null;
      _loadingRecordIds.remove(record.id);
      notifyListeners();
      return;
    }

    try {
      await _repository.approve(record.id);
      // Refresh both lists in background
      await Future.wait([
        loadPending(forceRefresh: true),
        loadApproved(forceRefresh: true),
      ]);
      _errorPending = null;
      _errorApproved = null;
    } catch (e) {
      // Handle 401 unauthorized
      if (e is ApiException && e.statusCode == 401) {
        if (context.mounted) {
          context.read<AppState>().logout();
          context.go('/login');
        }
        _errorPending = 'Unauthorized';
        _errorApproved = 'Unauthorized';
        _loadingRecordIds.remove(record.id);
        notifyListeners();
        return;
      }
      // Rollback optimistic update on error
      _pendingRecords
        ..add(record)
        ..sort((a, b) => b.date.compareTo(a.date));
      _errorPending = e.toString();
      _loadingRecordIds.remove(record.id);
      notifyListeners();
      rethrow;
    } finally {
      _loadingRecordIds.remove(record.id);
      notifyListeners();
    }
  }

  /// Reject a timesheet (optimistic update)
  Future<void> rejectOne(
    BuildContext context,
    AttendanceRecord record, {
    required String reason,
  }) async {
    // Track loading state for this record
    _loadingRecordIds.add(record.id);
    notifyListeners();

    // Optimistic update: remove from pending immediately
    _pendingRecords.removeWhere((r) => r.id == record.id);
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (record.id.startsWith('demo-')) {
      // For demo data, we just remove from pending (rejected records don't go to approved)
      // Update cache
      _cache.set<List<AttendanceRecord>>(
        'admin_pending_timesheets',
        _pendingRecords,
        ttl: const Duration(hours: 24),
        toJson: (records) => {
          'data': records.map((r) => r.toJson()).toList(),
        },
      );
      
      _errorPending = null;
      _loadingRecordIds.remove(record.id);
      notifyListeners();
      return;
    }

    try {
      await _repository.reject(record.id, reason: reason);
      // Refresh pending list in background
      await loadPending(forceRefresh: true);
      _errorPending = null;
    } catch (e) {
      // Handle 401 unauthorized
      if (e is ApiException && e.statusCode == 401) {
        if (context.mounted) {
          context.read<AppState>().logout();
          context.go('/login');
        }
        _errorPending = 'Unauthorized';
        _loadingRecordIds.remove(record.id);
        notifyListeners();
        return;
      }
      // Rollback optimistic update on error
      _pendingRecords
        ..add(record)
        ..sort((a, b) => b.date.compareTo(a.date));
      _errorPending = e.toString();
      _loadingRecordIds.remove(record.id);
      notifyListeners();
      rethrow;
    } finally {
      _loadingRecordIds.remove(record.id);
      notifyListeners();
    }
  }

  /// Bulk auto-approve eligible records (completed/checked out only)
  /// Returns number of successfully approved records
  Future<int> bulkAutoApproveEligible(BuildContext context) async {
    final eligible = eligibleForBulkApprove;
    if (eligible.isEmpty) {
      throw Exception('No eligible records for bulk approval');
    }

    final recordIds = eligible.map((r) => r.id).toList();
    _isBulkApproving = true;
    _loadingRecordIds.addAll(recordIds);
    notifyListeners();

    // Check if all are demo records
    final allDemo = eligible.every((r) => r.id.startsWith('demo-'));

    // Optimistic update: remove approved records from pending
    final recordsToApprove = List<AttendanceRecord>.from(
      _pendingRecords.where((r) => recordIds.contains(r.id)),
    );
    _pendingRecords.removeWhere((r) => recordIds.contains(r.id));
    notifyListeners();

    // Handle demo data in-memory (no API call needed)
    if (allDemo) {
      final now = DateTime.now();
      for (final record in recordsToApprove) {
        final approvedRecord = AttendanceRecord(
          id: record.id,
          userId: record.userId,
          companyId: record.companyId,
          date: record.date,
          checkInTime: record.checkInTime,
          checkOutTime: record.checkOutTime,
          status: record.status,
          breaks: record.breaks,
          totalBreakTimeMinutes: record.totalBreakTimeMinutes,
          approvalStatus: ApprovalStatus.approved,
          adminComment: 'Auto-approved (demo)',
          approvedBy: 'demo-admin',
          approvalDate: now,
          rejectionReason: record.rejectionReason,
          notes: record.notes,
          createdAt: record.createdAt,
          updatedAt: now,
        );
        _approvedRecords.add(approvedRecord);
      }
      _approvedRecords.sort((a, b) => b.date.compareTo(a.date));
      
      // Update cache
      _cache.set<List<AttendanceRecord>>(
        'admin_pending_timesheets',
        _pendingRecords,
        ttl: const Duration(hours: 24),
        toJson: (records) => {
          'data': records.map((r) => r.toJson()).toList(),
        },
      );
      _cache.set<List<AttendanceRecord>>(
        'admin_approved_timesheets',
        _approvedRecords,
        ttl: const Duration(hours: 24),
        toJson: (records) => {
          'data': records.map((r) => r.toJson()).toList(),
        },
      );
      
      _errorPending = null;
      _errorApproved = null;
      final approvedCount = recordIds.length;
      _isBulkApproving = false;
      _loadingRecordIds.removeAll(recordIds);
      notifyListeners();
      return approvedCount;
    }

    try {
      await _repository.bulkAutoApprove();

      // Refresh both lists in background
      await Future.wait([
        loadPending(forceRefresh: true),
        loadApproved(forceRefresh: true),
      ]);

      _errorPending = null;
      _errorApproved = null;
      final approvedCount = recordIds.length;
      return approvedCount;
    } catch (e) {
      // Handle 401 unauthorized
      if (e is ApiException && e.statusCode == 401) {
        if (context.mounted) {
          context.read<AppState>().logout();
          context.go('/login');
        }
        _errorPending = 'Unauthorized';
        _errorApproved = 'Unauthorized';
        _isBulkApproving = false;
        _loadingRecordIds.clear();
        notifyListeners();
        return 0;
      }
      // Rollback optimistic update on error
      for (final record in recordsToApprove) {
        _pendingRecords.add(record);
      }
      _pendingRecords.sort((a, b) => b.date.compareTo(a.date));
      _errorPending = e.toString();
      _isBulkApproving = false;
      _loadingRecordIds.clear();
      notifyListeners();
      rethrow;
    } finally {
      _isBulkApproving = false;
      _loadingRecordIds.removeAll(recordIds);
      notifyListeners();
    }
  }

  /// Seed demo data for testing
  /// Also writes to cache so data persists through navigation and refresh
  void seedDemo() {
    final now = DateTime.now();
    _pendingRecords = [
      AttendanceRecord(
        id: 'demo-pending-1',
        userId: 'user-1',
        companyId: 'company-1',
        date: now.subtract(const Duration(days: 1)),
        checkInTime: now.subtract(const Duration(days: 1, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 1, hours: 1)),
        status: 'clocked_out',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AttendanceRecord(
        id: 'demo-pending-2',
        userId: 'user-2',
        companyId: 'company-1',
        date: now.subtract(const Duration(days: 2)),
        checkInTime: now.subtract(const Duration(days: 2, hours: 9, minutes: 15)),
        checkOutTime: now.subtract(const Duration(days: 2, hours: 0, minutes: 45)),
        status: 'clocked_out',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AttendanceRecord(
        id: 'demo-pending-3',
        userId: 'user-3',
        companyId: 'company-1',
        date: now.subtract(const Duration(days: 3)),
        checkInTime: now.subtract(const Duration(days: 3, hours: 9)),
        // No checkOutTime - not completed, so not eligible for bulk approve
        status: 'clocked_in',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
    _approvedRecords = [
      AttendanceRecord(
        id: 'demo-approved-1',
        userId: 'user-4',
        companyId: 'company-1',
        date: now.subtract(const Duration(days: 4)),
        checkInTime: now.subtract(const Duration(days: 4, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 4, hours: 1)),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin-1',
        approvalDate: now.subtract(const Duration(days: 4, hours: 2)),
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      AttendanceRecord(
        id: 'demo-approved-2',
        userId: 'user-5',
        companyId: 'company-1',
        date: now.subtract(const Duration(days: 5)),
        checkInTime: now.subtract(const Duration(days: 5, hours: 9)),
        checkOutTime: now.subtract(const Duration(days: 5, hours: 1)),
        status: 'clocked_out',
        approvalStatus: ApprovalStatus.approved,
        approvedBy: 'admin-1',
        approvalDate: now.subtract(const Duration(days: 5, hours: 2)),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];

    // Write to cache so data persists through navigation and refresh
    _cache.set<List<AttendanceRecord>>(
      'admin_pending_timesheets',
      _pendingRecords,
      ttl: const Duration(hours: 24), // Long TTL for demo data
      toJson: (records) => {
        'data': records.map((r) => r.toJson()).toList(),
      },
    );
    _cache.set<List<AttendanceRecord>>(
      'admin_approved_timesheets',
      _approvedRecords,
      ttl: const Duration(hours: 24), // Long TTL for demo data
      toJson: (records) => {
        'data': records.map((r) => r.toJson()).toList(),
      },
    );

    _errorPending = null;
    _errorApproved = null;
    _usingStalePending = false;
    _usingStaleApproved = false;
    _hasEverLoadedPending = true;
    _hasEverLoadedApproved = true;
    notifyListeners();
  }

  /// Clear demo data (reset to empty)
  /// Also clears cache entries
  void clearDemo() {
    _pendingRecords = [];
    _approvedRecords = [];
    _errorPending = null;
    _errorApproved = null;
    _usingStalePending = false;
    _usingStaleApproved = false;

    // Clear cache entries
    _cache.remove('admin_pending_timesheets');
    _cache.remove('admin_approved_timesheets');

    notifyListeners();
  }
}

