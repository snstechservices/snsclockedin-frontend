import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/leave/domain/leave_cash_out.dart';

/// Store for managing leave cash out agreements
class LeaveCashOutStore extends ChangeNotifier {
  LeaveCashOutStore();

  // State
  List<LeaveCashOut> _items = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LeaveCashOut> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load cash out items
  /// Phase 1: No real API calls, just simulates delay if forceRefresh is true
  Future<void> load({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint('[LeaveCashOutStore] load(forceRefresh: $forceRefresh)');
    }

    // If not forcing refresh and we have data, return early
    if (!forceRefresh && _items.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[LeaveCashOutStore] SKIP: Store has ${_items.length} items');
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

    // No data and not forcing refresh - return empty
    _items = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Seed demo data for testing
  void seedDemo() {
    final now = DateTime.now();
    _items = [
      LeaveCashOut(
        id: 'demo-cashout-1',
        employeeId: 'emp-1',
        employeeName: 'John Doe',
        leaveType: 'Annual Leave',
        amount: 500.0,
        status: CashOutStatus.pending,
        date: now.subtract(const Duration(days: 2)),
      ),
      LeaveCashOut(
        id: 'demo-cashout-2',
        employeeId: 'emp-2',
        employeeName: 'Jane Smith',
        leaveType: 'Annual Leave',
        amount: 750.0,
        status: CashOutStatus.approved,
        date: now.subtract(const Duration(days: 5)),
      ),
      LeaveCashOut(
        id: 'demo-cashout-3',
        employeeId: 'emp-4',
        employeeName: 'Bob Johnson',
        leaveType: 'Annual Leave',
        amount: 300.0,
        status: CashOutStatus.rejected,
        date: now.subtract(const Duration(days: 7)),
      ),
    ];

    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear demo data (reset to empty)
  void clearDemo() {
    _items = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
