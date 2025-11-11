import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp/services/audio_player_service.dart' show audioService;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';

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

  // N8N Configuration - UPDATE THIS WITH YOUR N8N WEBHOOK URL
  static const String n8nWebhookUrl = 'https://squshier-dorie-tensorial.ngrok-free.dev/webhook-test/user-message';
  static const String n8nApiKey = ''; // Only if your n8n requires authentication


  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserMode();
    _addWelcomeMessage();

    // Auto-greet but don't auto-listen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speak('ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ.');
    });
  }

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
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);

    ttsService.setStartHandler(() {
      setState(() => isSpeaking = true);
    });
    ttsService.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
    ttsService.setErrorHandler((err) {
      setState(() => isSpeaking = false);
      debugPrint('TTS error: $err');
    });
  }

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
    if (isSpeaking) {
      await _speak('ದಯವಿಟ್ಟು ಕೆಲವು ಕ್ಷಣಗಳಲ್ಲಿ ಪ್ರಯತ್ನಿಸಿ. ನಾನು ಇನ್ನೂ ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ.');
      return;
    }

    if (isLoadingAI) {
      await _speak('ದಯವಿಟ್ಟು ಪ್ರಕ್ರಿಯೆ ಪೂರ್ಣಗೊಳ್ಳುವವರೆಗೆ ಕಾಯಿರಿ.');
      return;
    }

    if (!isListening) {
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

    // Show loading message while n8n processes
    final loadingMessage = Message(role: Role.assistant, content: 'ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...', timestamp: DateTime.now());
    setState(() {
      messages = [...messages, loadingMessage];
      isLoadingAI = true;
    });
    _scrollToBottom();

    try {
      // Call n8n workflow to get audio file
      await _callN8NWorkflowAndPlay(text);

      // Update message with success indication
      setState(() {
        messages = messages.sublist(0, messages.length - 1);
        messages = [...messages, Message(role: Role.assistant, content: '✅ ಉತ್ತರ ಪಡೆದುಕೊಂಡಿದೆ', timestamp: DateTime.now())];
        isLoadingAI = false;
      });

    } catch (e) {
      debugPrint('N8N response error: $e');
      setState(() {
        messages = messages.sublist(0, messages.length - 1);
        messages = [...messages, Message(role: Role.assistant, content: 'ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.', timestamp: DateTime.now())];
        isLoadingAI = false;
      });
      _scrollToBottom();
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
    }
  }

  /// Call n8n workflow and handle the response
  Future<void> _callN8NWorkflowAndPlay(String userMessage) async {
    try {
      final requestBody = {
        'userMessage': userMessage,
        'userMode': userMode ?? 'general',
        'language': 'kannada',
        'timestamp': DateTime.now().toIso8601String(),
        'responseType': 'audio',
      };

      final headers = {
        'Content-Type': 'application/json',
        if (n8nApiKey.isNotEmpty) 'Authorization': 'Bearer $n8nApiKey',
      };

      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      // Debug: Print response details
      _debugN8NResponse(response);

      if (response.statusCode == 200) {
        await _handleN8NResponse(response);
      } else {
        throw Exception('ಸರ್ವರ್ ತಪ್ಪು: ${response.statusCode}');
      }
    } catch (e) {
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
      rethrow;
    }
  }

  /// Handle n8n response - FIXED VERSION
  Future<void> _handleN8NResponse(http.Response response) async {
    try {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      debugPrint('=== RESPONSE ANALYSIS ===');
      debugPrint('Content-Type: $contentType');
      debugPrint('Body length: ${response.bodyBytes.length} bytes');

      // **FIX: Check if response is JSON or raw audio first**
      if (contentType.contains('application/json') || _looksLikeJson(response.bodyBytes)) {
        await _handleJsonResponse(response);
      } else if (contentType.contains('audio/')) {
        // Direct audio response
        await _playAudioFromBytes(response.bodyBytes, contentType);
      } else {
        // Unknown content type - try both approaches
        await _handleUnknownResponse(response.bodyBytes, contentType);
      }
    } catch (e) {
      debugPrint('N8N response handling error: $e');
      rethrow;
    }
  }

  /// Check if response looks like JSON
  bool _looksLikeJson(List<int> bytes) {
    try {
      if (bytes.isEmpty) return false;
      final firstChar = utf8.decode([bytes[0]]);
      return firstChar == '{' || firstChar == '[';
    } catch (e) {
      return false;
    }
  }

  /// Handle JSON response - FIXED VERSION
  Future<void> _handleJsonResponse(http.Response response) async {
    try {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      debugPrint('JSON Response type: ${jsonResponse.runtimeType}');

      if (jsonResponse is Map) {
        debugPrint('Response keys: ${jsonResponse.keys.toList()}');

        // **FIX: Your n8n returns audio as Buffer object**
        if (jsonResponse['type'] == 'Buffer' && jsonResponse['data'] is List) {
          await _handleBufferObject(jsonResponse);
        }
        // Check for direct audio data in other fields
        else if (jsonResponse['audio'] != null || jsonResponse['data'] != null) {
          await _handleAudioDataInJson(jsonResponse);
        }
        // Check for text response
        else if (jsonResponse['text'] != null || jsonResponse['output'] != null) {
          await _handleTextResponse(jsonResponse);
        }
        else {
          await _extractAndSpeakText(jsonResponse);
        }
      } else if (jsonResponse is List && jsonResponse.isNotEmpty) {
        // Handle array response
        await _handleJsonResponse(http.Response(
          jsonEncode(jsonResponse[0]),
          response.statusCode,
          headers: response.headers,
        ));
      } else {
        throw Exception('ಅಮಾನ್ಯ JSON ಪ್ರತಿಕ್ರಿಯೆ');
      }
    } catch (e) {
      debugPrint('JSON handling error: $e');
      rethrow;
    }
  }

  /// Handle Buffer object from n8n - IMPROVED VERSION
  Future<void> _handleBufferObject(Map bufferObject) async {
    try {
      final bufferData = bufferObject['data'];
      if (bufferData is List) {
        // Convert List<dynamic> to List<int>
        final audioBytes = bufferData.cast<int>().toList();
        debugPrint('🎵 Buffer data length: ${audioBytes.length} bytes');

        if (audioBytes.isEmpty) {
          throw Exception('ಖಾಲಿ ಆಡಿಯೋ ಡೇಟಾ');
        }

        // **DEBUG: Check audio data**
        _debugAudioData(audioBytes);

        // Play the audio
        await _playAudioFromBytes(audioBytes, 'audio/mpeg');
      } else {
        throw Exception('ಅಮಾನ್ಯ ಬಫರ್ ಡೇಟಾ');
      }
    } catch (e) {
      debugPrint('Buffer object handling error: $e');
      await _handleTextFallback(bufferObject, 'ಆಡಿಯೋ ಡೇಟಾ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
    }
  }

  /// Handle audio data embedded in JSON
  Future<void> _handleAudioDataInJson(Map jsonResponse) async {
    try {
      // Check various possible audio data locations
      if (jsonResponse['audio'] is Map && jsonResponse['audio']['data'] is List) {
        await _handleBufferObject(jsonResponse['audio']);
      } else if (jsonResponse['data'] is List) {
        final audioBytes = (jsonResponse['data'] as List).cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg');
      } else if (jsonResponse['audio'] is String) {
        // Base64 encoded audio
        await _handleBase64Audio(jsonResponse['audio'], 'audio/mpeg');
      } else {
        throw Exception('ಯಾವುದೇ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
      }
    } catch (e) {
      debugPrint('Audio data in JSON handling error: $e');
      rethrow;
    }
  }

  /// Handle text response
  Future<void> _handleTextResponse(Map jsonResponse) async {
    try {
      final textResponse = jsonResponse['text'] ??
          jsonResponse['output'] ??
          jsonResponse['message'] ??
          jsonResponse['response'] ??
          'ಪ್ರತಿಕ್ರಿಯೆ ಲಭ್ಯವಿಲ್ಲ';

      debugPrint('Text response: $textResponse');
      await _speak(textResponse.toString());
    } catch (e) {
      debugPrint('Text response handling error: $e');
      throw Exception('ಪ್ರತಿಕ್ರಿಯೆ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  /// Extract and speak text from any response
  Future<void> _extractAndSpeakText(Map jsonResponse) async {
    final textContent = _findTextContent(jsonResponse);

    if (textContent.isNotEmpty) {
      await _speak(textContent);
    } else {
      throw Exception('ಯಾವುದೇ ಪಠ್ಯ ಅಥವಾ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
    }
  }

  /// Find text content in complex JSON structures
  String _findTextContent(dynamic data, {int depth = 0}) {
    if (depth > 5) return '';

    if (data is String) {
      return data.length < 1000 ? data : '';
    } else if (data is Map) {
      final commonTextFields = ['text', 'output', 'message', 'response', 'content', 'transcription', 'answer'];

      for (final field in commonTextFields) {
        if (data[field] is String && data[field].toString().isNotEmpty) {
          return data[field].toString();
        }
      }

      for (final value in data.values) {
        final result = _findTextContent(value, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    } else if (data is List) {
      for (final item in data) {
        final result = _findTextContent(item, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }

    return '';
  }

  /// Text fallback handler
  Future<void> _handleTextFallback(Map jsonResponse, String fallbackMessage) async {
    debugPrint('Using text fallback: $fallbackMessage');

    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
    } else {
      await _speak(fallbackMessage);
    }
  }

  /// Handle base64 encoded audio data
  Future<void> _handleBase64Audio(String audioData, String mimeType) async {
    try {
      final audioBytes = base64.decode(audioData);
      await _playAudioFromBytes(audioBytes, mimeType);
    } catch (e) {
      debugPrint('Base64 audio handling error: $e');
      throw Exception('ಆಡಿಯೋ ಡೇಟಾ ಡಿಕೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  /// Save audio bytes to temporary file and play it using AudioService - IMPROVED
  Future<void> _playAudioFromBytes(List<int> audioBytes, String contentType) async {
    try {
      setState(() => isSpeaking = true);

      debugPrint('🎵 Attempting to play: ${audioBytes.length} bytes, type: $contentType');

      // Convert List<int> to Uint8List
      final Uint8List audioData = Uint8List.fromList(audioBytes);

      // **DEBUG: Verify audio data before playing**
      _debugAudioData(audioBytes);

      // Attempt to play audio
      await audioService.playAudioBytes(audioData, contentType);

      debugPrint('✅ Audio playback started successfully');

      // Wait for completion with timeout
      final startTime = DateTime.now();
      while (audioService.isPlaying) {
        if (DateTime.now().difference(startTime).inSeconds > 30) {
          debugPrint('⏰ Audio playback timeout');
          await audioService.stop();
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('✅ Audio playback completed');
      setState(() => isSpeaking = false);

    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      setState(() => isSpeaking = false);

      // Fallback to TTS
      await _speak('ಆಡಿಯೋ ಸಮಸ್ಯೆ, ಪಠ್ಯ ಪ್ರತಿಕ್ರಿಯೆ ನೀಡುತ್ತಿದೆ.');
    }
  }

  /// Debug method to analyze audio data
  void _debugAudioData(List<int> audioBytes) {
    debugPrint('=== AUDIO DATA ANALYSIS ===');
    debugPrint('Total bytes: ${audioBytes.length}');

    if (audioBytes.length >= 3) {
      final header = audioBytes.take(3).toList();
      debugPrint('First 3 bytes: $header');

      // Check for ID3 header (starts with "ID3")
      if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
        debugPrint('✅ MP3 with ID3 header detected!');
      }
      // Check for MPEG frame sync
      else if (header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
        debugPrint('✅ Raw MPEG audio detected!');
      } else {
        debugPrint('⚠️ Unknown audio format');
      }
    }
  }

  /// Handle unknown response types
  Future<void> _handleUnknownResponse(List<int> bodyBytes, String contentType) async {
    // Try to detect if it's text
    try {
      final text = utf8.decode(bodyBytes);
      if (text.length < 1000 && !text.contains('�')) {
        await _speak(text);
        return;
      }
    } catch (e) {
      // Not valid UTF-8 text
    }

    // Try to play as audio anyway (last attempt)
    try {
      await _playAudioFromBytes(bodyBytes, contentType);
    } catch (e) {
      // Final fallback
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಸ್ವೀಕರಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
    }
  }

  /// Debug method
  void _debugN8NResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? 'unknown';
    final bodyPreview = response.body.length > 200
        ? '${response.body.substring(0, 200)}...'
        : response.body;

    debugPrint('=== N8N Response Debug ===');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Content-Type: $contentType');
    debugPrint('Body Length: ${response.body.length} bytes');
    debugPrint('Body Preview: $bodyPreview');
    debugPrint('========================');
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
  // In the initState method, replace with this:


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
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${isListening ? 'Listening' : isSpeaking ? 'Playing Audio' : isLoadingAI ? 'Processing' : 'Ready'}',
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
                          isListening ? 'ಕೇಳುತ್ತಿದೆ...' : (isSpeaking ? 'ಆಡಿಯೋ ಪ್ಲೇ ಆಗುತ್ತಿದೆ...' : 'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
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
}

enum Role { user, assistant }

class Message {
  final Role role;
  final String content;
  final DateTime timestamp;

  Message({required this.role, required this.content, required this.timestamp});
}