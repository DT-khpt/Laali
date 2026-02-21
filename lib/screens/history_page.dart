import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio_player_service.dart' show audioService;
import '../models/chat_message.dart';
import '../../services/chat_history_service.dart';
import '../../services/audio_storage_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ChatMessage> chatHistory = [];
  bool isLoading = true;
  String? _currentlyPlayingMessageId;
  bool isPlaying = false;

  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  final AudioStorageService _audioStorage = AudioStorageService();

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMode = prefs.getString('userMode');

      // Only load history for account users
      if (userMode == 'account') {
        final history = await _chatHistoryService.loadChatHistory();

        // Verify audio files exist
        final List<ChatMessage> verifiedMessages = [];
        for (var message in history) {
          if (message.localAudioPath != null) {
            final exists = await _audioStorage.audioFileExists(message.localAudioPath!);
            if (!exists) {
              message = message.copyWith(localAudioPath: null, audioBytes: null);
            }
          }
          verifiedMessages.add(message);
        }

        setState(() {
          chatHistory = verifiedMessages;
          isLoading = false;
        });
      } else {
        setState(() {
          chatHistory = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _playAudio(ChatMessage message) async {
    if (_currentlyPlayingMessageId == message.id && isPlaying) {
      // Stop if already playing
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      await audioService.stop();
      return;
    }

    try {
      setState(() {
        isPlaying = true;
        _currentlyPlayingMessageId = message.id;
      });

      if (message.audioBytes != null) {
        await audioService.playAudioBytes(message.audioBytes!, 'audio/mpeg');
      } else if (message.localAudioPath != null) {
        final audioBytes = await _audioStorage.getLocalAudioBytes(message.localAudioPath!);
        if (audioBytes != null) {
          await audioService.playAudioBytes(audioBytes, 'audio/mpeg');
        } else {
          throw Exception('Audio file not found');
        }
      } else {
        throw Exception('No audio available');
      }

      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
    } catch (e) {
      debugPrint('Audio playback error: $e');
      setState(() {
        isPlaying = false;
        _currentlyPlayingMessageId = null;
      });

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ಆಡಿಯೋ ಪ್ಲೇಬ್ಯಾಕ್ ಸಾಧ್ಯವಾಗಲಿಲ್ಲ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistoryItem(ChatMessage message, int index) {
    final isUser = message.isUser;
    final isCurrentlyPlaying = _currentlyPlayingMessageId == message.id && isPlaying;
    final hasAudio = message.localAudioPath != null || message.audioBytes != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and time
            Row(
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 20,
                  color: isUser ? const Color(0xFF00796B) : const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 8),
                Text(
                  isUser ? 'ನೀವು' : 'ಸಹಾಯಕ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUser ? const Color(0xFF00796B) : const Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(message.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message content
            Text(
              message.content,
              style: const TextStyle(fontSize: 14),
            ),

            // Audio player for AI responses with audio
            if (!isUser && hasAudio) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFF00796B),
                      ),
                      onPressed: () => _playAudio(message),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ಆಡಿಯೋ ಪ್ರತಿಕ್ರಿಯೆ',
                        style: TextStyle(
                          color: Color(0xFF00796B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isCurrentlyPlaying)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00796B),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Video suggestion if available
            if (message.videoUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1976D2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.video_library, color: Color(0xFF1976D2), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.videoTitle ?? 'ವೀಡಿಯೊ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ಸಲಹೆ ನೀಡಲಾದ ವೀಡಿಯೊ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ಚಾಟ್ ಇತಿಹಾಸ'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00796B)),
            SizedBox(height: 16),
            Text('ಲೋಡ್ ಆಗುತ್ತಿದೆ...'),
          ],
        ),
      )
          : chatHistory.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ಯಾವುದೇ ಚಾಟ್ ಇತಿಹಾಸ ಲಭ್ಯವಿಲ್ಲ',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: chatHistory.length,
        itemBuilder: (context, index) {
          return _buildHistoryItem(chatHistory[index], index);
        },
      ),
    );
  }

  @override
  void dispose() {
    audioService.stop();
    super.dispose();
  }
}