import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
// ADD THIS IMPORT
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp/services/audio_player_service.dart' show audioService;
import 'package:shared_preferences/shared_preferences.dart';
// ADD THIS IMPORT

// IMPORT THE SEPARATE CHAT MESSAGE MODEL
import '../chat_message.dart'; // ADD THIS IMPORT
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/firebase_service.dart';
import '../services/audio_storage_service.dart';
import '../services/chat_history_service.dart';
import '../data/video_database.dart';
import '../welcome_page.dart';
import '../dashboard.dart';

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

  // Recording state
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;
  String? _currentTranscript;

  final FirebaseService _firebaseService = FirebaseService();
  final AudioStorageService _audioStorage = AudioStorageService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();

  static const String n8nWebhookUrl = 'https://boundless-unprettily-voncile.ngrok-free.dev/webhook/user-message';
  static const Duration n8nResponseTimeout = Duration(seconds: 300);

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
    _addWelcomeMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speak('ನಮಸ್ಕಾರ! ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ ಮತ್ತು ನಿಮ್ಮ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ.');
    });
  }

  // SAFE NAVIGATION METHODS
  void _navigateToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
    );
  }

  void _navigateToDashboard() {
    try {
      Navigator.pushNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Navigation to dashboard failed: $e');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userMode = prefs.getString('userMode');
      username = prefs.getString('username') ?? 'User';
    });

    // Load chat history with local audio storage
    await _loadChatHistory();
  }

  // MODIFIED: Load chat history with local audio storage
  Future<void> _loadChatHistory() async {
    try {
      // Load from local storage first
      final localMessages = await _chatHistoryService.loadChatHistory();

      // Verify local audio files still exist
      final List<ChatMessage> verifiedMessages = [];
      for (var message in localMessages) {
        if (message.localAudioPath != null) {
          final exists = await _audioStorage.audioFileExists(message.localAudioPath!);
          if (!exists) {
            // Remove local audio path if file doesn't exist
            message = message.copyWith(localAudioPath: null, audioBytes: null);
          }
        }
        verifiedMessages.add(message);
      }

      // If no local messages, load from Firebase for account users
      if (verifiedMessages.isEmpty && userMode == 'account') {
        final notes = await _firebaseService.getRecentVisitNotes(limit: 50);
        for (final note in notes) {
          final transcript = (note['transcript'] ?? '').toString();
          final timestamp = (note['created_at'] as Timestamp).toDate();

          if (transcript.isNotEmpty) {
            verifiedMessages.add(ChatMessage(
              id: 'user_${timestamp.millisecondsSinceEpoch}',
              content: transcript,
              timestamp: timestamp,
              isUser: true,
              audioUrl: null,
              localAudioPath: null,
              audioBytes: null,
            ));
          }
        }
        verifiedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      setState(() {
        messages.addAll(verifiedMessages);
      });

      // Clean up old audio files on app start
      await _audioStorage.cleanupOldAudioFiles();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  // NEW: Save chat history with local audio
  Future<void> _saveChatHistory() async {
    await _chatHistoryService.saveChatHistory(messages);
  }

  void _addWelcomeMessage() {
    final welcomeMsg = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      content: 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಸಮಸ್ಯೆಗಳನ್ನು ಹೇಳಿ ಅಥವಾ ಪ್ರಶ್ನೆ ಕೇಳಿ.',
      timestamp: DateTime.now(),
      isUser: false,
      audioUrl: null,
      localAudioPath: null,
      audioBytes: null,
    );
    setState(() => messages.add(welcomeMsg));
    _saveChatHistory(); // Save after adding welcome message
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

  // MODIFIED RECORDING METHOD WITH DELETE BUTTON
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
    });

    // Start recording timer
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
          });
        }
        if (isFinal && text.isNotEmpty) {
          _stopRecording(text);
        }
      }, localeId: 'kn-IN', retries: 1, attemptTimeout: const Duration(seconds: 30));
    } catch (e) {
      _stopRecording('');
    }
  }

  void _stopRecording(String transcript) {
    _recordingTimer.cancel();

    if (mounted) {
      setState(() {
        isRecording = false;
      });
    }

    if (transcript.isNotEmpty) {
      _sendMessage(transcript);
    }
  }

  void _deleteRecording() {
    setState(() {
      _currentTranscript = null;
    });
    _speak('ರೆಕಾರ್ಡಿಂಗ್ ಅಳಿಸಲಾಗಿದೆ. ಮರು-ರೆಕಾರ್ಡ್ ಮಾಡಿ.');
  }

  void _sendMessage(String transcript) async {
    final messageId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    // Add user message to chat
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

    // Save to Firebase for account users
    if (userMode == 'account') {
      await _firebaseService.saveVisitNote(transcript);
    }

    // Save chat history after adding user message
    await _saveChatHistory();

    // Show loading animation
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
      await _saveChatHistory(); // Save after adding error message
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

      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(n8nResponseTimeout);

      if (response.statusCode == 200) {
        await _handleN8NResponse(response, userMessage);
      } else {
        throw Exception('ಸರ್ವರ್ ತಪ್ಪು: ${response.statusCode}');
      }
    } catch (e) {
      await _speak('ಕ್ಷಮಿಸಿ, ಪ್ರತಿಕ್ರಿಯೆ ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
      rethrow;
    } finally {
      setState(() => isLoadingAI = false);
    }
  }

  // MODIFIED TO INCLUDE VIDEO SUGGESTION
  Future<void> _handleN8NResponse(http.Response response, String userMessage) async {
    try {
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.contains('application/json') || _looksLikeJson(response.bodyBytes)) {
        await _handleJsonResponse(response, userMessage);
      } else if (contentType.contains('audio/')) {
        await _playAudioFromBytes(response.bodyBytes, contentType, userMessage);
      } else {
        await _handleUnknownResponse(response.bodyBytes, contentType, userMessage);
      }
    } catch (e) {
      debugPrint('N8N response handling error: $e');
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

  Future<void> _handleJsonResponse(http.Response response, String userMessage) async {
    try {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

      if (jsonResponse is Map) {
        if (jsonResponse['type'] == 'Buffer' && jsonResponse['data'] is List) {
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

  Future<void> _handleBufferObject(Map bufferObject, String userMessage) async {
    try {
      final bufferData = bufferObject['data'];
      if (bufferData is List) {
        final audioBytes = bufferData.cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);
      }
    } catch (e) {
      debugPrint('Buffer object handling error: $e');
      await _handleTextFallback(bufferObject, 'ಆಡಿಯೋ ಡೇಟಾ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.', userMessage);
    }
  }

  Future<void> _handleAudioDataInJson(Map jsonResponse, String userMessage) async {
    try {
      if (jsonResponse['audio'] is Map && jsonResponse['audio']['data'] is List) {
        await _handleBufferObject(jsonResponse['audio'], userMessage);
      } else if (jsonResponse['data'] is List) {
        final audioBytes = (jsonResponse['data'] as List).cast<int>().toList();
        await _playAudioFromBytes(audioBytes, 'audio/mpeg', userMessage);
      } else if (jsonResponse['audio'] is String) {
        await _handleBase64Audio(jsonResponse['audio'], 'audio/mpeg', userMessage);
      } else {
        throw Exception('ಯಾವುದೇ ಆಡಿಯೋ ಡೇಟಾ ಕಂಡುಬಂದಿಲ್ಲ');
      }
    } catch (e) {
      debugPrint('Audio data in JSON handling error: $e');
      rethrow;
    }
  }

  Future<void> _handleTextResponse(Map jsonResponse, String userMessage) async {
    try {
      final textResponse = jsonResponse['text'] ?? jsonResponse['output'] ?? jsonResponse['message'] ?? 'ಪ್ರತಿಕ್ರಿಯೆ ಲಭ್ಯವಿಲ್ಲ';

      // Add AI response as text message
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

      await _saveChatHistory(); // Save after adding AI message

      await _speak(textResponse.toString());

      // ADD VIDEO SUGGESTION AFTER SPEAKING
      await _addVideoSuggestion(userMessage);
    } catch (e) {
      debugPrint('Text response handling error: $e');
      throw Exception('ಪ್ರತಿಕ್ರಿಯೆ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  // ADD VIDEO SUGGESTION METHOD
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
      await _saveChatHistory(); // Save after adding video suggestion
      _scrollToBottom();
    }
  }

  Future<void> _extractAndSpeakText(Map jsonResponse, String userMessage) async {
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
      final commonTextFields = ['text', 'output', 'message', 'response', 'content'];
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

  Future<void> _handleTextFallback(Map jsonResponse, String fallbackMessage, String userMessage) async {
    final textContent = _findTextContent(jsonResponse);
    if (textContent.isNotEmpty) {
      await _speak(textContent);
      await _addVideoSuggestion(userMessage);
    } else {
      await _speak(fallbackMessage);
    }
  }

  Future<void> _handleBase64Audio(String audioData, String mimeType, String userMessage) async {
    try {
      final audioBytes = base64.decode(audioData);
      await _playAudioFromBytes(audioBytes, mimeType, userMessage);
    } catch (e) {
      debugPrint('Base64 audio handling error: $e');
      throw Exception('ಆಡಿಯೋ ಡೇಟಾ ಡಿಕೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ');
    }
  }

  // MODIFIED: Enhanced playAudioFromBytes with local storage
  Future<void> _playAudioFromBytes(List<int> audioBytes, String contentType, String userMessage) async {
    try {
      setState(() => isPlaying = true);

      final Uint8List audioData = Uint8List.fromList(audioBytes);

      // Save audio locally
      final messageId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
      final localPath = await _audioStorage.saveAudioLocally(audioData, messageId);

      // Play audio immediately
      await audioService.playAudioBytes(audioData, contentType);

      // Add AI response as audio message with local storage
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
        _currentlyPlayingMessageId = null;
      });

      // Save chat history after adding message
      await _saveChatHistory();

      // ADD VIDEO SUGGESTION AFTER AUDIO PLAYBACK
      await _addVideoSuggestion(userMessage);

    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await _speak('ಆಡಿಯೋ ಸಮಸ್ಯೆ, ಪಠ್ಯ ಪ್ರತಿಕ್ರಿಯೆ ನೀಡುತ್ತಿದೆ.');
    }
  }

  // NEW: Play from local storage
  Future<void> _playLocalAudio(ChatMessage msg) async {
    if (msg.audioBytes != null) {
      // Use cached bytes for immediate playback
      await _playCachedAudio(msg);
    } else if (msg.localAudioPath != null) {
      // Load from local file and cache
      await _playLocalAudioFile(msg);
    } else {
      // Fallback to TTS
      await _speak(msg.content);
    }
  }

  // NEW: Play cached audio bytes
  Future<void> _playCachedAudio(ChatMessage msg) async {
    try {
      setState(() {
        isPlaying = true;
        _currentlyPlayingMessageId = msg.id;
      });

      await audioService.playAudioBytes(msg.audioBytes!, 'audio/mpeg');

      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
    } catch (e) {
      debugPrint('❌ Cached audio playback error: $e');
      await _playLocalAudioFile(msg);
    }
  }

  // NEW: Play from local audio file
  Future<void> _playLocalAudioFile(ChatMessage msg) async {
    try {
      setState(() {
        isPlaying = true;
        _currentlyPlayingMessageId = msg.id;
      });

      final audioBytes = await _audioStorage.getLocalAudioBytes(msg.localAudioPath!);
      if (audioBytes != null) {
        // Update message with cached bytes
        final updatedMsg = msg.copyWith(audioBytes: audioBytes);
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          setState(() {
            messages[index] = updatedMsg;
          });
        }

        await audioService.playAudioBytes(audioBytes, 'audio/mpeg');
      } else {
        throw Exception('Audio file not found');
      }

      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
    } catch (e) {
      debugPrint('❌ Local audio file playback error: $e');
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await _speak(msg.content);
    }
  }

  Future<void> _handleUnknownResponse(List<int> bodyBytes, String contentType, String userMessage) async {
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

  // MODIFIED: Enhanced clear data to include audio files
  Future<void> _handleClearData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ಚಾಟ್ ಇತಿಹಾಸ ಅಳಿಸಿ'),
        content: const Text('ನೀವು ಖಚಿತವಾಗಿ ಎಲ್ಲಾ ಸಂಭಾಷಣೆ ಇತಿಹಾಸವನ್ನು ಅಳಿಸಲು ಬಯಸುವಿರಾ? ಇದು ಎಲ್ಲಾ ಆಡಿಯೋ ಫೈಲ್‌ಗಳನ್ನು also ಅಳಿಸುತ್ತದೆ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Clear messages
              setState(() {
                messages.clear();
              });

              // Clear storage
              await _chatHistoryService.clearChatHistory();

              // Clear audio cache - FIXED: Use the service method
              await _audioStorage.cleanupOldAudioFiles(keepLastDays: 0); // This will delete all files

              _speak('ಸಂಭಾಷಣೆ ಇತಿಹಾಸ ಮತ್ತು ಆಡಿಯೋ ಫೈಲ್‌ಗಳು ಅಳಿಸಲಾಗಿದೆ.');

              // Add welcome message back
              _addWelcomeMessage();
            },
            child: const Text('ಅಳಿಸಿ'),
          ),
        ],
      ),
    );
  }

  // ADD METHOD TO OPEN VIDEO
  void _openVideo(String videoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('ವೀಡಿಯೊ ತೆರೆಯಲು准备: $videoUrl'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ರದ್ದು'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement video playback
              _speak('ವೀಡಿಯೊ ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ');
            },
            child: const Text('ವೀಡಿಯೊ ತೆರೆಯಿರಿ'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  // MODIFIED: Enhanced message bubble with audio storage indicators
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final isCurrentlyPlaying = _currentlyPlayingMessageId == msg.id && isPlaying;
    final hasVideo = msg.videoUrl != null;
    final hasLocalAudio = msg.localAudioPath != null || msg.audioBytes != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF00796B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Row(
                      children: [
                        Icon(Icons.smart_toy, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        const Text('ಸಹಾಯಕ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85 - 24,
                    ),
                    child: Text(
                      msg.content,
                      softWrap: true,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),

                  // ADD VIDEO SUGGESTION
                  if (hasVideo) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00796B)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.video_library, color: const Color(0xFF00796B), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  msg.videoTitle ?? 'ವೀಡಿಯೊ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00796B),
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow, size: 20),
                              label: const Text('ವೀಡಿಯೊ ನೋಡಿ'),
                              onPressed: () => _openVideo(msg.videoUrl!, msg.videoTitle!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      if (!isUser)
                        GestureDetector(
                          onTap: () => _playMessageAudio(msg),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isCurrentlyPlaying ? const Color(0xFF00796B) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00796B),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Icon(
                                  isCurrentlyPlaying ? Icons.stop : Icons.play_arrow,
                                  size: 28,
                                  color: isCurrentlyPlaying ? Colors.white : const Color(0xFF00796B),
                                ),
                                // Green dot indicator for locally stored audio
                                if (hasLocalAudio)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MODIFIED: Enhanced audio playback with local storage support
  Future<void> _playMessageAudio(ChatMessage msg) async {
    if (_currentlyPlayingMessageId == msg.id && isPlaying) {
      // Stop if already playing
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await audioService.stop();
    } else {
      // Stop any currently playing audio
      if (isPlaying) {
        await audioService.stop();
      }

      // Play this message - try local audio first
      await _playLocalAudio(msg);
    }
  }

  @override
  void dispose() {
    _recordingTimer.cancel();
    ttsService.stop();
    speechService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header - UPDATED: Added profile icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateToWelcome,
                    tooltip: 'ಹಿಂದೆ',
                  ),
                  const Text('ಧ್ವನಿ ಸಹಾಯಕ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      // ADDED: Profile icon to navigate to dashboard
                      IconButton(
                        icon: const Icon(Icons.person),
                        onPressed: _navigateToDashboard,
                        tooltip: 'ಪ್ರೊಫೈಲ್',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _handleClearData,
                        tooltip: 'ಚಾಟ್ ಅಳಿಸಿ',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: messages.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ಸಂಭಾಷಣೆ ಪ್ರಾರಂಭಿಸಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ'),
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

            // Recording/Input Area - FIXED: Added constraints
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text('ಪ್ರಕ್ರಿಯೆಗೊಳಿಸುತ್ತಿದೆ...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FIXED RECORDING UI - NO OVERFLOW AND NO DEPRECATION
  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          // Recording Header - FIXED: Use constraints to prevent overflow
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ರೆಕಾರ್ಡಿಂಗ್... ${_recordingDuration.inSeconds}ಸೆ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Voice Message Bubble (Center) - FIXED: Constrained width
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Waveform Animation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final height = 20 + (DateTime.now().millisecond % 30);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 6,
                      height: height.toDouble(),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                // FIXED: Use Flexible to prevent text overflow
                Flexible(
                  child: Text(
                    _currentTranscript ?? 'ನಿಮ್ಮ ಸಂದೇಶ ರೆಕಾರ್ಡ್ ಆಗುತ್ತಿದೆ...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons (Delete - Send) - FIXED: Use constraints and wrap in container
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Delete Button (Left)
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, size: 20),
                      label: const FittedBox(
                        child: Text('ಅಳಿಸಿ', style: TextStyle(fontSize: 14)),
                      ),
                      onPressed: _deleteRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send Button (Right)
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send, size: 20),
                      label: const FittedBox(
                        child: Text('ಕಳುಹಿಸಿ', style: TextStyle(fontSize: 14)),
                      ),
                      onPressed: _currentTranscript != null ? () => _sendMessage(_currentTranscript!) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FIXED NORMAL UI - NO OVERFLOW AND NO DEPRECATION
  Widget _buildNormalUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _startRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_none, size: 24, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    // FIXED: Use Flexible to prevent text overflow
                    Flexible(
                      child: Text(
                        'ಸಂದೇಶ ರೆಕಾರ್ಡ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ...',
                        style: TextStyle(
                          fontSize: 14, // Slightly smaller font
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Recording button - FIXED: Slightly smaller to fit better
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF00796B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 121, 107, 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.mic, size: 24, color: Colors.white),
              onPressed: _startRecording,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}