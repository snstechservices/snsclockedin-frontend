import 'dart:io';
import 'package:dio/dio.dart';
import 'package:sns_clocked_in/core/network/api_client.dart';
import 'package:sns_clocked_in/core/storage/simple_cache.dart';

/// Break type model
class BreakType {
  const BreakType({
    required this.name,
    this.id,
    this.displayName,
    this.description,
    this.minDurationMinutes,
    this.maxDurationMinutes,
    this.icon,
    this.color,
    this.isActive = true,
  });

  final String name;
  final String? id; // API ID (for update/delete operations)
  final String? displayName;
  final String? description;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;
  final String? icon;
  final String? color;
  final bool isActive;

  /// Display name (falls back to name if displayName is null)
  String get label => displayName ?? name;

  /// Get duration range as string (e.g., "30-60 minutes")
  String get durationRange {
    if (minDurationMinutes == null && maxDurationMinutes == null) {
      return '';
    }
    if (minDurationMinutes == null) {
      return 'Up to ${maxDurationMinutes}m';
    }
    if (maxDurationMinutes == null) {
      return '${minDurationMinutes}m+';
    }
    if (minDurationMinutes == maxDurationMinutes) {
      return '$minDurationMinutes minutes';
    }
    return '$minDurationMinutes-$maxDurationMinutes minutes';
  }

  /// Create from JSON (API response)
  factory BreakType.fromJson(Map<String, dynamic> json) {
    return BreakType(
      name: json['name'] as String,
      id: json['_id'] as String? ?? json['id'] as String?,
      displayName: json['displayName'] as String?,
      description: json['description'] as String?,
      minDurationMinutes: json['minDuration'] as int?,
      maxDurationMinutes: json['maxDuration'] as int?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Convert to JSON (for caching and API)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (id != null) '_id': id,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      if (minDurationMinutes != null) 'minDuration': minDurationMinutes,
      if (maxDurationMinutes != null) 'maxDuration': maxDurationMinutes,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      'isActive': isActive,
    };
  }
}

/// Repository for break types with 24-hour cache
/// Matches legacy caching rules from TIMESHEET_LEGACY_AUDIT_REPORT.md
abstract class BreakTypesRepository {
  Future<List<BreakType>> fetchBreakTypes({bool forceRefresh = false});
  
  /// Create a new break type (admin only)
  Future<BreakType> createBreakType(Map<String, dynamic> data);
  
  /// Update an existing break type (admin only)
  Future<BreakType> updateBreakType(String id, Map<String, dynamic> data);
  
  /// Delete a break type (admin only)
  Future<void> deleteBreakType(String id);
}

/// Mock implementation for break types (for testing/development)
class MockBreakTypesRepository implements BreakTypesRepository {
  List<BreakType> _mockBreakTypes = [
    const BreakType(
      name: 'lunch',
      displayName: 'Lunch Break',
      description: 'Standard lunch break for employees',
      minDurationMinutes: 30,
      maxDurationMinutes: 60,
      icon: 'restaurant',
      color: '#2E7D32',
      isActive: true,
    ),
    const BreakType(
      name: 'personal',
      displayName: 'Personal Break',
      description: 'Personal time break for employees',
      minDurationMinutes: 5,
      maxDurationMinutes: 30,
      icon: 'person',
      color: '#7B1FA2',
      isActive: true,
    ),
    const BreakType(
      name: 'coffee_break',
      displayName: 'Coffee Break',
      description: 'Short coffee break for employees',
      minDurationMinutes: 5,
      maxDurationMinutes: 15,
      icon: 'coffee',
      color: '#ED6C02',
      isActive: true,
    ),
  ];

  @override
  Future<List<BreakType>> fetchBreakTypes({bool forceRefresh = false}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockBreakTypes);
  }

  @override
  Future<BreakType> createBreakType(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Add generated ID for mock
    final dataWithId = {...data, '_id': 'break_${DateTime.now().millisecondsSinceEpoch}'};
    final breakType = BreakType.fromJson(dataWithId);
    _mockBreakTypes.add(breakType);
    return breakType;
  }

  @override
  Future<BreakType> updateBreakType(String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockBreakTypes.indexWhere((bt) => bt.id == id || bt.name == id);
    if (index >= 0) {
      final updated = BreakType.fromJson({..._mockBreakTypes[index].toJson(), ...data, 'id': _mockBreakTypes[index].id ?? _mockBreakTypes[index].name});
      _mockBreakTypes[index] = updated;
      return updated;
    }
    throw Exception('Break type not found');
  }

  @override
  Future<void> deleteBreakType(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockBreakTypes.removeWhere((bt) => bt.id == id || bt.name == id);
  }
}

