import 'package:dio/dio.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';
import 'package:sns_clocked_in/features/company_calendar/domain/calendar_day.dart';

/// API exception for calendar errors
class ApiException implements Exception {
  ApiException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
}

/// Repository for company calendar data
abstract class CompanyCalendarRepository {
  /// Get calendar configuration (working days, hours)
  Future<CompanyCalendarConfig> getCalendarConfig();

  /// Get calendar days for a specific month
  Future<List<CalendarDay>> getCalendarDays({
    required int year,
    required int month,
    bool forceRefresh = false,
  });

  /// Get details for a specific day
  Future<CalendarDay?> getDayDetails(DateTime date);
}

/// Mock implementation for company calendar
class MockCompanyCalendarRepository implements CompanyCalendarRepository {
  @override
  Future<CompanyCalendarConfig> getCalendarConfig() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const CompanyCalendarConfig(
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      workingHours: {'start': '09:00', 'end': '17:00'},
    );
  }

  @override
  Future<List<CalendarDay>> getCalendarDays({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final days = <CalendarDay>[];
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    // Generate days for the month
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final weekday = date.weekday;

      // Determine day type
      DayType type;
      String? name;

      // Check if weekend (Saturday = 6, Sunday = 7)
      if (weekday == 6 || weekday == 7) {
        type = DayType.weekend;
      } else {
        // Check if working day (Monday-Friday)
        if (weekday >= 1 && weekday <= 5) {
          type = DayType.working;
        } else {
          type = DayType.weekend;
        }
      }

      // Add some mock holidays
      if (day == 1 && month == 1) {
        type = DayType.holiday;
        name = 'New Year';
      }

      days.add(CalendarDay(
        date: date,
        type: type,
        name: name,
      ));
    }

    return days;
  }

  @override
  Future<CalendarDay?> getDayDetails(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final days = await getCalendarDays(
      year: date.year,
      month: date.month,
    );
    return days.firstWhere(
      (d) => d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
      orElse: () => CalendarDay(
        date: date,
        type: date.weekday >= 1 && date.weekday <= 5
            ? DayType.working
            : DayType.weekend,
      ),
    );
  }
}

/// Real API implementation for company calendar
class ApiCompanyCalendarRepository implements CompanyCalendarRepository {
  ApiCompanyCalendarRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  static const Duration _cacheTtl = Duration(hours: 24);
  static const String _configCacheKey = 'company_calendar_config_v1';
  static const String _daysCacheKeyPrefix = 'company_calendar_days_';

  @override
  Future<CompanyCalendarConfig> getCalendarConfig() async {
    // Check cache
    final cached = _cache.get<CompanyCalendarConfig>(
      _configCacheKey,
      fromJson: (json) => CompanyCalendarConfig.fromJson(json),
    );
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _apiClient.get('/admin/company-calendar/config');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final config = CompanyCalendarConfig.fromJson(
            data['data'] as Map<String, dynamic>,
          );

          // Cache it
          _cache.set<CompanyCalendarConfig>(
            _configCacheKey,
            config,
            ttl: _cacheTtl,
            toJson: (config) => config.toJson(),
          );

          return config;
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Return default config on error
      return const CompanyCalendarConfig(
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      );
    }
  }

  @override
  Future<List<CalendarDay>> getCalendarDays({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$_daysCacheKeyPrefix$year-$month';

    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<CalendarDay>>(
        cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => CalendarDay.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        return cached;
      }
    }

    try {
      final response = await _apiClient.get(
        '/admin/company-calendar/days',
        queryParameters: {
          'year': year,
          'month': month,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final daysList = data['data'] as List<dynamic>? ?? [];

          final days = daysList
              .map((item) => CalendarDay.fromJson(item as Map<String, dynamic>))
              .toList();

          // Cache it
          _cache.set<List<CalendarDay>>(
            cacheKey,
            days,
            ttl: _cacheTtl,
            toJson: (days) => {
              'timestamp': DateTime.now().toIso8601String(),
              'data': days.map((d) => d.toJson()).toList(),
            },
          );

          return days;
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Return empty list on error
      return [];
    }
  }

  @override
  Future<CalendarDay?> getDayDetails(DateTime date) async {
    final days = await getCalendarDays(
      year: date.year,
      month: date.month,
    );
    return days.firstWhere(
      (d) => d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
      orElse: () => CalendarDay(
        date: date,
        type: date.weekday >= 1 && date.weekday <= 5
            ? DayType.working
            : DayType.weekend,
      ),
    );
  }
}
