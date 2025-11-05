import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/mcp_knowledge_base.dart';

class AIService {
  // Prefer constructor injection; fallback to --dart-define OPENAI_API_KEY
  final String _openAIKey;
  static const String _baseURL = 'https://api.openai.com/v1';

  AIService({String? apiKey}) : _openAIKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

  /// Get response with proper fallback: Q&A pairs first, then categories, then external AI
  Future<String> getResponse(String userMessage, String context) async {
    debugPrint('AI Service - User query: $userMessage');

    // 1) Try QA pairs and category search (with fuzzy matching)
    final jsonResponse = _searchKnowledgeBase(userMessage);
    if (jsonResponse != null) {
      return jsonResponse;
    }

    // 2) No local match, use OpenAI if key available
    if (_openAIKey.isNotEmpty) {
      try {
        return await _getOpenAIResponse(userMessage, context);
      } catch (e) {
        debugPrint('OpenAI error: $e');
        return _getFallbackResponse();
      }
    }

    // 3) Final fallback
    return _getFallbackResponse();
  }

  String? _searchKnowledgeBase(String query) {
    final normalizedQuery = query.toLowerCase().trim();

    // Search through QA pairs
    for (final qa in knowledgeBase) {
      final question = qa['question'].toString().toLowerCase();
      if (_fuzzyMatch(normalizedQuery, question)) {
        return qa['answer'];
      }
    }

    return null;
  }

  bool _fuzzyMatch(String input, String target) {
    // Very basic fuzzy matching - could be improved with proper fuzzy search algorithm
    final inputWords = input.split(' ');
    final targetWords = target.split(' ');

    var matches = 0;
    for (final word in inputWords) {
      if (word.length > 2 && targetWords.any((t) => t.contains(word))) {
        matches++;
      }
    }

    return matches >= (inputWords.length ~/ 2);
  }

  Future<String> _getOpenAIResponse(String message, String context) async {
    final url = Uri.parse('$_baseURL/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAIKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a maternal health assistant. Respond in Kannada language. Context: $context'
          },
          {
            'role': 'user',
            'content': message
          }
        ],
        'temperature': 0.7,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get AI response: ${response.statusCode}');
    }
  }

  String _getFallbackResponse() {
    return 'ಕ್ಷಮಿಸಿ, ನನಗೆ ಅರ್ಥವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಂದು ರೀತಿಯಲ್ಲಿ ಕೇಳಿ.';
  }
}

final aiService = AIService();
