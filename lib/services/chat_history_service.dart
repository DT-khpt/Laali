// lib/services/chat_history_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/chat_message.dart';
import 'firebase_service.dart';

class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    try {
      // Save locally
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = await _firebaseService.getCurrentUserAccountId();
      final userKey = 'chat_history_${currentUserId ?? 'local'}';

      final messagesJson = messages.map((msg) => msg.toJson()).toList();
      await prefs.setString(userKey, jsonEncode(messagesJson));

      // Save to Firebase if user is logged in and has account
      if (currentUserId != null) {
        for (final message in messages) {
          await _firebaseService.saveChatMessage(
            messageId: message.id,
            content: message.content,
            isUser: message.isUser,
            audioPath: message.localAudioPath,
            videoUrl: message.videoUrl,
            videoTitle: message.videoTitle,
          );
        }
      }

      debugPrint('✅ Chat history saved for user: $currentUserId');
    } catch (e) {
      debugPrint('❌ Error saving chat history: $e');
    }
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = await _firebaseService.getCurrentUserAccountId();
      final userKey = 'chat_history_${currentUserId ?? 'local'}';

      // Try to load from Firebase first for account users
      if (currentUserId != null) {
        try {
          final firebaseMessages = await _firebaseService.getChatHistory();
          if (firebaseMessages.isNotEmpty) {
            final List<ChatMessage> loadedMessages = [];

            for (final messageData in firebaseMessages) {
              loadedMessages.add(ChatMessage(
                id: messageData['id'] ?? '',
                content: messageData['content'] ?? '',
                timestamp: messageData['timestamp'] ?? DateTime.now(),
                isUser: messageData['is_user'] ?? false,
                audioUrl: null,
                localAudioPath: messageData['audio_path'],
                audioBytes: null,
                videoUrl: messageData['video_url'],
                videoTitle: messageData['video_title'],
              ));
            }

            debugPrint('✅ Loaded ${loadedMessages.length} messages from Firebase');
            return loadedMessages;
          }
        } catch (e) {
          debugPrint('❌ Error loading from Firebase, falling back to local: $e');
        }
      }

      // Fallback to local storage
      final chatHistoryJson = prefs.getString(userKey);
      if (chatHistoryJson != null) {
        final List<dynamic> messagesData = jsonDecode(chatHistoryJson);
        final List<ChatMessage> loadedMessages = [];

        for (final messageData in messagesData) {
          try {
            loadedMessages.add(ChatMessage.fromJson(messageData));
          } catch (e) {
            debugPrint('❌ Error parsing message: $e');
          }
        }

        debugPrint('✅ Chat history loaded from local: ${loadedMessages.length} messages');
        return loadedMessages;
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history: $e');
    }

    return [];
  }

  Future<void> clearChatHistory() async {
    try {
      final currentUserId = await _firebaseService.getCurrentUserAccountId();

      // Clear from Firebase
      if (currentUserId != null) {
        await _firebaseService.clearChatHistory();
      }

      // Clear locally
      final prefs = await SharedPreferences.getInstance();
      final userKey = 'chat_history_${currentUserId ?? 'local'}';
      await prefs.remove(userKey);

      debugPrint('✅ Chat history cleared for user: $currentUserId');
    } catch (e) {
      debugPrint('❌ Error clearing chat history: $e');
    }
  }
}