import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mcp/config/routes.dart';
import 'package:mcp/services/audio_player_service.dart' show audioService;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../../services/tts_service.dart';
import '../../services/speech_service.dart';
import '../../services/audio_storage_service.dart';
import '../../services/chat_history_service.dart';
import '../../data/video_database.dart';
import 'dashboard.dart';
import 'voice_signup_page.dart';
import 'history_page.dart';

class VoiceInterfacePage extends StatefulWidget {
  const VoiceInterfacePage({super.key});

  @override
  State<VoiceInterfacePage> createState() => _VoiceInterfacePageState();
}

class _VoiceInterfacePageState extends State<VoiceInterfacePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isRecording = false;
  bool isPlaying = false;
  bool isLoadingAI = false;
  bool isSpeaking = false;
  String? userMode;
  String? username;
  String? _currentlyPlayingMessageId;

  // Audio playback state
  bool _isAudioPaused = false;
  Uint8List? _currentAudioData;
  String? _currentAudioContentType;

  // Recording state
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;
  String? _currentTranscript;
  String? _finalTranscript;

  final AudioStorageService _audioStorage = AudioStorageService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();

  static const String n8nWebhookUrl = 'https://davida-gawkier-invigoratingly.ngrok-free.dev/webhook/user-message';
  static const Duration n8nResponseTimeout = Duration(seconds: 300);

  // NEW: Colors
  static const Color greenColor = Color(0xFF037E57);
  static const Color blueColor = Color(0xFF043249);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _initTts();
    _loadUserData();
    _addWelcomeMessage();
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
      setState(() => messages.addAll(localMessages));
    } catch (e) { debugPrint('History load error: $e'); }
  }

  Future<void> _saveChatHistory() async => await _chatHistoryService.saveChatHistory(messages);

  void _addWelcomeMessage() {
    if (messages.isEmpty) {
      final welcomeMsg = ChatMessage(
        id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
        content: 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಸಮಸ್ಯೆಗಳನ್ನು ಹೇಳಿ ಅಥವಾ ಪ್ರಶ್ನೆ ಕೇಳಿ.',
        timestamp: DateTime.now(),
        isUser: false,
      );
      setState(() => messages.add(welcomeMsg));
      _speak(welcomeMsg.content);
    }
  }

  Future<void> _initTts() async {
    await ttsService.setLanguage('kn-IN');
    await ttsService.setSpeechRate(0.4);
  }

  Future<void> _speak(String text) async {
    setState(() => isSpeaking = true);
    await ttsService.speak(text);
    setState(() => isSpeaking = false);
  }

  void _startRecording() async {
    final ok = await speechService.initialize();
    if (!ok) return;
    setState(() { isRecording = true; _recordingDuration = Duration.zero; _pulseController.repeat(); });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => _recordingDuration += const Duration(seconds: 1)));
    await speechService.startListeningWithRetry((text, isFinal) {
      setState(() { _currentTranscript = text; if (isFinal) _finalTranscript = text; });
    }, localeId: 'kn-IN');
  }

  void _stopRecording() {
    _recordingTimer.cancel();
    speechService.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => isRecording = false);
  }

  void _deleteRecording() {
    _stopRecording();
    setState(() { _currentTranscript = null; _finalTranscript = null; });
  }

  void _sendRecording() {
    final text = _finalTranscript ?? _currentTranscript;
    if (text != null && text.isNotEmpty) {
      _sendMessage(text);
      _deleteRecording();
    }
  }

  void _sendMessage(String transcript) async {
    final userMsg = ChatMessage(id: 'user_${DateTime.now().millisecondsSinceEpoch}', content: transcript, timestamp: DateTime.now(), isUser: true);
    setState(() => messages.add(userMsg));
    _scrollToBottom();
    await _saveChatHistory();
    setState(() => isLoadingAI = true);
    try {
      final res = await http.post(Uri.parse(n8nWebhookUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'userMessage': transcript, 'timestamp': DateTime.now().toIso8601String()})).timeout(n8nResponseTimeout);
      await _handleN8NResponse(res, transcript);
    } catch (e) { debugPrint('N8N Error: $e'); } finally { setState(() => isLoadingAI = false); _scrollToBottom(); }
  }

  Future<void> _handleN8NResponse(http.Response res, String userMsg) async {
    final contentType = res.headers['content-type']?.toLowerCase() ?? '';
    debugPrint('📥 Response Content-Type: $contentType');

    if (contentType.contains('application/json') || _looksLikeJson(res.bodyBytes)) {
      await _handleJsonResponse(res, userMsg);
    } else if (contentType.contains('audio/')) {
      await _playAudioFromBytes(res.bodyBytes, contentType, userMsg);
    } else {
      debugPrint('⚠️ Unknown response format received');
      // If we can't determine, try to see if it's JSON anyway
      try {
        await _handleJsonResponse(res, userMsg);
      } catch (e) {
        debugPrint('❌ Error parsing unknown response: $e');
      }
    }
  }

  bool _looksLikeJson(List<int> bytes) {
    if (bytes.isEmpty) return false;
    final firstChar = String.fromCharCode(bytes[0]);
    return firstChar == '{' || firstChar == '[';
  }

  Future<void> _handleJsonResponse(http.Response res, String userMsg) async {
    final String body = utf8.decode(res.bodyBytes, allowMalformed: true);
    debugPrint('📥 JSON Response received: $body');
    
    final data = jsonDecode(body);
    final Map? dataMap = data is List ? (data.isNotEmpty ? data.first : null) : data;
    
    if (dataMap != null) {
      await _handleVideoAudioResponse(dataMap, userMsg);
    } else {
      debugPrint('⚠️ Empty or invalid JSON data');
    }
  }

  Future<void> _handleVideoAudioResponse(Map data, String userMsg) async {
    String? audio = data['audioContent']?.toString() ?? data['audio_content']?.toString();
    
    // Deeper check for nested structures if needed
    if (audio == null && data['pipelineResponse'] != null) {
      try { audio = data['pipelineResponse'][0]['audio'][0]['audioContent']; } catch (_) {}
    }

    String? videoUrl = data['video_url']?.toString() ?? data['video']?.toString();
    if (data['video'] is Map) {
      videoUrl = data['video']['url']?.toString() ?? data['video']['video_url']?.toString();
    }
    String? videoTitle = data['video_title']?.toString() ?? data['title']?.toString() ?? 'ಸಂಬಂಧಿತ ವೀಡಿಯೊ';

    if (audio != null && audio.isNotEmpty) {
      debugPrint('🔈 Playing audio from JSON content...');
      final cleaned = audio.replaceAll(RegExp(r'data:audio/[^;]+;base64,'), '').replaceAll(RegExp(r'\s+'), '');
      await _playAudioFromBytes(
        base64.decode(cleaned), 
        'audio/mpeg', 
        userMsg,
        videoUrl: videoUrl,
        videoTitle: videoTitle,
      );
    } else {
      final text = data['text']?.toString() ?? data['output']?.toString() ?? data['message']?.toString() ?? '';
      if (text.isNotEmpty) {
        final aiMsg = ChatMessage(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}', 
          content: text, 
          timestamp: DateTime.now(), 
          isUser: false,
          videoUrl: videoUrl,
          videoTitle: videoTitle,
        );
        setState(() => messages.add(aiMsg));
        _scrollToBottom();
        await _speak(text);
      }
    }
    
    // If no audio or text was found, but there is a video, suggest it explicitly
    if (audio == null && (data['text'] == null && data['output'] == null) && videoUrl != null) {
      await _addVideoSuggestionFromN8N(data);
    }
  }

  Future<void> _addVideoSuggestionFromN8N(Map data) async {
    String? url = data['video_url']?.toString() ?? data['video']?.toString();
    if (data['video'] is Map) url = data['video']['url']?.toString();
    if (url != null && url.startsWith('http')) {
      final videoMsg = ChatMessage(id: 'vid_${DateTime.now().millisecondsSinceEpoch}', content: 'ವೀಡಿಯೊ ನೋಡಿ:', timestamp: DateTime.now(), isUser: false, videoUrl: url, videoTitle: data['video_title']?.toString() ?? 'ಸಂಬಂಧಿತ ವೀಡಿಯೊ');
      setState(() => messages.add(videoMsg));
      _scrollToBottom();
      await _saveChatHistory();
    }
  }

  Future<void> _playAudioFromBytes(List<int> bytes, String type, String userMsg, {String? videoUrl, String? videoTitle}) async {
    try {
      final id = 'audio_${DateTime.now().millisecondsSinceEpoch}';
      
      final msg = ChatMessage(
        id: id,
        content: 'ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ',
        timestamp: DateTime.now(),
        isUser: false,
        audioBytes: Uint8List.fromList(bytes),
        videoUrl: videoUrl,
        videoTitle: videoTitle,
      );

      setState(() {
        messages.add(msg);
        isPlaying = true;
        _currentlyPlayingMessageId = id;
        _currentAudioData = msg.audioBytes;
        _currentAudioContentType = type;
        _isAudioPaused = false;
      });
      _scrollToBottom();

      _audioStorage.saveAudioLocally(msg.audioBytes!, id).then((path) {
        final index = messages.indexWhere((m) => m.id == id);
        if (index != -1) {
          setState(() {
            messages[index] = messages[index].copyWith(localAudioPath: path);
          });
        }
      });

      await audioService.playAudioBytes(bytes, type);
    } catch (e) {
      debugPrint('Playback Error: $e');
    } finally {
      if (mounted) {
        setState(() { isPlaying = false; });
      }
      await _saveChatHistory();
    }
  }

  Future<void> _pauseResumeAudio(ChatMessage msg) async {
    if (_currentlyPlayingMessageId == msg.id) {
      if (isPlaying && !_isAudioPaused) {
        await audioService.stop();
        setState(() => _isAudioPaused = true);
      } else {
        setState(() { isPlaying = true; _isAudioPaused = false; });
        if(msg.audioBytes != null) await audioService.playAudioBytes(msg.audioBytes!, 'audio/mpeg');
        setState(() => isPlaying = false);
      }
    } else {
      if (isPlaying) await audioService.stop();
      _playLocalAudio(msg);
    }
  }

  Future<void> _playLocalAudio(ChatMessage msg) async {
    final bytes = msg.audioBytes ?? (msg.localAudioPath != null ? await _audioStorage.getLocalAudioBytes(msg.localAudioPath!) : null);
    if (bytes != null) {
      setState(() { isPlaying = true; _currentlyPlayingMessageId = msg.id; _isAudioPaused = false; });
      await audioService.playAudioBytes(bytes, 'audio/mpeg');
      setState(() => isPlaying = false);
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); });

  @override
  void dispose() { _pulseController.dispose(); _recordingTimer.cancel(); audioService.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: blueColor,
        title: const Text('ಧ್ವನಿ ಸಹಾಯಕ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: () => setState(() => messages.clear())),
          IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const HistoryPage()))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty 
              ? const Center(child: Text('ಪ್ರಶ್ನೆ ಕೇಳಲು ಮೈಕ್ರೊಫೋನ್ ಟ್ಯಾಪ್ ಮಾಡಿ')) 
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (isLoadingAI ? 1 : 0),
                  itemBuilder: (c, i) => i == messages.length 
                    ? const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())) 
                    : _buildMessageBubble(messages[i]),
                ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isAudio = msg.audioBytes != null || msg.localAudioPath != null;
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: msg.isUser ? greenColor : blueColor, borderRadius: BorderRadius.circular(20)),
            child: isAudio ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_currentlyPlayingMessageId == msg.id && isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () => _pauseResumeAudio(msg),
                ),
                const Text('ಧ್ವನಿ ಪ್ರತಿಕ್ರಿಯೆ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ) : Text(msg.content, style: const TextStyle(color: Colors.white)),
          ),
          if (msg.videoUrl != null) GestureDetector(
            onTap: () => showDialog(context: context, builder: (c) => AlertDialog(title: Text(msg.videoTitle ?? 'ವೀಡಿಯೊ'), content: SelectableText(msg.videoUrl!))),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade800, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(msg.videoTitle ?? 'ವೀಡಿಯೊ ನೋಡಿ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() => Container(
    padding: const EdgeInsets.all(20),
    color: Colors.white,
    child: isRecording ? Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 32), onPressed: () => _deleteRecording()),
        Text('${_recordingDuration.inSeconds}ಸೆ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
        IconButton(icon: const Icon(Icons.send, color: greenColor, size: 32), onPressed: () => _sendRecording()),
      ],
    ) : Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isRecording) FadeTransition(opacity: _opacityAnimation, child: ScaleTransition(scale: _scaleAnimation, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: greenColor.withOpacity(0.3))))),
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: greenColor, shape: BoxShape.circle),
                child: const Icon(Icons.mic, size: 40, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('ಮಾತನಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ', style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}
