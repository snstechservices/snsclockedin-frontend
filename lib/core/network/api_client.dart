import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sns_clocked_in/core/config/env.dart';

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

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // TODO(dev): Add correlation ID header
          // options.headers['X-Correlation-ID'] = uuid.v4();

          // TODO(dev): Add auth token in Step 2
          // final token = getStoredToken();
          // if (token != null) {
          //   options.headers['Authorization'] = 'Bearer $token';
          // }

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

          // TODO(dev): Add global error handling
          // - Token expiry -> redirect to login
          // - Network errors -> show retry dialog
          // - Server errors -> show error message

          return handler.next(error);
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
