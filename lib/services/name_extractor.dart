// lib/services/name_extractor.dart
import 'package:flutter/foundation.dart';

/// Enhanced Name Extractor with better pattern recognition and validation
class NameExtractor {
  static final Map<String, List<String>> _namePatterns = {
    'kannada': [
      'ನನ್ನ ಹೆಸರು',
      'ನಾನು',
      'ಹೆಸರು',
      'ನನ್ನ ಪೆಸರು',
      'ನಾನ್',
      'ನನ್ನನ್ನು',
      'ನನ್ನ ಪೇರ್',
      'ನನ್ನ ನೇಮ್'
    ],
    'english': [
      'my name is',
      'my name',
      'name is',
      'i am',
      'call me',
      'this is',
      'it is',
      'you can call me'
    ]
  };

  static final Map<String, List<String>> _suffixes = {
    'kannada': ['ಅವರು', 'ಆಗಿದೆ', 'ಎಂದು', 'ಎನ್ನುತ್ತಾರೆ', 'ಎನ್ನುವರು', 'ಎಂಬ'],
    'english': ['is', 'am', 'are', 'was', 'were', 'has', 'have']
  };

  static final Map<String, List<String>> _verbs = {
    'kannada': ['ಹೇಳು', 'ಕೇಳು', 'ತಿಳಿಸು', 'ಕೊಡು', 'ಬನ್ನಿ', 'ಮಾಡಿ'],
    'english': ['please', 'kindly', 'tell', 'say', 'speak']
  };

  /// Enhanced name extraction with multiple strategies
  String extractName(String text) {
    if (text.isEmpty) return '';

    final lowerText = text.toLowerCase();
    debugPrint('🔍 Name extraction - Original text: $text');

    // Multiple extraction strategies
    final strategies = [
      _extractWithPatterns(text, lowerText),
      _extractWithPosition(text, lowerText),
      _extractWithLanguageDetection(text, lowerText),
    ];

    // Return the best result
    for (final result in strategies) {
      if (result.isNotEmpty && _validateName(result)) {
        debugPrint('✅ Name extracted: $result');
        return result;
      }
    }

    debugPrint('❌ No valid name extracted, returning original');
    return text;
  }

  /// Pattern-based extraction
  String _extractWithPatterns(String original, String lowerText) {
    String cleanedText = original;

    // Check all language patterns
    for (final language in _namePatterns.keys) {
      for (final pattern in _namePatterns[language]!) {
        if (lowerText.contains(pattern)) {
          final patternIndex = lowerText.indexOf(pattern);
          cleanedText = original.substring(patternIndex + pattern.length).trim();
          debugPrint('🎯 Pattern match ($language): "$pattern" → "$cleanedText"');
          break;
        }
      }
      if (cleanedText != original) break;
    }

    return _cleanExtractedName(cleanedText, 'pattern');
  }

  /// Position-based extraction (for short inputs)
  String _extractWithPosition(String original, String lowerText) {
    // If text is short and doesn't contain patterns, assume it's just the name
    if (original.length <= 30 && !_containsPatterns(lowerText)) {
      debugPrint('📍 Position-based extraction for short text');
      return _cleanExtractedName(original, 'position');
    }

    return '';
  }

  /// Language-aware extraction
  String _extractWithLanguageDetection(String original, String lowerText) {
    final isKannada = _containsKannada(original);
    final isEnglish = _containsEnglish(original);

    if (isKannada && !isEnglish) {
      // Kannada-only text, extract after common Kannada phrases
      return _extractKannadaName(original, lowerText);
    } else if (isEnglish && !isKannada) {
      // English-only text
      return _extractEnglishName(original, lowerText);
    }

    // Mixed language - use combined approach
    return _extractMixedLanguageName(original, lowerText);
  }

  String _extractKannadaName(String original, String lowerText) {
    final kannadaMarkers = ['ಎಂಬ', 'ಎಂದು', 'ಎನ್ನು'];
    for (final marker in kannadaMarkers) {
      if (original.contains(marker)) {
        final index = original.indexOf(marker);
        return _cleanExtractedName(original.substring(0, index).trim(), 'kannada_marker');
      }
    }
    return '';
  }

  String _extractEnglishName(String original, String lowerText) {
    // English-specific extraction logic
    final englishMarkers = ['called', 'named', 'known as'];
    for (final marker in englishMarkers) {
      if (lowerText.contains(marker)) {
        final index = lowerText.indexOf(marker);
        return _cleanExtractedName(original.substring(index + marker.length).trim(), 'english_marker');
      }
    }
    return '';
  }

  String _extractMixedLanguageName(String original, String lowerText) {
    // For mixed language, be more conservative
    final words = original.split(RegExp(r'\s+'));
    if (words.length <= 3) {
      // Likely just the name
      return _cleanExtractedName(original, 'mixed_short');
    }
    return '';
  }

