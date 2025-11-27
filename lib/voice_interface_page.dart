import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp/services/audio_player_service.dart' show audioService;
import 'package:shared_preferences/shared_preferences.dart';
import '../chat_message.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/audio_storage_service.dart';
import '../services/chat_history_service.dart';
import '../data/video_database.dart';
import '../welcome_page.dart';
import '../dashboard.dart';
import '../voice_signup_page.dart';
import '../history_page.dart';

class VoiceInterfacePage extends StatefulWidget {
  const VoiceInterfacePage({super.key});

  @override
  State<VoiceInterfacePage> createState() => _VoiceInterfacePageState();
}

class _VoiceInterfacePageState extends State<VoiceInterfacePage> {
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isRecording = false;
  bool isPlaying = false;
  bool isLoadingAI = false;
  bool isSpeaking = false;
  String? userMode;
  String? username;
  String? _currentlyPlayingMessageId;

  // NEW: Audio playback state
  bool _isAudioPaused = false;
  Duration? _audioPosition;
  Duration? _audioDuration;
  // NEW: Store current playing audio data for resume functionality
  Uint8List? _currentAudioData;
  String? _currentAudioContentType;

  // Recording state
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;
  String? _currentTranscript;
  String? _finalTranscript;

  final AudioStorageService _audioStorage = AudioStorageService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();

  static const String n8nWebhookUrl = 'https://boundless-unprettily-voncile.ngrok-free.dev/webhook-test/user-message';
  static const Duration n8nResponseTimeout = Duration(seconds: 300);

