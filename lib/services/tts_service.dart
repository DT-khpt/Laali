import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Simple Text-To-Speech wrapper configured for Kannada (kn-IN) by default.
/// Keeps a single FlutterTts instance and exposes high-level async methods.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _disposed = false; // guard to prevent use-after-dispose

  TtsService() {
    // Kick off async configure but don't block constructor callers.
    // This sets stable defaults to avoid very-high pitch and racing that can produce glitches.
    _configureDefaults();
  }

  bool get isInitialized => _initialized && !_disposed;

  Future<void> _configureDefaults() async {
    try {
      await _tts.setLanguage('kn-IN');
      await _tts.setSpeechRate(0.5); // Slower default rate for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      return Future.value(); // Explicit void return
    }
  }

  Future<void> setLanguage(String language) async {
    if (_disposed) return Future.value();
    return _tts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    if (_disposed) return Future.value();
    return _tts.setSpeechRate(rate);
  }

  Future<void> setSlowSpeed() async {
    if (_disposed) return Future.value();
    return _tts.setSpeechRate(0.4); // Very slow and clear for Kannada
  }

  Future<void> setPitch(double pitch) async {
    if (_disposed) return Future.value();
    return _tts.setPitch(pitch);
  }

  Future<void> setStartHandler(VoidCallback handler) async {
    if (_disposed) return Future.value();
    _tts.setStartHandler(handler);
    return Future.value();
  }

  Future<void> setCompletionHandler(VoidCallback handler) async {
    if (_disposed) return Future.value();
    _tts.setCompletionHandler(handler);
    return Future.value();
  }

  Future<void> setErrorHandler(void Function(dynamic) handler) async {
    if (_disposed) return Future.value();
    _tts.setErrorHandler(handler);
    return Future.value();
  }

  Future<void> speak(String text) async {
    if (_disposed || text.isEmpty) return Future.value();

    if (!_initialized) {
      debugPrint('Warning: TTS used before initialization complete');
      await _configureDefaults();
    }

    return _tts.speak(text);
  }

  Future<void> stop() async {
    if (_disposed) return Future.value();
    return _tts.stop();
  }

  void dispose() {
    _disposed = true;
    _tts.stop();
  }
}

final ttsService = TtsService();
