// lib/services/name_extractor.dart

import 'package:flutter/foundation.dart';

class NameExtractor {
  /// Enhanced name extraction that preserves English words
  String extractName(String text) {
    if (text.isEmpty) return '';

    final lowerText = text.toLowerCase();
    debugPrint('Name extraction - Original text: $text');

    // First try common patterns in Kannada and English
    final patterns = [
      RegExp(r'(?:ನನ್ನ ಹೆಸರು|my name is|i am|ನಾನು) ([^\n.,!?]+)', caseSensitive: false),
      RegExp(r'([^\n.,!?]+) (?:ಎಂದು ಕರೆಯುತ್ತಾರೆ|ಎಂಬುದು ನನ್ನ ಹೆಸರು)', caseSensitive: false),
      RegExp(r'call me ([^\n.,!?]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final extracted = match.group(1)?.trim();
        if (extracted != null && extracted.isNotEmpty) {
          // Get the original case from the matched position
          final start = match.start;
          final end = match.end;
          final originalCase = text.substring(start, end).trim();
          debugPrint('Name extracted via pattern: $originalCase');
          return originalCase;
        }
      }
    }

    // If no patterns match, try splitting and cleaning
    final words = text.split(RegExp(r'[\s,!?]+'));
    String? name;

    // Look for words that could be names (avoid common words/noise)
    for (final word in words) {
      if (word.length > 1 && !_isCommonWord(word)) {
        name = word;
        break;
      }
    }

    debugPrint('Name extracted via fallback: $name');
    return name ?? '';
  }

  /// Enhanced name extraction with context awareness
  String extractNameFromContext(String text, String context) {
    String name = extractName(text);

    if (name.isEmpty && context == 'username') {
      // For username context, be more lenient
      final words = text.split(RegExp(r'[\s,!?]+'));
      for (final word in words) {
        if (word.length > 1) {
          name = word;
          break;
        }
      }
    }

    return name;
  }

  bool _isCommonWord(String word) {
    final lowerWord = word.toLowerCase();
    return [
      // Kannada common words
      'ನನ್ನ',
      'ಹೆಸರು',
      'ಎಂದು',
      'ನಾನು',
      'ಮತ್ತು',
      'ಆದರೆ',
      'ಆಗಿದೆ',
      'ಇದೆ',
      // English common words
      'my',
      'name',
      'is',
      'please',
      'call',
      'me',
      'the',
      'and',
      'but',
      'or',
    ].contains(lowerWord);
  }
}

final nameExtractor = NameExtractor();