  // NEW: Colors
  static const Color greenColor = Color(0xFF037E57);
  static const Color blueColor = Color(0xFF043249);

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
    _addWelcomeMessage();
  }

  // SAFE NAVIGATION METHODS
  void _navigateToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
    );
  }

  void _navigateToHistory() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistoryPage()),
      );
    } catch (e) {
      debugPrint('Navigation to history failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ಇತಿಹಾಸ ಪುಟ ತೆರೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleProfileTap() async {
    final prefs = await SharedPreferences.getInstance();
    final userMode = prefs.getString('userMode');

    if (userMode == 'account') {
      _navigateToDashboard();
    } else {
      _navigateToSignupWithMessage();
    }
  }

  void _navigateToDashboard() {
    try {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Navigation to dashboard failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
      );
    }
  }

  void _navigateToSignupWithMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ಖಾತೆ ರಚಿಸಿ'),
        content: const Text(
          'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್ ಮತ್ತು ಚಾಟ್ ಇತಿಹಾಸವನ್ನು ಪ್ರವೇಶಿಸಲು ದಯವಿಟ್ಟು ಖಾತೆಯನ್ನು ರಚಿಸಿ. ನಿಮ್ಮ ಗರ್ಭಾವಸ್ಥೆಯ ಮಾಹಿತಿಯನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಲು ಮತ್ತು ನಿಮ್ಮ ಎಲ್ಲಾ ಸಂಭಾಷಣೆಗಳನ್ನು ಸಂಗ್ರಹಿಸಲು ಇದು ನಿಮಗೆ ಅನುಮತಿಸುತ್ತದೆ.',
          textAlign: TextAlign.justify,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSignup();
            },
            child: const Text('ಖಾತೆ ರಚಿಸಿ'),
          ),
        ],
      ),
    );
  }

  void _navigateToSignup() {
    try {
      Navigator.pushReplacementNamed(context, '/signup');
    } catch (e) {
      debugPrint('Navigation to signup failed: $e');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const VoiceSignupPage()),
            (route) => false,
      );
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userMode = prefs.getString('userMode');
      username = prefs.getString('username') ?? 'User';
    });

    await _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final localMessages = await _chatHistoryService.loadChatHistory();

      final List<ChatMessage> verifiedMessages = [];
      for (var message in localMessages) {
        if (message.localAudioPath != null) {
          final exists =
          await _audioStorage.audioFileExists(message.localAudioPath!);
          if (!exists) {
            message = message.copyWith(localAudioPath: null, audioBytes: null);
          }
        }
        verifiedMessages.add(message);
      }

      setState(() {
        messages.addAll(verifiedMessages);
      });

      await _audioStorage.cleanupOldAudioFiles();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    await _chatHistoryService.saveChatHistory(messages);
  }

  // NEW: Delete chat history
  Future<void> _deleteChatHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ಚಾಟ್ ಇತಿಹಾಸ ಅಳಿಸಿ'),
        content: const Text('ನೀವು ಖಚಿತವಾಗಿ ಎಲ್ಲಾ ಚಾಟ್ ಇತಿಹಾಸವನ್ನು ಅಳಿಸಲು ಬಯಸುವಿರಾ? ಈ ಕ್ರಿಯೆಯನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗುವುದಿಲ್ಲ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatHistoryService.clearChatHistory();
              await _audioStorage.clearAllAudioFiles();
              setState(() {
                messages.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ಚಾಟ್ ಇತಿಹಾಸ ಅಳಿಸಲಾಗಿದೆ'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('ಅಳಿಸಿ'),
          ),
        ],
      ),
    );
  }

  void _addWelcomeMessage() {
    if (messages.isEmpty) {
      final welcomeMsg = ChatMessage(
        id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
        content:
        'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಸಮಸ್ಯೆಗಳನ್ನು ಹೇಳಿ ಅಥವಾ ಪ್ರಶ್ನೆ ಕೇಳಿ.',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
        localAudioPath: null,
        audioBytes: null,
      );
      setState(() => messages.add(welcomeMsg));
      _saveChatHistory();

      // FIXED: Speak welcome message only once
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _speak('ನಮಸ್ಕಾರ! ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಮತ್ತು ನಿಮ್ಮ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ.');
      });
    }
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSpeechRate(0.4);
    await ttsService.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    try {
      setState(() => isSpeaking = true);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    } finally {
      if (mounted) {
        setState(() => isSpeaking = false);
      }
    }
  }

  void _startRecording() async {
    final ok = await speechService.initialize();
    if (!ok) {
      await _speak('ಕ್ಷಮಿಸಿ, ಮೈಕ್ರೊಫೋನ್ ಲಭ್ಯವಿಲ್ಲ.');
      return;
    }

    setState(() {
      isRecording = true;
      _recordingDuration = Duration.zero;
      _currentTranscript = null;
      _finalTranscript = null;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    });

    try {
      await speechService.startListeningWithRetry((text, isFinal) {
        if (text.isNotEmpty) {
          setState(() {
            _currentTranscript = text;
            if (isFinal) {
              _finalTranscript = text;
            }
          });
        }
      },
          localeId: 'kn-IN',
          retries: 1,
          attemptTimeout: const Duration(seconds: 30));
    } catch (e) {
      _stopRecording();
    }
  }

  void _stopRecording() {
    _recordingTimer.cancel();
    speechService.stop();
    if (mounted) {
      setState(() {
        isRecording = false;
      });
    }
  }

  void _deleteRecording() {
    setState(() {
      _currentTranscript = null;
      _finalTranscript = null;
    });
    _stopRecording();
    _speak('ರೆಕಾರ್ಡಿಂಗ್ ಅಳಿಸಲಾಗಿದೆ. ಮರು-ರೆಕಾರ್ಡ್ ಮಾಡಿ.');
  }

  void _sendRecording() {
    if (_finalTranscript != null && _finalTranscript!.isNotEmpty) {
      _sendMessage(_finalTranscript!);
      _stopRecording();
    } else if (_currentTranscript != null && _currentTranscript!.isNotEmpty) {
      _sendMessage(_currentTranscript!);
      _stopRecording();
    } else {
      _speak('ದಯವಿಟ್ಟು ಮೊದಲು ರೆಕಾರ್ಡ್ ಮಾಡಿ.');
    }
  }

  void _sendMessage(String transcript) async {
    final messageId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    final userMessage = ChatMessage(
      id: messageId,
      content: transcript,
      timestamp: DateTime.now(),
      isUser: true,
      audioUrl: null,
      localAudioPath: null,
      audioBytes: null,
    );

    setState(() {
      messages.add(userMessage);
    });
    _scrollToBottom();

    await _saveChatHistory();

    setState(() => isLoadingAI = true);
    _scrollToBottom();

    try {
      await _callN8NWorkflowAndPlay(transcript);
    } catch (e) {
      debugPrint('N8N response error: $e');
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: 'ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
        localAudioPath: null,
        audioBytes: null,
      );
      setState(() {
        messages.add(errorMessage);
        isLoadingAI = false;
      });
      await _saveChatHistory();
    }

    _scrollToBottom();
  }

  Future<void> _callN8NWorkflowAndPlay(String userMessage) async {
    try {
      final requestBody = {
        'userMessage': userMessage,
        'userMode': userMode ?? 'general',
        'language': 'kannada',
        'timestamp': DateTime.now().toIso8601String(),
        'responseType': 'audio',
      };

      final response = await http
          .post(
        Uri.parse(n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(n8nResponseTimeout);

      if (response.statusCode == 200) {
        await _handleN8NResponse(response, userMessage);
      } else if (response.statusCode == 500) {
        debugPrint('⚠️ Server returned 500, but checking for valid response data...');
        debugPrint('Response body preview: ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}');
        await _handleN8NResponse(response, userMessage);
      } else {
        throw Exception('ಸರ್ವರ್ ತಪ್ಪು: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('N8N response error: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
      rethrow;
    } finally {
      setState(() => isLoadingAI = false);
    }
  }

  Future<void> _handleN8NResponse(
      http.Response response, String userMessage) async {
    try {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final bodyBytes = response.bodyBytes;

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Content-Type: $contentType');
      debugPrint('📥 Body length: ${bodyBytes.length} bytes');

      if (bodyBytes.isEmpty) {
        throw Exception('ಖಾಲಿ ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆದುಬಂದಿದೆ');
      }

      if (contentType.contains('application/json') ||
          _looksLikeJson(bodyBytes)) {
        await _handleJsonResponse(response, userMessage);
      } else if (contentType.contains('audio/')) {
        await _playAudioFromBytes(bodyBytes, contentType, userMessage);
      } else {
        await _handleUnknownResponse(bodyBytes, contentType, userMessage);
      }
    } catch (e) {
      debugPrint('❌ N8N response handling error: $e');

      try {
        debugPrint('🔄 Trying JSON fallback...');
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse is Map || jsonResponse is List) {
          await _handleJsonResponse(response, userMessage);
          return;
        }
      } catch (e2) {
        debugPrint('❌ JSON fallback also failed: $e2');
      }

      rethrow;
    }
  }

  bool _looksLikeJson(List<int> bytes) {
    try {
      if (bytes.isEmpty) return false;
      final firstChar = utf8.decode([bytes[0]]);
      return firstChar == '{' || firstChar == '[';
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleJsonResponse(
      http.Response response, String userMessage) async {
    try {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

      if (jsonResponse is List && jsonResponse.isNotEmpty) {
        final firstItem = jsonResponse.first;
        if (firstItem is Map) {
          if (firstItem.containsKey('video') && firstItem.containsKey('audioContent')) {
            await _handleVideoAudioResponse(firstItem, userMessage);
            return;
          }
        }
      }

      if (jsonResponse is Map) {
        if (jsonResponse.containsKey('video') && jsonResponse.containsKey('audioContent')) {
          await _handleVideoAudioResponse(jsonResponse, userMessage);
        }
        else if (jsonResponse['type'] == 'Buffer' && jsonResponse['data'] is List) {
          await _handleBufferObject(jsonResponse, userMessage);
        } else if (jsonResponse['audio'] != null || jsonResponse['data'] != null) {
          await _handleAudioDataInJson(jsonResponse, userMessage);
        } else if (jsonResponse['text'] != null || jsonResponse['output'] != null) {
          await _handleTextResponse(jsonResponse, userMessage);
        } else {
          await _extractAndSpeakText(jsonResponse, userMessage);
        }
      }
    } catch (e) {
      debugPrint('JSON handling error: $e');
      rethrow;
    }
  }

  Future<void> _handleVideoAudioResponse(Map jsonResponse, String userMessage) async {
    try {
      final audioContent = jsonResponse['audioContent']?.toString();
      if (audioContent != null && audioContent.isNotEmpty) {
        final audioBytes = base64.decode(audioContent);
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);

        if (jsonResponse['video'] != null) {
          await _addVideoSuggestionFromN8N(jsonResponse['video']);
        }
      } else {
        throw Exception('ಯಾವುದೇ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
      }
    } catch (e) {
      debugPrint('Video+Audio response handling error: $e');
      final textContent = _findTextContent(jsonResponse);
      if (textContent.isNotEmpty) {
        await _speak(textContent);
        if (jsonResponse['video'] != null) {
          await _addVideoSuggestionFromN8N(jsonResponse['video']);
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _handleBufferObject(Map bufferObject, String userMessage) async {
    try {
      final bufferData = bufferObject['data'];
      if (bufferData is List) {
        final audioBytes = bufferData.cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);
      }
    } catch (e) {
      debugPrint('Buffer object handling error: $e');
      await _handleTextFallback(bufferObject,
          'ಆಡಿಯೋ ಡೇಟಾ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.', userMessage);
    }
  }

  Future<void> _handleAudioDataInJson(Map jsonResponse, String userMessage) async {
    try {
      if (jsonResponse['audioContent'] != null && jsonResponse['audioContent'] is String) {
        final audioContent = jsonResponse['audioContent'] as String;
        final audioBytes = base64.decode(audioContent);
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);

        if (jsonResponse['video'] != null) {
          await _addVideoSuggestionFromN8N(jsonResponse['video']);
        }
      }
      else if (jsonResponse['audio'] != null && jsonResponse['audio']['data'] != null) {
        final audioData = jsonResponse['audio']['data'];
        if (audioData is String) {
          final audioBytes = base64.decode(audioData);
          await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);

          if (jsonResponse['video'] != null && jsonResponse['video']['hasVideo'] == true) {
            await _addVideoSuggestionFromN8N(jsonResponse['video']);
          }
        }
      }
      else if (jsonResponse['audio'] is Map && jsonResponse['audio']['data'] is List) {
        await _handleBufferObject(jsonResponse['audio'], userMessage);
      }
      else if (jsonResponse['data'] is List) {
        final audioBytes = (jsonResponse['data'] as List).cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);
      }
      else {
        throw Exception('ಯಾವುದೇ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
      }
    } catch (e) {
      debugPrint('Audio data in JSON handling error: $e');
      rethrow;
    }
  }

  Future<void> _addVideoSuggestionFromN8N(dynamic videoData) async {
    try {
      String? videoUrl;
      String? videoTitle;

      if (videoData is Map) {
        videoUrl = videoData['url']?.toString();
        videoTitle = videoData['title']?.toString();

        videoUrl ??= videoData['videoUrl']?.toString();
        videoTitle ??= videoData['videoTitle']?.toString();
      }

      if (videoUrl != null && videoTitle != null) {
        await Future.delayed(const Duration(seconds: 1));

        final videoMessage = ChatMessage(
          id: 'video_${DateTime.now().millisecondsSinceEpoch}',
          content: 'ನೀವು ಈ ವೀಡಿಯೊವನ್ನು also ನೋಡಬಹುದು:',
          timestamp: DateTime.now(),
          isUser: false,
          audioUrl: null,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
          localAudioPath: null,
          audioBytes: null,
        );

        setState(() {
          messages.add(videoMessage);
        });
        await _saveChatHistory();
        _scrollToBottom();

        debugPrint('✅ Video suggestion added: $videoTitle - $videoUrl');
      } else {
        debugPrint('⚠️ Video data missing URL or title: $videoData');
      }
    } catch (e) {
      debugPrint('❌ Error adding N8N video suggestion: $e');
    }
  }

  Future<void> _handleTextResponse(Map jsonResponse, String userMessage) async {
    try {
      final textResponse = jsonResponse['text'] ??
          jsonResponse['output'] ??
          jsonResponse['message'] ??
          'ಪ್ರತಿಕ್ರಿಯೆ ಲಭ್ಯವಿಲ್ಲ';

      final aiMessage = ChatMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        content: textResponse.toString(),
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
        localAudioPath: null,
        audioBytes: null,
      );

      setState(() {
        messages.add(aiMessage);
      });

      await _saveChatHistory();
      await _speak(textResponse.toString());
      await _addVideoSuggestion(userMessage);
    } catch (e) {
      debugPrint('Text response handling error: $e');
      throw Exception('ಪ್ರತಿಕ್ರಿಯೆ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  Future<void> _addVideoSuggestion(String userMessage) async {
    final videoData = VideoDatabase.findVideo(userMessage);
    if (videoData != null) {
      await Future.delayed(const Duration(seconds: 1));

      final videoMessage = ChatMessage(
        id: 'video_${DateTime.now().millisecondsSinceEpoch}',
        content: 'ನೀವು ಈ ವೀಡಿಯೊವನ್ನು also ನೋಡಬಹುದು:',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
        videoUrl: videoData['video'],
        videoTitle: videoData['title'],
        localAudioPath: null,
        audioBytes: null,
      );

      setState(() {
        messages.add(videoMessage);
      });
      await _saveChatHistory();
      _scrollToBottom();
    }
  }

  Future<void> _extractAndSpeakText(
      Map jsonResponse, String userMessage) async {
    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
      await _addVideoSuggestion(userMessage);
    } else {
      throw Exception('ಯಾವುದೇ ಪಠ್ಯ ಅಥವಾ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
    }
  }

  String _findTextContent(dynamic data, {int depth = 0}) {
    if (depth > 5) return '';
    if (data is String) return data.length < 1000 ? data : '';
    if (data is Map) {
      final commonTextFields = [
        'text',
        'output',
        'message',
        'response',
        'content'
      ];
      for (final field in commonTextFields) {
        if (data[field] is String && data[field].toString().isNotEmpty) {
          return data[field].toString();
        }
      }
      for (final value in data.values) {
        final result = _findTextContent(value, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    if (data is List) {
      for (final item in data) {
        final result = _findTextContent(item, depth: depth + 1);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  Future<void> _handleTextFallback(
      Map jsonResponse, String fallbackMessage, String userMessage) async {
    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
      await _addVideoSuggestion(userMessage);
    } else {
      await _speak(fallbackMessage);
    }
  }

  Future<void> _playAudioFromBytes(
      List<int> audioBytes, String contentType, String userMessage) async {
    try {
      setState(() {
        isPlaying = true;
        _isAudioPaused = false;
        _audioPosition = Duration.zero;
        _audioDuration = const Duration(seconds: 19);
        // Store current audio data for pause/resume functionality
        _currentAudioData = Uint8List.fromList(audioBytes);
        _currentAudioContentType = contentType;
      });

      final Uint8List audioData = Uint8List.fromList(audioBytes);

      final messageId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
      final localPath = await _audioStorage.saveAudioLocally(audioData, messageId);

      await audioService.playAudioBytes(audioData, contentType);

      final aiMessage = ChatMessage(
        id: messageId,
        content: 'ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ',
        timestamp: DateTime.now(),
        isUser: false,
        audioUrl: null,
        localAudioPath: localPath,
        audioBytes: audioData,
      );

      setState(() {
        messages.add(aiMessage);
        isPlaying = false;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = null;
      });

      await _saveChatHistory();

    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      setState(() {
        isPlaying = false;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = null;
      });
      await _speak('ಆಡಿಯೋ ಸಮಸ್ಯೆ, ಪಠ್ಯ ಪ್ರತಿಕ್ರಿಯೆ ನೀಡುತ್ತಿದೆ.');
    }
  }

  Future<void> _playLocalAudio(ChatMessage msg) async {
    if (msg.audioBytes != null) {
      await _playCachedAudio(msg);
    } else if (msg.localAudioPath != null) {
      await _playLocalAudioFile(msg);
    } else {
      await _speak(msg.content);
    }
  }

  Future<void> _playCachedAudio(ChatMessage msg) async {
    try {
      setState(() {
        isPlaying = true;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = msg.id;
        _audioPosition = Duration.zero;
        _audioDuration = const Duration(seconds: 19);
        // Store current audio data for pause/resume functionality
        _currentAudioData = msg.audioBytes;
        _currentAudioContentType = 'audio/mpeg';
      });

      await audioService.playAudioBytes(msg.audioBytes!, 'audio/mpeg');

      setState(() {
        isPlaying = false;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = null;
      });
    } catch (e) {
      debugPrint('❌ Cached audio playback error: $e');
      await _playLocalAudioFile(msg);
    }
  }

  Future<void> _playLocalAudioFile(ChatMessage msg) async {
    try {
      setState(() {
        isPlaying = true;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = msg.id;
        _audioPosition = Duration.zero;
        _audioDuration = const Duration(seconds: 19);
      });

      final audioBytes =
      await _audioStorage.getLocalAudioBytes(msg.localAudioPath!);
      if (audioBytes != null) {
        final updatedMsg = msg.copyWith(audioBytes: audioBytes);
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          setState(() {
            messages[index] = updatedMsg;
          });
        }

        // Store current audio data for pause/resume functionality
        _currentAudioData = audioBytes;
        _currentAudioContentType = 'audio/mpeg';

        await audioService.playAudioBytes(audioBytes, 'audio/mpeg');
      } else {
        throw Exception('Audio file not found');
      }

      setState(() {
        isPlaying = false;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = null;
      });
    } catch (e) {
      debugPrint('❌ Local audio file playback error: $e');
      setState(() {
        isPlaying = false;
        _isAudioPaused = false;
        _currentlyPlayingMessageId = null;
      });
      await _speak(msg.content);
    }
  }

  // UPDATED: Pause/Resume audio functionality using stop and replay
  Future<void> _pauseResumeAudio(ChatMessage msg) async {
    if (_currentlyPlayingMessageId == msg.id) {
      if (isPlaying && !_isAudioPaused) {
        // "Pause" by stopping the audio
        await audioService.stop();
        setState(() {
          _isAudioPaused = true;
        });
      } else if (_isAudioPaused) {
        // "Resume" by playing the audio from beginning
        if (_currentAudioData != null && _currentAudioContentType != null) {
          setState(() {
            isPlaying = true;
            _isAudioPaused = false;
          });
          await audioService.playAudioBytes(_currentAudioData!, _currentAudioContentType!);
          setState(() {
            isPlaying = false;
          });
        }
      }
    } else {
      // Play different audio
      if (isPlaying) {
        await audioService.stop();
      }
      await _playLocalAudio(msg);
    }
  }

  Future<void> _handleUnknownResponse(
      List<int> bodyBytes, String contentType, String userMessage) async {
    try {
      final text = utf8.decode(bodyBytes);
      if (text.length < 1000 && !text.contains('�')) {
        await _speak(text);
        await _addVideoSuggestion(userMessage);
        return;
      }
    } catch (e) {
      debugPrint('Text decoding failed: $e');
    }

    try {
      await _playAudioFromBytes(bodyBytes, contentType, userMessage);
    } catch (e) {
      debugPrint('Audio playback failed: $e');
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಸ್ವೀಕರಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
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

  // Simple video icon that shows URL dialog
  void _openVideo(String videoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ವೀಡಿಯೊ ಲಿಂಕ್:'),
            const SizedBox(height: 8),
            SelectableText(
              videoUrl,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ಲಿಂಕ್ ಕಾಪಿ ಆಗಿದೆ'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('ಲಿಂಕ್ ಕಾಪಿ ಮಾಡಿ'),
          ),
        ],
      ),
    );
  }

  // Helper method to replace withOpacity
  Color _getColorWithOpacity(Color color, double opacity) {
    return Color.fromARGB(
      (opacity * 255.0).round() & 0xff,
      (color.r * 255.0).round() & 0xff,
      (color.g * 255.0).round() & 0xff,
      (color.b * 255.0).round() & 0xff,
    );
  }

  // User Avatar
  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: greenColor, // UPDATED: Changed to new green color
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // Assistant Avatar
  Widget _buildAssistantAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: blueColor, // UPDATED: Changed to new blue color
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.smart_toy,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // Audio Message Bubble with Pause/Play functionality
  Widget _buildAudioMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final isCurrentlyPlaying = _currentlyPlayingMessageId == msg.id && isPlaying;
    final isPaused = _currentlyPlayingMessageId == msg.id && _isAudioPaused;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAssistantAvatar(),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 40 : 8,
                right: isUser ? 8 : 40,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                isUser ? greenColor : blueColor, // UPDATED: New colors
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  // Play/Pause Button
                  GestureDetector(
                    onTap: () => _pauseResumeAudio(msg),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaused ? Icons.play_arrow :
                        isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                        size: 24,
                        color: isUser
                            ? greenColor // UPDATED: New green color
                            : blueColor, // UPDATED: New blue color
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Audio Timeline and Waveform
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_audioPosition ?? Duration.zero),
                              style: TextStyle(
                                color: _getColorWithOpacity(Colors.white, 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_formatDuration(_audioPosition ?? Duration.zero)} / ${_formatDuration(_audioDuration ?? const Duration(seconds: 19))}',
                              style: TextStyle(
                                color: _getColorWithOpacity(Colors.white, 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Progress Bar / Waveform
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _getColorWithOpacity(Colors.white, 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              // Progress
                              Container(
                                width: isCurrentlyPlaying || isPaused
                                    ? MediaQuery.of(context).size.width * 0.3
                                    : 0,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              // Waveform dots (simplified)
                              if (!isCurrentlyPlaying && !isPaused)
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                                  children: List.generate(8, (index) {
                                    final height = 2 + (index % 3);
                                    return Container(
                                      width: 2,
                                      height: height.toDouble(),
                                      color: _getColorWithOpacity(
                                          Colors.white, 0.6),
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ),

                        // Message content (for text messages)
                        if (msg.content.isNotEmpty &&
                            !msg.content.contains('ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              msg.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  // Helper method to format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // Text Message Bubble with simplified video icon
  Widget _buildTextMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final hasVideo = msg.videoUrl != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAssistantAvatar(),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 40 : 8,
                right: isUser ? 8 : 40,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                isUser ? greenColor : blueColor, // UPDATED: New colors
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  if (hasVideo) ...[
                    const SizedBox(height: 12),
                    // Simple video icon only
                    GestureDetector(
                      onTap: () => _openVideo(msg.videoUrl!, msg.videoTitle!),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getColorWithOpacity(Colors.white, 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _getColorWithOpacity(Colors.white, 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'ವೀಡಿಯೊ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  // Choose between audio or text bubble
  Widget _buildMessageBubble(ChatMessage msg) {
    final hasLocalAudio = msg.localAudioPath != null || msg.audioBytes != null;
    final isAudioResponse =
        msg.content.contains('ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ') || hasLocalAudio;

    if (isAudioResponse) {
      return _buildAudioMessageBubble(msg);
    } else {
      return _buildTextMessageBubble(msg);
    }
  }

  // Play message audio with pause/resume support

  @override
  void dispose() {
    _recordingTimer.cancel();
    ttsService.stop();
    speechService.stop();
    audioService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header - UPDATED: Added delete button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: blueColor, // UPDATED: New blue color
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _navigateToWelcome,
                    tooltip: 'ಹಿಂದೆ',
                  ),
                  const Text(
                    'ಧ್ವನಿ ಸಹಾಯಕ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      // Delete Chat History Button
                      if (messages.isNotEmpty && messages.length > 1) // Show only if there are messages
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: _deleteChatHistory,
                          tooltip: 'ಚಾಟ್ ಇತಿಹಾಸ ಅಳಿಸಿ',
                        ),
                      if (userMode == 'account')
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white),
                          onPressed: _navigateToHistory,
                          tooltip: 'ಚಾಟ್ ಇತಿಹಾಸ',
                        ),
                      IconButton(
                        icon: const Icon(Icons.person, color: Colors.white),
                        onPressed: _handleProfileTap,
                        tooltip: 'ಪ್ರೊಫೈಲ್',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: messages.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ಸಂಭಾಷಣೆ ಪ್ರಾರಂಭಿಸಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length + (isLoadingAI ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isLoadingAI && index == messages.length) {
                      return _buildLoadingIndicator();
                    }
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),
            ),

            // Recording Controls
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (isRecording) _buildRecordingUI(),
                  if (!isRecording) _buildNormalUI(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: blueColor, // UPDATED: New blue color
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    final hasTranscript = _finalTranscript != null || _currentTranscript != null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Recording Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                'ರೆಕಾರ್ಡಿಂಗ್... ${_recordingDuration.inSeconds}ಸೆ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Audio Recording Bubble
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: greenColor, // UPDATED: New green color
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Recording Indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 24,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(width: 12),

                // Recording Timeline and Waveform
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time indicator
                      Text(
                        '${_recordingDuration.inSeconds}ಸೆ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Live Waveform
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _getColorWithOpacity(Colors.white, 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(12, (index) {
                            final height = 2 +
                                (DateTime.now().millisecond + index * 50) % 4;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 2,
                              height: height.toDouble(),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Transcript
                      if (_currentTranscript != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _currentTranscript!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Delete Button
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, size: 24),
                    label: const Text('ಅಳಿಸಿ', style: TextStyle(fontSize: 16)),
                    onPressed: _deleteRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // Send Button
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 24),
                    label:
                    const Text('ಕಳುಹಿಸಿ', style: TextStyle(fontSize: 16)),
                    onPressed: hasTranscript ? _sendRecording : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasTranscript
                          ? greenColor // UPDATED: New green color
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Normal UI with large mic button
  Widget _buildNormalUI() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Large Mic Button
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: greenColor, // UPDATED: New green color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: greenColor // UPDATED: New green color
                        .withAlpha(76),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}