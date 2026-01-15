import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test helper to initialize environment for tests
Future<void> setupTestEnvironment() async {
  // Initialize dotenv with default values if not already loaded
  if (!dotenv.isInitialized) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // If .env doesn't exist, create a minimal dotenv instance
      // We'll use a workaround by loading an empty string
      await dotenv.load();
    }
  }
  
  // Set default values if not present
  dotenv.env['APP_ENV'] ??= 'test';
  dotenv.env['API_BASE_URL'] ??= 'http://localhost:3000';
}