/// Real implementation for break types with API and cache
class ApiBreakTypesRepository implements BreakTypesRepository {
  ApiBreakTypesRepository({
    ApiClient? apiClient,
    SimpleCache? cache,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cache = cache ?? SimpleCache();

  final ApiClient _apiClient;
  final SimpleCache _cache;

  /// Cache TTL for break types (24 hours per legacy rules)
  static const Duration _cacheTtl = Duration(hours: 24);
  static const String _cacheKey = 'break_types_v1';

  @override
  /// Fetch break types
  /// GET /attendance/break-types
  Future<List<BreakType>> fetchBreakTypes({bool forceRefresh = false}) async {
    // Check cache if not forcing refresh
    if (!forceRefresh) {
      final cached = _cache.get<List<BreakType>>(
        _cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => BreakType.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (cached != null) {
        return cached;
      }
    }

    // Try network request
    try {
      final response = await _apiClient.get('/attendance/break-types');

      // Parse response
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final breakTypesList = data['data'] as List<dynamic>? ?? [];

          // If API returns empty list, use defaults
          if (breakTypesList.isEmpty) {
            final defaultBreakTypes = _getDefaultBreakTypes();
            // Cache the defaults
            _cache.set<List<BreakType>>(
              _cacheKey,
              defaultBreakTypes,
              ttl: _cacheTtl,
              toJson: (breakTypes) => {
                'timestamp': DateTime.now().toIso8601String(),
                'data': breakTypes.map((bt) => bt.toJson()).toList(),
              },
            );
            return defaultBreakTypes;
          }

          final breakTypes = breakTypesList
              .map((item) => BreakType.fromJson(item as Map<String, dynamic>))
              .toList();

          // Update cache with timestamp
          _cache.set<List<BreakType>>(
            _cacheKey,
            breakTypes,
            ttl: _cacheTtl,
            toJson: (breakTypes) => {
              'timestamp': DateTime.now().toIso8601String(),
              'data': breakTypes.map((bt) => bt.toJson()).toList(),
            },
          );

          return breakTypes;
        }
      }

      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      // Network error - check if we have stale cache
      final staleCache = _cache.getStale<List<BreakType>>(
        _cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => BreakType.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      // If offline or network error, return stale cache if available
      if (_isOfflineError(e) && staleCache != null) {
        return staleCache;
      }

      // If no stale cache, return and cache default break types
      if (staleCache == null) {
        final defaultBreakTypes = _getDefaultBreakTypes();
        // Cache the defaults so they persist
        _cache.set<List<BreakType>>(
          _cacheKey,
          defaultBreakTypes,
          ttl: _cacheTtl,
          toJson: (breakTypes) => {
            'timestamp': DateTime.now().toIso8601String(),
            'data': breakTypes.map((bt) => bt.toJson()).toList(),
          },
        );
        return defaultBreakTypes;
      }

      // Re-throw if it's not an offline scenario
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to fetch break types: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      // Other errors - try stale cache
      final staleCache = _cache.getStale<List<BreakType>>(
        _cacheKey,
        fromJson: (json) {
          final list = json['data'] as List<dynamic>;
          return list
              .map((item) => BreakType.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

      if (staleCache != null) {
        return staleCache;
      }

      // If no cache available, return and cache default break types
      final defaultBreakTypes = _getDefaultBreakTypes();
      // Cache the defaults so they persist
      _cache.set<List<BreakType>>(
        _cacheKey,
        defaultBreakTypes,
        ttl: _cacheTtl,
        toJson: (breakTypes) => {
          'timestamp': DateTime.now().toIso8601String(),
          'data': breakTypes.map((bt) => bt.toJson()).toList(),
        },
      );
      return defaultBreakTypes;
    }
  }

  /// Get default break types when API is unavailable
  List<BreakType> _getDefaultBreakTypes() {
    return const [
      BreakType(
        name: 'lunch',
        displayName: 'Lunch Break',
        description: 'Standard lunch break for employees',
        minDurationMinutes: 30,
        maxDurationMinutes: 60,
        icon: 'restaurant',
        color: '#2E7D32',
        isActive: true,
      ),
      BreakType(
        name: 'personal',
        displayName: 'Personal Break',
        description: 'Personal time break for employees',
        minDurationMinutes: 5,
        maxDurationMinutes: 30,
        icon: 'person',
        color: '#7B1FA2',
        isActive: true,
      ),
      BreakType(
        name: 'coffee_break',
        displayName: 'Coffee Break',
        description: 'Short coffee break for employees',
        minDurationMinutes: 5,
        maxDurationMinutes: 15,
        icon: 'coffee',
        color: '#ED6C02',
        isActive: true,
      ),
    ];
  }

  @override
  Future<BreakType> createBreakType(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('/admin/break-types', data: data);
      
      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['success'] == true && responseData['data'] != null) {
          final breakType = BreakType.fromJson(responseData['data'] as Map<String, dynamic>);
          
          // Invalidate cache to force refresh
          _cache.remove(_cacheKey);
          
          return breakType;
        }
      }
      
      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to create break type: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<BreakType> updateBreakType(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put('/admin/break-types/$id', data: data);
      
      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['success'] == true && responseData['data'] != null) {
          final breakType = BreakType.fromJson(responseData['data'] as Map<String, dynamic>);
          
          // Invalidate cache to force refresh
          _cache.remove(_cacheKey);
          
          return breakType;
        }
      }
      
      throw ApiException(message: 'Invalid response format');
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to update break type: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteBreakType(String id) async {
    try {
      await _apiClient.delete('/admin/break-types/$id');
      
      // Invalidate cache to force refresh
      _cache.remove(_cacheKey);
    } on DioException catch (e) {
      throw ApiException(
        message: e.error is ApiException
            ? (e.error as ApiException).message
            : 'Failed to delete break type: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Check if error indicates offline state
  bool _isOfflineError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.error is SocketException);
  }
}


