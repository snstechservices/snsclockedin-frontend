import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_accrual_log.dart';

/// Store for managing leave accrual logs
class LeaveAccrualStore extends ChangeNotifier {
  LeaveAccrualStore();

  // State
  List<LeaveAccrualLog> _logs = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LeaveAccrualLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load accrual logs
  /// Phase 1: No real API calls, just simulates delay if forceRefresh is true
  Future<void> load({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint('[LeaveAccrualStore] load(forceRefresh: $forceRefresh)');
    }

    // If not forcing refresh and we have data, return early
    if (!forceRefresh && _logs.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[LeaveAccrualStore] SKIP: Store has ${_logs.length} logs');
      }
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Phase 1: Simulate delay if forceRefresh, but don't call real API
    if (forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Keep existing data (no real API call in Phase 1)
      _isLoading = false;
      notifyListeners();
      return;
    }

    // No data and not forcing refresh - seed demo data for UI
    if (_logs.isEmpty) {
      seedDemo();
      return;
    }

    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Seed demo data for testing
  void seedDemo() {
    final now = DateTime.now();
    _logs = [
      LeaveAccrualLog(
        id: 'demo-accrual-1',
        employeeId: 'emp-1',
        employeeName: 'John Doe',
        leaveType: 'Annual Leave',
        hoursAccrued: 2.5,
        date: now.subtract(const Duration(days: 1)),
      ),
      LeaveAccrualLog(
        id: 'demo-accrual-2',
        employeeId: 'emp-2',
        employeeName: 'Jane Smith',
        leaveType: 'Annual Leave',
        hoursAccrued: 2.5,
        date: now.subtract(const Duration(days: 2)),
      ),
      LeaveAccrualLog(
        id: 'demo-accrual-3',
        employeeId: 'emp-4',
        employeeName: 'Bob Johnson',
        leaveType: 'Annual Leave',
        hoursAccrued: 2.5,
        date: now.subtract(const Duration(days: 3)),
      ),
      LeaveAccrualLog(
        id: 'demo-accrual-4',
        employeeId: 'emp-3',
        employeeName: 'Alice Williams',
        leaveType: 'Annual Leave',
        hoursAccrued: 2.5,
        date: now.subtract(const Duration(days: 5)),
      ),
    ];

    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear demo data (reset to empty)
  void clearDemo() {
    _logs = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
