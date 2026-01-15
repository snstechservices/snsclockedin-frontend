import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/time_tracking/data/time_tracking_repository.dart';
import 'package:sns_clocked_in/features/time_tracking/domain/time_entry.dart';

class AttendanceStore extends ChangeNotifier {
  final TimeTrackingRepository _repository;
  
  List<TimeEntry> _history = [];
  bool _isLoading = false;

  AttendanceStore({
    required TimeTrackingRepository repository,
  }) : _repository = repository;

  List<TimeEntry> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _history = await _repository.getRecentEntries();
    } catch (e) {
      debugPrint('Error loading attendance history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
