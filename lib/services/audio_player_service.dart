import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  File? _currentTempFile;

  AudioService() {
    _setupListeners();
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      debugPrint('🎵 AudioPlayer State: $state');
      _isPlaying = state == PlayerState.playing;
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      debugPrint('🎵 AudioPlayer: Playback complete');
      _isPlaying = false;
      _cleanupTempFile();
    });

    _audioPlayer.onLog.listen((log) {
      debugPrint('🎵 AudioPlayer Log: $log');
    });
  }

  Future<void> playAudioBytes(List<int> audioBytes, String contentType) async {
    try {
      debugPrint('🎵 AudioService: Playing ${audioBytes.length} bytes, Type: $contentType');

      // Stop any currently playing audio
      await _audioPlayer.stop();
      await _cleanupTempFile();

      if (audioBytes.isEmpty) {
        debugPrint('⚠️ AudioService: Received empty bytes');
        return;
      }

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      _currentTempFile = File('${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3');

      // Write bytes to file
      await _currentTempFile!.writeAsBytes(audioBytes);
      debugPrint('🎵 AudioService: Saved to temp file: ${_currentTempFile!.path}');

      // Set source and play
      await _audioPlayer.play(DeviceFileSource(_currentTempFile!.path));

      _isPlaying = true;
      debugPrint('🎵 AudioService: Playback started');

    } catch (e) {
      debugPrint('❌ AudioService Error: $e');
      await _cleanupTempFile();
      rethrow;
    }
  }

  Future<void> _cleanupTempFile() async {
    try {
      if (_currentTempFile != null && await _currentTempFile!.exists()) {
        await _currentTempFile!.delete();
        debugPrint('🎵 AudioService: Temp file deleted');
      }
      _currentTempFile = null;
    } catch (e) {
      debugPrint('⚠️ AudioService: Cleanup error: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    await _cleanupTempFile();
  }

  bool get isPlaying => _isPlaying;

  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _cleanupTempFile();
  }
}

final audioService = AudioService();