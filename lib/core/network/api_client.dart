import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/config/env.dart';
import 'package:uuid/uuid.dart';

/// API exception wrapper for better error handling
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Singleton API client using Dio for HTTP requests
class ApiClient {
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  static final ApiClient _instance = ApiClient._internal();

  late final Dio _dio;
  String? Function()? _tokenGetter;
  final _uuid = const Uuid();

  Dio get dio => _dio;

  /// Set token provider function
  // ignore: use_setters_to_change_properties
  void setTokenProvider(String? Function()? tokenGetter) {
    _tokenGetter = tokenGetter;
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add correlation ID header
          options.headers['X-Correlation-Id'] = _uuid.v4();

          // Add auth token if available
          final token = _tokenGetter?.call();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Debug logging in development
          if (Env.isDevelopment) {
            debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (Env.isDevelopment) {
            debugPrint(
              'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (Env.isDevelopment) {
            debugPrint(
              'ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path}',
            );
            debugPrint('ERROR MESSAGE: ${error.message}');
          }

          // Wrap DioException into ApiException
          final apiException = ApiException(
            message: error.message ?? 'Unknown error',
            statusCode: error.response?.statusCode,
          );

          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: apiException,
            ),
          );
        },
      ),
    );
  }

  /// Example method - GET request
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  /// Example method - POST request
  Future<Response<dynamic>> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  /// Example method - PUT request
  Future<Response<dynamic>> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  /// Example method - DELETE request
  Future<Response<dynamic>> delete(String path) {
    return _dio.delete(path);
  }
}
