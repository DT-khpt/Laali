import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../chat_message.dart';

class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  static const String _chatHistoryKey = 'chat_history';
  static const int _maxMessages = 100;

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Keep only the latest messages to avoid storage issues
      final recentMessages = messages.length > _maxMessages
          ? messages.sublist(messages.length - _maxMessages)
          : messages;

      final messagesJson = recentMessages.map((msg) => msg.toJson()).toList();
      await prefs.setString(_chatHistoryKey, jsonEncode(messagesJson));
      debugPrint('✅ Chat history saved: ${recentMessages.length} messages');
    } catch (e) {
      debugPrint('❌ Error saving chat history: $e');
    }
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatHistoryJson = prefs.getString(_chatHistoryKey);

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

        debugPrint('✅ Chat history loaded: ${loadedMessages.length} messages');
        return loadedMessages;
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history: $e');
    }

    return [];
  }

  Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
      debugPrint('✅ Chat history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing chat history: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final messages = await loadChatHistory();
      final updatedMessages = messages.where((msg) => msg.id != messageId).toList();
      await saveChatHistory(updatedMessages);
      debugPrint('✅ Message deleted: $messageId');
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
    }
  }
}