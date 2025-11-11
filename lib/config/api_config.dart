// lib/config/api_config.dart
class ApiConfig {
  static const String geminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // Will be loaded from environment
  );

  // API endpoints
  static const String geminiURL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  // Rate limiting
  static const int maxRequestsPerMinute = 10;
  static const int requestTimeoutSeconds = 30;

  // Cache settings
  static const int cacheDurationMinutes = 60;
}

// Secure API key loader
class SecureConfig {
  static Future<String> loadApiKey() async {
    // In production, use flutter_dotenv or similar
    const key = ApiConfig.geminiKey;
    if (key.isEmpty) {
      throw Exception('API key not configured. Please set GEMINI_API_KEY environment variable.');
    }
    return key;
  }
}