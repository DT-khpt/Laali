// lib/utils/mock_llm.dart

/// Enhanced Mock LLM for development and testing
class MockLLM {
  final Map<String, List<String>> _responseTemplates;
  final bool _simulateLatency;
  final Duration _latencyDuration;

  // Response history for context
  final List<Map<String, dynamic>> _conversationHistory = [];

  MockLLM({
    bool simulateLatency = true,
    Duration latencyDuration = const Duration(milliseconds: 200),
  }) :
        _simulateLatency = simulateLatency,
        _latencyDuration = latencyDuration,
        _responseTemplates = _initializeTemplates();

  static Map<String, List<String>> _initializeTemplates() {
    return {
      'greeting': [
        'ನಮಸ್ಕಾರ! ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕಕ್ಕೆ ಸ್ವಾಗತ. ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ?',
        'ಹಲೋ! ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆ ಮತ್ತು ಶಿಶು ಆರೋಗ್ಯದ ಬಗ್ಗೆ ಸಹಾಯ ಮಾಡಲು ಸಿದ್ಧನಾಗಿದ್ದೇನೆ.',
        'ನಮಸ್ಕಾರ! ನಿಮ್ಮ ಪ್ರಶ್ನೆಗಳಿಗೆ ಉತ್ತರಿಸಲು ಸಂತೋಷ.'
      ],
      'pregnancy': [
        'ಗರ್ಭಾವಸ್ಥೆಯಲ್ಲಿ ಸಮತೋಲಿತ ಆಹಾರ ಮತ್ತು ನಿಯಮಿತ ವ್ಯಾಯಾಮ ಮುಖ್ಯ. ದಿನಕ್ಕೆ 400 ಮೈಕ್ರೋಗ್ರಾಂ ಫೋಲಿಕ್ ಆಮ್ಲ ತೆಗೆದುಕೊಳ್ಳಿ.',
        'ಗರ್ಭಿಣಿಯರು ದಿನಕ್ಕೆ 30 ನಿಮಿಷ ನಡೆಯಬಹುದು. ಭಾರೀ ವ್ಯಾಯಾಮ ತಪ್ಪಿಸಿ.',
        'ಗರ್ಭಾವಸ್ಥೆಯ ಮೊದಲ 3 ತಿಂಗಳು: ಹಸಿರು ಕಾಯಿಪಲ್ಯ, ಹಣ್ಣುಗಳು, ಡೇರಿ ಉತ್ಪನ್ನಗಳು ತಿನ್ನಿರಿ.'
      ],
      'nutrition': [
        'ಗರ್ಭಾವಸ್ಥೆಯಲ್ಲಿ ಪ್ರೋಟೀನ್, ಕ್ಯಾಲ್ಸಿಯಂ, ಕಬ್ಬಿಣ ಮತ್ತು ಫೋಲಿಕ್ ಆಮ್ಲ ಅಗತ್ಯ. ಹಾಲು, ಮೊಸರು, ಕೋಳಿಮೊಟ್ಟೆ, ಹಸಿರು ಕಾಯಿಪಲ್ಯ ತಿನ್ನಿರಿ.',
        'ಕಬ್ಬಿಣದ ಅಗತ್ಯ ಹೆಚ್ಚಾಗುತ್ತದೆ. ಕೋಳಿಮೊಟ್ಟೆ, ಹಸಿರು ಕಾಯಿಪಲ್ಯ, ಲೆಗ್ಯೂಮ್ಸ್ ತಿನ್ನಿರಿ.',
        'ಕ್ಯಾಲ್ಸಿಯಂಗೆ ಹಾಲು, ಮೊಸರು, ತಾಜಾ ಹಣ್ಣುಗಳು ತಿನ್ನಿರಿ.'
      ],
      'emergency': [
        'ಶಿಶುವಿನ ಜ್ವರ 100.4°F ಮೇಲೆ ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ. ನೀರು ಸೇವನೆ ಖಚಿತಪಡಿಸಿ.',
        'ಶಿಶುವಿಗೆ ಅತಿಸಾರವಾದರೆ ORS ಕೊಡಿ. ಹಾಲು ಮುಂದುವರಿಸಿ.',
        'ಶ್ವಾಸ ತೆಗೆದುಕೊಳ್ಳಲು ಕಷ್ಟ, ನೀಲಿ ಬಣ್ಣದ ತುಟಿ ಇದ್ದರೆ ತಕ್ಷಣ ವೈದ್ಯಕೀಯ ಸಹಾಯ ಪಡೆಯಿರಿ.'
      ],
      'vaccination': [
        'ಟೀಕೆಗಳು: ಜನ್ಮದಂದು - ಬಿಸಿಜಿ, ಹೆಪಟೈಟಿಸ್ ಬಿ. 6 ವಾರಗಳು - ಡಿಪಿಟಿ, ಹಿಬ್, ಐಪಿವಿ.',
        'ಶಿಶುವಿನ ಟೀಕೆಗಳು: 10 ವಾರಗಳು - ಡಿಪಿಟಿ, ಹಿಬ್, ಐಪಿವಿ. 9 ತಿಂಗಳು - ಎಂಆರ್.',
        'ಟೀಕೆಗಳು ಮುಖ್ಯ. ನಿಮ್ಮ ಶಿಶುವಿಗೆ ಎಲ್ಲಾ ಟೀಕೆಗಳನ್ನು ಸರಿಯಾದ ಸಮಯದಲ್ಲಿ ಕೊಡಿಸಿ.'
      ],
      'unknown': [
        'ಕ್ಷಮಿಸಿ, ಈ ಪ್ರಶ್ನೆಗೆ ನನ್ನ ಜ್ಞಾನದಲ್ಲಿ ಉತ್ತರವಿಲ್ಲ. ದಯವಿಟ್ಟು ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ.',
        'ಈ ವಿಷಯದ ಬಗ್ಗೆ ನಾನು ಖಚಿತವಾಗಿ ಹೇಳಲು ಸಾಧ್ಯವಿಲ್ಲ. ಆರೋಗ್ಯ ವೃತ್ತಿಪರರ ಸಲಹೆ ಪಡೆಯಿರಿ.',
        'ನನ್ನ ಜ್ಞಾನದಲ್ಲಿ ಈ ಪ್ರಶ್ನೆಗೆ ಉತ್ತರವಿಲ್ಲ. ದಯವಿಟ್ಟು ಇತರ ಪ್ರಶ್ನೆ ಕೇಳಿ.'
      ]
    };
  }

