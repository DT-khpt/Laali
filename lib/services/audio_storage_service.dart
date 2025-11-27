import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AudioStorageService {
  static final AudioStorageService _instance = AudioStorageService._internal();
  factory AudioStorageService() => _instance;
  AudioStorageService._internal();

  // ADD USER-SPECIFIC PATHS
  Future<String> _getUserAudioDirectory(String? userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final userFolder = userId ?? 'anonymous';
    return '${directory.path}/audio_responses/$userFolder';
  }

  Future<String?> saveAudioLocally(Uint8List audioBytes, String messageId, {String? userId}) async {
    try {
      final audioDirPath = await _getUserAudioDirectory(userId);
      final audioDir = Directory(audioDirPath);

      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final filePath = '$audioDirPath/$messageId.mp3';
      final file = File(filePath);

      await file.writeAsBytes(audioBytes);
      debugPrint('✅ Audio saved locally for user $userId: $filePath');

      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving audio locally: $e');
      return null;
    }
  }

  Future<Uint8List?> getLocalAudioBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error reading local audio bytes: $e');
      return null;
    }
  }

  Future<bool> audioFileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('❌ Error checking audio file existence: $e');
      return false;
    }
  }

  // In your audio_storage_service.dart file, add this method:

  Future<void> clearAllAudioFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio_files');

      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        debugPrint('✅ All audio files cleared successfully');
      }
    } catch (e) {
      debugPrint('❌ Error clearing audio files: $e');
      throw Exception('Failed to clear audio files: $e');
    }
  }

  Future<void> cleanupOldAudioFiles({String? userId, int keepLastDays = 30}) async {
    try {
      final audioDirPath = await _getUserAudioDirectory(userId);
      final audioDir = Directory(audioDirPath);

      if (await audioDir.exists()) {
        final files = await audioDir.list().toList();
        final cutoffDate = DateTime.now().subtract(Duration(days: keepLastDays));

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
              debugPrint('🧹 Cleaned up old audio file for user $userId: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up audio files: $e');
    }
  }

  // Clean up ALL user audio files (when user account is deleted)
  Future<void> cleanupUserAudioFiles(String userId) async {
    try {
      final audioDirPath = await _getUserAudioDirectory(userId);
      final audioDir = Directory(audioDirPath);

      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        debugPrint('✅ Deleted all audio files for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up user audio files: $e');
    }
  }
}