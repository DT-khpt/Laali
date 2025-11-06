import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Simple Text-To-Speech wrapper configured for Kannada (kn-IN) by default.
/// Keeps a single FlutterTts instance and exposes high-level async methods.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  TtsService() {
    // Kick off async configure but don't block constructor callers.
    // This sets stable defaults to avoid very-high pitch and racing that can produce glitches.
    _configureDefaults();
  }

  Future<void> _configureDefaults() async {
    if (_initialized) return;
    try {
      // Attempt to set a sensible default language, but verify it's supported.
      await setLanguage('kn-IN');
      // Use very slow speed by default for clarity on important onboarding prompts
      await setVerySlowSpeed();
      await _tts.setPitch(1.0);    // Normal pitch
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
      debugPrint('TTS configured: language set and defaults applied (very slow)');
    } catch (e) {
      // Don't crash the app if configuration fails; log for debugging.
      debugPrint('TTS configuration error: $e');
    }
  }

  /// Speak [text]. Returns when the speak command has been issued (and, with awaitSpeakCompletion(true), completes after speech ends).
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_initialized) await _configureDefaults();

    try {
      // Stop any currently playing speech to avoid overlapping (common cause of glitches).
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() => _tts.stop();

  /// Release native resources. Call when the app is disposed.
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Optional runtime tuning helpers if you'd like to expose controls to the UI/tests.
  Future<void> setSpeechRate(double rate) async {
    // clamp rate to sensible range 0.0 - 1.0
    final r = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(r);
  }

  Future<void> setPitch(double pitch) async {
    // clamp pitch to 0.5 - 2.0 (platform-dependent)
    final p = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(p);
  }

  /// Set the TTS language. If the requested language isn't available on the
  /// device's TTS engine, try simple alternatives and finally fall back to a
  /// supported language or 'en-US'. This prevents silent failures when a
  /// regional language isn't installed on the device.
  Future<void> setLanguage(String language) async {
    try {
      final available = await _tts.getLanguages; // returns List<dynamic> or null
      final requested = language;
      if (available != null) {
        final asStrings = available.map((e) => e.toString()).toList();
        if (asStrings.contains(requested)) {
          await _tts.setLanguage(requested);
          return;
        }
        // try alternate separator
        final alt = requested.replaceAll('-', '_');
        if (asStrings.contains(alt)) {
          await _tts.setLanguage(alt);
          return;
        }
        // try match by language prefix (e.g., 'kn' matches 'kn-IN')
        final prefix = requested.split(RegExp(r'[-_]')).first;
        final firstMatch = asStrings.firstWhere((s) => s.startsWith(prefix), orElse: () => '');
        if (firstMatch.isNotEmpty) {
          await _tts.setLanguage(firstMatch);
          return;
        }
        // fallback to first supported language
        if (asStrings.isNotEmpty) {
          await _tts.setLanguage(asStrings.first);
          debugPrint('TTS language "$requested" not available; falling back to ${asStrings.first}');
          return;
        }
      }
      // As a final fallback try en-US
      await _tts.setLanguage('en-US');
      debugPrint('TTS language "$language" not found; set to en-US fallback');
    } catch (e) {
      debugPrint('Error setting TTS language ($language): $e');
      try {
        await _tts.setLanguage('en-US');
      } catch (e2) {
        debugPrint('Fallback setLanguage failed: $e2');
      }
    }
  }

  void setStartHandler(VoidCallback? handler) {
    if (handler != null) {
      _tts.setStartHandler(handler);
    } else {
      // FlutterTts requires a non-null callback; register a no-op when clearing.
      _tts.setStartHandler(() {});
    }
  }

  void setCompletionHandler(VoidCallback? handler) {
    if (handler != null) {
      _tts.setCompletionHandler(handler);
    } else {
      _tts.setCompletionHandler(() {});
    }
  }
  void setErrorHandler(void Function(dynamic)? handler) {
    if (handler != null) {
      _tts.setErrorHandler((dynamic err) => handler(err));
    } else {
      _tts.setErrorHandler((dynamic _) {});
    }
  }

  Future<void> setVolume(double volume) => _tts.setVolume(volume);

  /// Set very slow speed for important information
  Future<void> setVerySlowSpeed() async {
    try {
      await _tts.setSpeechRate(0.3); // much slower for clarity
      await _tts.setPitch(0.95);
    } catch (e) {
      debugPrint('Error setting very slow speed: $e');
    }
  }

  /// Slightly slow speed for clearer instructions (used by some pages)
  Future<void> setSlowSpeed() async {
    try {
      await _tts.setSpeechRate(0.40);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('Error setting slow speed: $e');
    }
  }

  /// Normal conversation speed
  Future<void> setNormalSpeed() async {
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('Error setting normal speed: $e');
    }
  }

  /// Faster speed for quick responses
  Future<void> setFastSpeed() async {
    try {
      await _tts.setSpeechRate(0.7);
    } catch (e) {
      debugPrint('Error setting fast speed: $e');
    }
  }

  /// Speak with natural pauses between sentences
  Future<void> speakWithPauses(String text) async {
    if (text.isEmpty) return;
    // Split on sentence enders and keep them similar; remove trailing empties
    final sentences = text.split(RegExp(r'(?<=[.?!])\s+'));
    for (final s in sentences) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) {
        await speak(trimmed);
        // natural pause
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }
  }
}

// Convenient singleton
final ttsService = TtsService();