  /// Enhanced cleaning with validation
  String _cleanExtractedName(String name, String strategy) {
    if (name.isEmpty) return '';

    var cleaned = name;

    // Remove suffixes from all languages
    for (final language in _suffixes.keys) {
      for (final suffix in _suffixes[language]!) {
        if (cleaned.toLowerCase().endsWith(suffix.toLowerCase())) {
          cleaned = cleaned.substring(0, cleaned.length - suffix.length).trim();
          debugPrint('🧹 Removed suffix ($language): "$suffix"');
        }
      }
    }

    // Remove verbs/action words
    for (final language in _verbs.keys) {
      for (final verb in _verbs[language]!) {
        if (cleaned.toLowerCase().endsWith(verb.toLowerCase())) {
          cleaned = cleaned.substring(0, cleaned.length - verb.length).trim();
          debugPrint('🧹 Removed verb ($language): "$verb"');
        }
      }
    }

    // Normalize Unicode characters
    const smartQuotes = ['\u201C', '\u201D', '\u2018', '\u2019', '\u201E', '\u201F'];
    for (final quote in smartQuotes) {
      cleaned = cleaned.replaceAll(RegExp(quote), '');
    }

    // Remove punctuation but preserve word characters and Kannada range
    cleaned = cleaned.replaceAll(RegExp(r"[^\w\s\u0C80-\u0CFF]"), ' ').trim();

    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    debugPrint('✨ Cleaned name ($strategy): "$cleaned"');
    return cleaned;
  }

  /// Enhanced context-aware extraction
  String extractNameFromContext(String text, String context) {
    String name = extractName(text);

    // Context-specific cleaning
    switch (context) {
      case 'username':
        name = _cleanForUsername(name);
        break;
      case 'medical':
        name = _cleanForMedicalContext(name);
        break;
      case 'formal':
        name = _cleanForFormalContext(name);
        break;
    }

    return name;
  }

  String _cleanForUsername(String name) {
    // Remove titles and honorifics
    final titles = ['ಶ್ರೀ', 'ಶ್ರೀಮತಿ', 'ಡಾ', 'ಡಾಕ್ಟರ್', 'ಮಿಸ್ಟರ್', 'ಮಿಸೆಸ್', 'ಮಿಸ'];
    for (final title in titles) {
      if (name.startsWith(title)) {
        name = name.substring(title.length).trim();
      }
    }

    // Ensure reasonable length
    if (name.length > 50) {
      name = name.substring(0, 50).trim();
    }

    return name;
  }

  String _cleanForMedicalContext(String name) {
    // Medical context might need different cleaning
    // Remove common medical terms that might be mistaken for names
    final medicalTerms = ['ರೋಗಿ', 'ಪೇಶಂಟ್', 'ವಯೋಜನ', 'ಮಹಿಳೆ'];
    for (final term in medicalTerms) {
      name = name.replaceAll(term, '').trim();
    }
    return name;
  }

  String _cleanForFormalContext(String name) {
    // Preserve formal structure
    return name;
  }

  /// Validation methods
  bool _validateName(String name) {
    if (name.isEmpty) return false;

    // Check length
    if (name.length < 2 || name.length > 50) return false;

    // Check character composition
    final validChars = RegExp(r'^[\w\s\u0C80-\u0CFF]+$');
    if (!validChars.hasMatch(name)) return false;

    // Check for common invalid patterns
    final invalidPatterns = [
      RegExp(r'^\d+$'), // Only numbers
      RegExp(r'^[^\w\u0C80-\u0CFF]+$'), // No valid characters
    ];

    for (final pattern in invalidPatterns) {
      if (pattern.hasMatch(name)) return false;
    }

    return true;
  }

  bool _containsPatterns(String text) {
    for (final patterns in _namePatterns.values) {
      for (final pattern in patterns) {
        if (text.contains(pattern)) return true;
      }
    }
    return false;
  }

  bool _containsKannada(String text) {
    return RegExp(r'[\u0C80-\u0CFF]').hasMatch(text);
  }

  bool _containsEnglish(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  /// Utility method to get extraction statistics
  Map<String, dynamic> getExtractionStats() {
    return {
      'patterns': {
        'kannada': _namePatterns['kannada']!.length,
        'english': _namePatterns['english']!.length,
      },
      'suffixes': {
        'kannada': _suffixes['kannada']!.length,
        'english': _suffixes['english']!.length,
      },
      'verbs': {
        'kannada': _verbs['kannada']!.length,
        'english': _verbs['english']!.length,
      }
    };
  }
}

final nameExtractor = NameExtractor();