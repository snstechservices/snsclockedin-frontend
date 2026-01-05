import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration wrapper for accessing .env variables
class Env {
  Env._();

  /// Application environment (development, staging, production)
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';

  /// Base URL for API requests
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

  /// Check if running in development mode
  static bool get isDevelopment => appEnv == 'development';

  /// Check if running in staging mode
  static bool get isStaging => appEnv == 'staging';

  /// Check if running in production mode
  static bool get isProduction => appEnv == 'production';
}
