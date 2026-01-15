import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/features/company_calendar/data/company_calendar_repository.dart';
import 'package:sns_clocked_in/features/company_calendar/domain/calendar_day.dart';

/// Store for managing company calendar
class CompanyCalendarStore extends ChangeNotifier {
  CompanyCalendarStore({
    required CompanyCalendarRepository repository,
  }) : _repository = repository;

  final CompanyCalendarRepository _repository;

  // State
  CompanyCalendarConfig? _config;
  Map<String, List<CalendarDay>> _calendarDays = {}; // Key: "year-month"
  CalendarDay? _selectedDay;
  bool _isLoading = false;
  String? _error;

  // Getters
  CompanyCalendarConfig? get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CalendarDay? get selectedDay => _selectedDay;

  /// Get calendar days for a specific month
  List<CalendarDay> getCalendarDays(int year, int month) {
    final key = '$year-$month';
    return _calendarDays[key] ?? [];
  }

  /// Load calendar configuration
  Future<void> loadConfig() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _repository.getCalendarConfig();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load calendar days for a specific month
  Future<void> loadCalendarDays({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final days = await _repository.getCalendarDays(
        year: year,
        month: month,
        forceRefresh: forceRefresh,
      );
      final key = '$year-$month';
      _calendarDays[key] = days;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load day details
  Future<void> loadDayDetails(DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedDay = await _repository.getDayDetails(date);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _selectedDay = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set selected day (for UI)
  void setSelectedDay(CalendarDay? day) {
    _selectedDay = day;
    notifyListeners();
  }
}
