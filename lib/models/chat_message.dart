import 'dart:typed_data';
import 'dart:convert';

class ChatMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isUser;
  final String? audioUrl;
  final String? videoUrl;
  final String? videoTitle;
  final String? localAudioPath;
  final Uint8List? audioBytes;

  ChatMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isUser,
    this.audioUrl,
    this.videoUrl,
    this.videoTitle,
    this.localAudioPath,
    this.audioBytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
      'videoTitle': videoTitle,
      'localAudioPath': localAudioPath,
      'audioBytes': audioBytes != null ? base64.encode(audioBytes!) : null,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isUser: json['isUser'],
      audioUrl: json['audioUrl'],
      videoUrl: json['videoUrl'],
      videoTitle: json['videoTitle'],
      localAudioPath: json['localAudioPath'],
      audioBytes: json['audioBytes'] != null
          ? base64.decode(json['audioBytes'])
          : null,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    bool? isUser,
    String? audioUrl,
    String? videoUrl,
    String? videoTitle,
    String? localAudioPath,
    Uint8List? audioBytes,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isUser: isUser ?? this.isUser,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      audioBytes: audioBytes ?? this.audioBytes,
    );
  }
}