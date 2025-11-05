import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
    return _isInitialized;
  }

  Future<void> startListening(void Function(String text, bool isFinal) onResult, {String localeId = 'kn-IN'}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize speech recognition');
      }
    }

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        onResult(text, result.finalResult);
      },
      localeId: localeId,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> startListeningWithMixedLanguage(
    void Function(String text, bool isFinal) onResult,
  ) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize speech recognition');
      }
    }

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        onResult(text, result.finalResult);
      },
      localeId: 'kn-IN',
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  void cancel() {
    _speech.cancel();
  }

  bool get isListening => _speech.isListening;
}

final speechService = SpeechService();
