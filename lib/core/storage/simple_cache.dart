import 'dart:convert';

/// Simple in-memory cache service for v2 features
/// Matches legacy caching behavior: cache-first with TTL
class SimpleCache {
  SimpleCache._internal();
  static final SimpleCache _instance = SimpleCache._internal();
  factory SimpleCache() => _instance;

  final Map<String, _CacheEntry> _cache = {};

  /// Get cached data if exists and not expired
  /// Returns null if cache miss or expired
  T? get<T>(String key, {required T Function(Map<String, dynamic>) fromJson}) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    try {
      final data = jsonDecode(entry.dataJson) as Map<String, dynamic>;
      return fromJson(data);
    } catch (e) {
      // Invalid cache data, remove it
      _cache.remove(key);
      return null;
    }
  }

  /// Get cached data even if expired (for offline fallback)
  T? getStale<T>(String key, {required T Function(Map<String, dynamic>) fromJson}) {
    final entry = _cache[key];
    if (entry == null) return null;

    try {
      final data = jsonDecode(entry.dataJson) as Map<String, dynamic>;
      return fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Store data in cache with TTL
  void set<T>(
    String key,
    T data, {
    required Duration ttl,
    required Map<String, dynamic> Function(T) toJson,
  }) {
    try {
      final dataJson = jsonEncode(toJson(data));
      _cache[key] = _CacheEntry(
        dataJson: dataJson,
        savedAt: DateTime.now(),
        ttl: ttl,
      );
    } catch (e) {
      // Failed to serialize, don't cache
    }
  }

  /// Remove cache entry
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
  }

  /// Check if cache entry exists (even if expired)
  bool exists(String key) {
    return _cache.containsKey(key);
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.dataJson,
    required this.savedAt,
    required this.ttl,
  });

  final String dataJson;
  final DateTime savedAt;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(savedAt) > ttl;
}

