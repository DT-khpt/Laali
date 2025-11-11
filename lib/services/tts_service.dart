import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  TtsService() {
    _configureDefaults();
  }

  Future<void> _configureDefaults() async {
    if (_initialized) return;
    try {
      await setLanguage('kn-IN');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.4); // Slow and clear speech
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
      debugPrint('TTS configured with slow, clear Kannada');
    } catch (e) {
      debugPrint('TTS configuration error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_initialized) await _configureDefaults();

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    final r = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(r);
  }

  Future<void> setPitch(double pitch) async {
    final p = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(p);
  }

  Future<void> setLanguage(String language) async {
    try {
      final available = await _tts.getLanguages;
      final requested = language;
      if (available != null) {
        final asStrings = available.map((e) => e.toString()).toList();
        if (asStrings.contains(requested)) {
          await _tts.setLanguage(requested);
          return;
        }
        final alt = requested.replaceAll('-', '_');
        if (asStrings.contains(alt)) {
          await _tts.setLanguage(alt);
          return;
        }
        final prefix = requested.split(RegExp(r'[-_]')).first;
        final firstMatch = asStrings.firstWhere((s) => s.startsWith(prefix), orElse: () => '');
        if (firstMatch.isNotEmpty) {
          await _tts.setLanguage(firstMatch);
          return;
        }
        if (asStrings.isNotEmpty) {
          await _tts.setLanguage(asStrings.first);
          return;
        }
      }
      await _tts.setLanguage('en-US');
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
}

final ttsService = TtsService();