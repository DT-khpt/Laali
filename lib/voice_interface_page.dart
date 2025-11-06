import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/ai_service.dart';

class VoiceInterfacePage extends StatefulWidget {
  const VoiceInterfacePage({super.key});

  @override
  State<VoiceInterfacePage> createState() => _VoiceInterfacePageState();
}

class _VoiceInterfacePageState extends State<VoiceInterfacePage> {
  final ScrollController _scrollController = ScrollController();
  List<Message> messages = [];
  String currentTranscript = '';
  bool isListening = false;
  bool isSpeaking = false;
  bool isLoadingAI = false;
  String? userMode;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserMode();
    _addWelcomeMessage();
    // Auto-start listening after short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !isListening && !isSpeaking && !isLoadingAI) {
        _toggleListening();
      }
    });
    // Speak a welcome message for the voice interface
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        _speakWelcomeMessage();
      });
    });
  }

  // Add a small welcome message in the chat history (non-blocking)
  void _addWelcomeMessage() {
    const welcomeText = 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ — ಸಮಸ್ಯೆಗಳನ್ನು ಹೇಳಿ ಅಥವಾ ಪ್ರಶ್ನೆ ಕೇಳಿ.';
    final msg = Message(role: Role.assistant, content: welcomeText, timestamp: DateTime.now());
    if (mounted) {
      setState(() {
        messages = [...messages, msg];
      });
    }
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSlowSpeed(); // use slower speed for clarity
    await ttsService.setPitch(1.0);

    ttsService.setStartHandler(() {
      setState(() => isSpeaking = true);
    });
    ttsService.setCompletionHandler(() {
      // TTS finished speaking — mark as not speaking and auto-restart mic
      setState(() => isSpeaking = false);
      // Small delay to let audio channel settle, then start listening if idle
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        // Safety checks: only auto-start if assistant just spoke (messages not empty),
        // and no AI processing or manual listening is happening.
        if (!isListening && !isLoadingAI && messages.isNotEmpty) {
          _toggleListening();
        }
      });
    });
    ttsService.setErrorHandler((err) {
      setState(() => isSpeaking = false);
      debugPrint('TTS error: $err');
    });
  }

  /// Ensure the microphone/speech recognizer is ready (requests permissions via initialize).
  Future<bool> _checkMicrophonePermission() async {
    try {
      final available = await speechService.initialize();
      if (!available) {
        await _speak('ದಯವಿಟ್ಟು ಅಪ್ಲಿಕೇಶನ್‌ಗೆ ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿ ನೀಡಿ.');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  Future<void> _loadUserMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userMode = prefs.getString('userMode');
    });
  }

  Future<void> _speak(String text) async {
    try {
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (isSpeaking || isLoadingAI) {
      debugPrint('Cannot listen - busy speaking or processing AI');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _toggleListening();
      });
      return;
    }

    if (!isListening) {
      // Ensure microphone permission and speech service availability
      final ok = await _checkMicrophonePermission();
      if (!ok) return;

      debugPrint('Starting speech recognition...');
      setState(() {
        isListening = true;
        currentTranscript = '';
      });

      try {
        await speechService.startListeningWithRetry((text, isFinal) async {
          debugPrint('Speech result: "$text" final: $isFinal');
          if (!mounted) return;
          setState(() => currentTranscript = text);

          if (isFinal && text.isNotEmpty) {
            debugPrint('Final speech result: $text');
            _onSpeechResult(text);
          } else if (isFinal) {
            debugPrint('Empty final result');
            if (mounted) setState(() => isListening = false);
            // Retry listening after short delay
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && !isListening && !isSpeaking && !isLoadingAI) {
                _toggleListening();
              }
            });
          }
        }, localeId: 'kn-IN', retries: 2, attemptTimeout: const Duration(seconds: 10), onFailure: () async {
          debugPrint('Speech recognition failed after retries');
          if (mounted) setState(() => isListening = false);
          await _speak('ಕ್ಷಮಿಸಿ, ಧ್ವನಿ ಗುರುತಿಸುವಿಕೆ ವಿಫಲವಾಗಿದೆ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.');
        });
      } catch (e) {
        debugPrint('Speech listening error: $e');
        if (mounted) setState(() => isListening = false);
        await _speak('ಕ್ಷಮಿಸಿ, ಧ್ವನಿ ಗುರುತಿಸುವಿಕೆ ಸೇವೆಯಲ್ಲಿ ಸಮಸ್ಯೆ ಉಂಟಾಗಿದೆ.');
      }
    } else {
      debugPrint('Stopping speech recognition...');
      await speechService.stop();
      setState(() => isListening = false);
    }
  }

  void _onSpeechResult(String text) async {
    final userMessage = Message(role: Role.user, content: text, timestamp: DateTime.now());
    setState(() {
      messages = [...messages, userMessage];
      currentTranscript = '';
      isListening = false;
    });
    _scrollToBottom();

    // Show loading message while AI processes
    final loadingMessage = Message(role: Role.assistant, content: 'ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...', timestamp: DateTime.now());
    setState(() {
      messages = [...messages, loadingMessage];
      isLoadingAI = true;
    });
    _scrollToBottom();

    try {
      final response = await aiService.getResponse(text, userMode ?? 'general');

      // Replace loading message with actual response
      setState(() {
        messages = messages.sublist(0, messages.length - 1);
        messages = [...messages, Message(role: Role.assistant, content: response, timestamp: DateTime.now())];
        isLoadingAI = false;
      });
      _scrollToBottom();

      await _speak(response);

      // IMPROVED: Let TTS completion handler decide when to restart listening
    } catch (e) {
      debugPrint('AI response error: $e');
      setState(() {
        messages = messages.sublist(0, messages.length - 1);
        messages = [...messages, Message(role: Role.assistant, content: 'ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.', timestamp: DateTime.now())];
        isLoadingAI = false;
      });
      _scrollToBottom();
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');

      // Restart listening after error
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !isListening && !isSpeaking && !isLoadingAI) {
          _toggleListening();
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleClearData() async {
    await _speak('ನಿಮ್ಮ ಸಂಭಾಷಣೆ ಇತಿಹಾಸವನ್ನು ಅಳಿಸಲಾಗುತ್ತಿದೆ.');
    setState(() {
      messages = [];
      currentTranscript = '';
    });
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  void dispose() {
    ttsService.stop();
    speechService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/welcome'),
                    tooltip: 'ಮುಖಪುಟ',
                  ),
                  const Text('ಧ್ವನಿ ಸಹಾಯಕ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _handleClearData,
                    tooltip: 'ಸಂಭಾಷಣೆ ಅಳಿಸಿ',
                  ),
                ],
              ),
            ),
            // Messages list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: messages.isEmpty
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      Text('ಸಂಭಾಷಣೆ ಪ್ರಾರಂಭಿಸಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('ಲಕ್ಷಣಗಳನ್ನು ವರದಿ ಮಾಡಿ, ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ, ಅಥವಾ ಆರೋಗ್ಯ ಸಲಹೆ ಪಡೆಯಿರಿ', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                      SizedBox(height: 20),
                    ],
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg.role == Role.user;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? theme.primaryColor : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isUser ? 'ನೀವು' : 'ಸಹಾಯಕ', style: TextStyle(fontWeight: FontWeight.w600, color: isUser ? Colors.white : null)),
                                    const SizedBox(height: 6),
                                    Text(msg.content, style: TextStyle(color: isUser ? Colors.white : null)),
                                    const SizedBox(height: 8),
                                    Text(_formatTime(msg.timestamp), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Input area with microphone
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 4, offset: Offset(0, -1))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentTranscript.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: theme.primaryColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                        child: Text('"$currentTranscript"', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    // Debug status line
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${isListening ? 'Listening' : isSpeaking ? 'Speaking' : isLoadingAI ? 'Processing' : 'Ready'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _toggleListening,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening ? const Color(0xFFD32F2F) : const Color(0xFF1976D2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x33000000),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isListening ? 'ಕೇಳುತ್ತಿದೆ...' : (isSpeaking ? 'ಮಾತನಾಡುತ್ತಿದೆ...' : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (userMode == 'account')
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushNamed(context, '/dashboard'),
                          child: const Text('ಡ್ಯಾಶ್‌ಬೋರ್ಡ್ ನೋಡಿ'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Speak a short Kannada welcome message when entering the voice interface.
  Future<void> _speakWelcomeMessage() async {
    // Wait a tiny bit to ensure TTS is initialized
    await Future.delayed(const Duration(milliseconds: 200));
    await _speak('"ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ — ಗರ್ಭಾವಸ್ಥೆ, ಶಿಶು ಆರೈಕೆ ಮತ್ತು ಆರೋಗ್ಯದ ವಿಷಯಗಳಲ್ಲಿ ನಿಮಗೆ ಸಹಾಯ ಮಾಡಲು ಇಲ್ಲಿದ್ದೇನೆ. ಆರೋಗ್ಯಕ್ಕೆ ಸಂಬಂಧಿಸಿದ ಯಾವುದೇ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ, ನಾನು ಸದಾ ನಿಮ್ಮೊಂದಿಗೆ ಸಹಾಯ ಮಾಡಲು ಸಿದ್ಧನಾಗಿದ್ದೇನೆ."');
  }
}

enum Role { user, assistant }

class Message {
  final Role role;
  final String content;
  final DateTime timestamp;

  Message({required this.role, required this.content, required this.timestamp});
}
