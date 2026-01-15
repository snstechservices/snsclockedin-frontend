import 'dart:io';
import 'package:dio/dio.dart';

/// Helper utility for converting technical errors to user-friendly messages
///
/// Provides consistent error message formatting across the app.
class ErrorMessageHelper {
  ErrorMessageHelper._();

  /// Convert an error to a user-friendly message
  ///
  /// Handles common error types:
  /// - DioException (network errors)
  /// - Generic exceptions
  /// - String errors
  static String toUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }

    if (error is String) {
      // If already a user-friendly message, return as-is
      if (_isUserFriendly(error)) {
        return error;
      }
      // Otherwise, provide generic message
      return 'An unexpected error occurred. Please try again.';
    }

    // Generic exception
    final errorString = error.toString();
    if (_isUserFriendly(errorString)) {
      return errorString;
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Handle DioException errors
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your connection and try again.';

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return 'Your session has expired. Please log in again.';
        } else if (statusCode == 403) {
          return 'You don\'t have permission to perform this action.';
        } else if (statusCode == 404) {
          return 'The requested resource was not found.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        } else if (statusCode != null && statusCode >= 500) {
          return 'Server error. Please try again later.';
        } else if (statusCode != null && statusCode >= 400) {
          // Try to extract message from response
          final message = error.response?.data?['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
          return 'Request failed. Please try again.';
        }
        return 'An error occurred. Please try again.';

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';

      case DioExceptionType.badCertificate:
        return 'Security certificate error. Please contact support.';

      case DioExceptionType.unknown:
      default:
        if (error.error is SocketException || error.message?.contains('SocketException') == true) {
          return 'Unable to connect to the server. Please check your internet connection.';
        }
        return 'An error occurred. Please try again.';
    }
  }

  /// Check if error message is already user-friendly
  static bool _isUserFriendly(String message) {
    // Messages that are already user-friendly (don't contain technical details)
    final userFriendlyPatterns = [
      'Please',
      'try again',
      'check',
      'contact',
      'session',
      'permission',
      'not found',
    ];

    final lowerMessage = message.toLowerCase();
    return userFriendlyPatterns.any((pattern) => lowerMessage.contains(pattern));
  }
}

