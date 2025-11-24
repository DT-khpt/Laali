import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AudioStorageService {
  static final AudioStorageService _instance = AudioStorageService._internal();
  factory AudioStorageService() => _instance;
  AudioStorageService._internal();

  Future<String?> saveAudioLocally(Uint8List audioBytes, String messageId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio_responses');

      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final filePath = '${audioDir.path}/$messageId.mp3';
      final file = File(filePath);

      await file.writeAsBytes(audioBytes);
      debugPrint('✅ Audio saved locally: $filePath');

      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving audio locally: $e');
      return null;
    }
  }

  Future<File?> getLocalAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting local audio file: $e');
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

  Future<void> deleteLocalAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Audio file deleted: $filePath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting audio file: $e');
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

  Future<void> cleanupOldAudioFiles({int keepLastDays = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio_responses');

      if (await audioDir.exists()) {
        final files = await audioDir.list().toList();
        final cutoffDate = DateTime.now().subtract(Duration(days: keepLastDays));

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
              debugPrint('🧹 Cleaned up old audio file: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up audio files: $e');
    }
  }

  Future<int> getAudioCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio_responses');

      if (await audioDir.exists()) {
        final files = await audioDir.list().toList();
        int totalSize = 0;

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            totalSize += stat.size;
          }
        }
        return totalSize;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error calculating audio cache size: $e');
      return 0;
    }
  }
}