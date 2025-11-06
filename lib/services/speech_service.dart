import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Lightweight wrapper around `speech_to_text` providing an easy start/stop
/// API and a current recognized text state.
class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  String lastRecognized = '';

  /// Initialize the underlying plugin and return whether it's available.
  Future<bool> initialize() async {
    try {
      _available = await _stt.initialize(
        onError: (val) => debugPrint('Speech error: $val'),
        onStatus: (val) => debugPrint('Speech status: $val'),
        debugLogging: true,
      );
      debugPrint('Speech service available: $_available');
      return _available;
    } catch (e) {
      debugPrint('Speech init exception: $e');
      _available = false;
      return false;
    }
  }

  bool get isAvailable => _available;

  String _normalizeLocale(String requested) => requested.replaceAll('-', '_');

  Future<void> startListening(
      void Function(String text, bool isFinal) onResult, {
        String localeId = 'kn_IN',
        bool partialResults = true,
      }) async {
    if (!_available) {
      final ok = await initialize();
      if (!ok) return;
    }

    final chosenLocale = _normalizeLocale(localeId);
    debugPrint('Starting listening with locale: $chosenLocale');

    try {
      await _stt.listen(
        onResult: (result) {
          debugPrint('Speech result: "${result.recognizedWords}" final=${result.finalResult}');
          lastRecognized = result.recognizedWords;
          try {
            onResult(result.recognizedWords, result.finalResult);
          } catch (e) {
            debugPrint('onResult callback error: $e');
          }
        },
        localeId: chosenLocale,
        listenOptions: stt.SpeechListenOptions(partialResults: partialResults),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onSoundLevelChange: (level) {
          debugPrint('Sound level: $level');
        },
      );
    } catch (e) {
      debugPrint('Listen error: $e');
    }
  }

  /// Start listening with automatic language detection. Prefer Kannada but
  /// fall back to automatic detection if the preferred locale fails.
  Future<void> startListeningWithMixedLanguage(
      void Function(String text, bool isFinal) onResult,
      ) async {
    if (!_available) {
      final ok = await initialize();
      if (!ok) return;
    }

    // First try Kannada (kn-IN) to bias recognition towards Kannada.
    try {
      final chosenLocale = _normalizeLocale('kn-IN');
      debugPrint('Starting mixed-language listening (preferred): $chosenLocale');
      await _stt.listen(
        onResult: (result) {
          debugPrint('Mixed language result: "${result.recognizedWords}" final=${result.finalResult}');
          lastRecognized = result.recognizedWords;
          try {
            onResult(result.recognizedWords, result.finalResult);
          } catch (e) {
            debugPrint('onResult callback error: $e');
          }
        },
        localeId: chosenLocale,
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onSoundLevelChange: (level) => debugPrint('Sound level: $level'),
      );
    } catch (e) {
      // If specifying Kannada fails (some platforms can throw), fall back to
      // automatic language detection (omit localeId).
      debugPrint('Kannada listen failed, trying auto-detect: $e');
      try {
        await _stt.listen(
          onResult: (result) {
            debugPrint('Auto-detect result: "${result.recognizedWords}" final=${result.finalResult}');
            lastRecognized = result.recognizedWords;
            try {
              onResult(result.recognizedWords, result.finalResult);
            } catch (e) {
              debugPrint('onResult callback error: $e');
            }
          },
          listenOptions: stt.SpeechListenOptions(partialResults: true),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          onSoundLevelChange: (level) => debugPrint('Sound level: $level'),
        );
      } catch (e2) {
        debugPrint('Auto-detect listen also failed: $e2');
      }
    }
  }

  /// Start listening with retries. If recognition yields no final result within
  /// the timeout, this helper will retry up to [retries] times. Useful for
  /// flaky environments or when microphone permissions may be delayed.
  Future<void> startListeningWithRetry(
    void Function(String text, bool isFinal) onResult, {
    String localeId = 'kn_IN',
    int retries = 2,
    Duration attemptTimeout = const Duration(seconds: 12),
    bool partialResults = true,
    void Function()? onFailure,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      var gotFinal = false;
      // Start listening and set a timer to treat lack of final results as failure.
      try {
        await startListening((text, isFinal) {
          try {
            onResult(text, isFinal);
            if (isFinal) gotFinal = true;
          } catch (e) {
            debugPrint('onResult wrapper error: $e');
          }
        }, localeId: localeId, partialResults: partialResults);

        // Wait up to attemptTimeout for a final result.
        await Future.delayed(attemptTimeout, () => null);
      } catch (e) {
        debugPrint('startListeningWithRetry listen error: $e');
      }

      if (gotFinal) return; // success

      // didn't get a final result — stop and retry
      try {
        await stop();
      } catch (_) {}

      if (attempt < retries) {
        debugPrint('Retrying speech listen (attempt ${attempt + 1} of $retries)');
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      } else {
        debugPrint('All speech listen attempts failed');
        if (onFailure != null) onFailure();
        return;
      }
    }
  }

  /// Start listening with retries and progressive timeouts. This is an
  /// enhanced helper that increases timeout per attempt and surfaces failures
  /// via the optional onFailure callback.
  Future<void> startListeningWithEnhancedRetry(
    void Function(String text, bool isFinal) onResult, {
    String localeId = 'kn_IN',
    int maxRetries = 3,
    Duration initialTimeout = const Duration(seconds: 8),
    bool partialResults = true,
    void Function()? onFailure,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      var gotFinal = false;
      try {
        final timeout = initialTimeout + Duration(seconds: attempt * 2);
        debugPrint('Enhanced listen attempt ${attempt + 1} timeout: ${timeout.inSeconds}s');

        await startListening((text, isFinal) {
          try {
            onResult(text, isFinal);
            if (isFinal) gotFinal = true;
          } catch (e) {
            debugPrint('onResult handler error in enhanced retry: $e');
          }
        }, localeId: localeId, partialResults: partialResults);

        // Wait up to timeout for a final result to be set by the callback.
        final waitUntil = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(waitUntil) && !gotFinal) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint('Speech attempt ${attempt + 1} failed: $e');
      }

      if (gotFinal) return; // success

      // stop and retry if allowed
      try {
        await stop();
      } catch (_) {}

      if (attempt < maxRetries - 1) {
        debugPrint('Retrying speech listen (enhanced) attempt ${attempt + 2} of $maxRetries');
        await Future.delayed(Duration(milliseconds: 400 + 100 * attempt));
        continue;
      } else {
        debugPrint('All enhanced speech listen attempts failed');
        if (onFailure != null) onFailure();
        return;
      }
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (e) {
      debugPrint('Cancel error: $e');
    }
  }

// Note: locale enumeration helpers were removed because the real plugin
// provides different APIs for locales; keep the wrapper minimal.
}

final speechService = SpeechService();