  /// Enhanced response generation with context awareness
  Future<String> generate(String prompt) async {
    if (_simulateLatency) {
      await Future.delayed(_latencyDuration);
    }

    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'content': prompt,
      'timestamp': DateTime.now(),
    });

    // Analyze prompt for intent
    final intent = _analyzeIntent(prompt);
    final context = _getConversationContext();

    // Generate response based on intent and context
    final response = _generateResponse(intent, prompt, context);

    // Add response to history
    _conversationHistory.add({
      'role': 'assistant',
      'content': response,
      'timestamp': DateTime.now(),
    });

    // Keep history manageable
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 10);
    }

    return response;
  }

  /// Analyze user intent from prompt
  String _analyzeIntent(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('hello') || lower.contains('hi') || lower.contains('ನಮಸ್ಕಾರ')) {
      return 'greeting';
    } else if (lower.contains('pregnancy') || lower.contains('ಗರ್ಭ') || lower.contains('ಗರ್ಭಾವಸ್ಥೆ')) {
      return 'pregnancy';
    } else if (lower.contains('food') || lower.contains('nutrition') || lower.contains('ಆಹಾರ') || lower.contains('ತಿನ್ನ')) {
      return 'nutrition';
    } else if (lower.contains('emergency') || lower.contains('ಜ್ವರ') || lower.contains('ಅತಿಸಾರ') || lower.contains('ತುರ್ತು')) {
      return 'emergency';
    } else if (lower.contains('vaccine') || lower.contains('ಟೀಕೆ') || lower.contains('injection')) {
      return 'vaccination';
    } else if (lower.contains('age') || lower.contains('ಗರ್ಭಾವಸ್ಥೆಯ ವಯಸ್ಸು') || lower.contains('weeks')) {
      return 'gestational_age';
    } else if (lower.contains('kannada') || lower.contains('ಕನ್ನಡ')) {
      return 'kannada';
    }

    return 'unknown';
  }

  /// Get conversation context for more coherent responses
  Map<String, dynamic> _getConversationContext() {
    if (_conversationHistory.isEmpty) return {};

    final lastFew = _conversationHistory.reversed.take(3).toList().reversed.toList();
    final topics = <String>[];

    for (final message in lastFew) {
      if (message['role'] == 'user') {
        topics.add(_analyzeIntent(message['content'] as String));
      }
    }

    return {
      'recent_topics': topics,
      'conversation_length': _conversationHistory.length,
      'last_user_message': _conversationHistory.lastWhere(
            (msg) => msg['role'] == 'user',
        orElse: () => {},
      )['content'],
    };
  }

  /// Generate response based on intent and context
  String _generateResponse(String intent, String prompt, Map<String, dynamic> context) {
    final templates = _responseTemplates[intent] ?? _responseTemplates['unknown']!;
    final randomIndex = DateTime.now().millisecond % templates.length;
    var response = templates[randomIndex];

    // Add context-aware enhancements
    response = _enhanceWithContext(response, context, prompt);

    return response;
  }

  /// Enhance response with conversation context
  String _enhanceWithContext(String response, Map<String, dynamic> context, String prompt) {
    final recentTopics = (context['recent_topics'] as List<dynamic>?)?.cast<String>() ?? [];

    // If user is asking similar questions, provide more detailed response
    if (recentTopics.length >= 2 && recentTopics.last == recentTopics[recentTopics.length - 2]) {
      response += '\n\nಈ ವಿಷಯದ ಬಗ್ಗೆ ಇನ್ನಷ್ಟು ಮಾಹಿತಿ ಬೇಕಾದರೆ, ದಯವಿಟ್ಟು ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ.';
    }

    // Add safety disclaimer for medical topics
    if (_isMedicalTopic(prompt)) {
      response += '\n\n🚜 ಗಮನಿಸಿ: ಇದು ಸಾಮಾನ್ಯ ಸಲಹೆ ಮಾತ್ರ. ವೈದ್ಯಕೀಯ ಸಲಹೆಗೆ ನಿಮ್ಮ ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ.';
    }

    return response;
  }

  bool _isMedicalTopic(String prompt) {
    final medicalKeywords = [
      'medicine', 'treatment', 'doctor', 'hospital', 'fever', 'pain',
      'ಔಷಧ', 'ಚಿಕಿತ್ಸೆ', 'ವೈದ್ಯ', 'ಆಸ್ಪತ್ರೆ', 'ಜ್ವರ', 'ನೋವು'
    ];

    final lower = prompt.toLowerCase();
    return medicalKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Get conversation history for debugging
  List<Map<String, dynamic>> getConversationHistory() {
    return List.from(_conversationHistory);
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Generate multiple response options (for testing)
  Future<List<String>> generateOptions(String prompt, int count) async {
    final options = <String>[];
    for (int i = 0; i < count; i++) {
      options.add(await generate('$prompt [option ${i + 1}]'));
    }
    return options;
  }

  /// Health check for the mock service
  Future<Map<String, dynamic>> healthCheck() async {
    return {
      'status': 'healthy',
      'templates_loaded': _responseTemplates.length,
      'conversation_history_length': _conversationHistory.length,
      'simulate_latency': _simulateLatency,
      'latency_duration': _latencyDuration.toString(),
    };
  }
}

// Factory function with configuration
MockLLM createMockLLM({
  bool simulateLatency = true,
  Duration latencyDuration = const Duration(milliseconds: 200),
}) {
  return MockLLM(
    simulateLatency: simulateLatency,
    latencyDuration: latencyDuration,
  );
}

// Global instance for convenience
final mockLLM = createMockLLM();