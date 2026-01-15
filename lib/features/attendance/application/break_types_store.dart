import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/attendance/data/break_types_repository.dart';

/// Store for managing break types
class BreakTypesStore extends ChangeNotifier {
  BreakTypesStore({
    required BreakTypesRepository repository,
  }) : _repository = repository;

  final BreakTypesRepository _repository;

  // State
  List<BreakType> _breakTypes = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<BreakType> get breakTypes => List.unmodifiable(_breakTypes);
  List<BreakType> get activeBreakTypes => _breakTypes.where((bt) => bt.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load break types
  Future<void> load({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _breakTypes = await _repository.fetchBreakTypes(forceRefresh: forceRefresh);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _breakTypes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new break type (admin only)
  Future<void> createBreakType(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.createBreakType(data);
      // Refresh list
      await load(forceRefresh: true);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing break type (admin only)
  Future<void> updateBreakType(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.updateBreakType(id, data);
      // Refresh list
      await load(forceRefresh: true);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a break type (admin only)
  Future<void> deleteBreakType(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteBreakType(id);
      // Refresh list
      await load(forceRefresh: true);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

