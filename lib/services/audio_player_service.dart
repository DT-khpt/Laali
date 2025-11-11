import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  File? _currentTempFile;

  AudioService() {
    _setupListeners();
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
      _cleanupTempFile();
    });
  }

  Future<void> playAudioBytes(List<int> audioBytes, String contentType) async {
    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();
      await _cleanupTempFile();

      // Enhanced validation
      if (!_isValidAudioData(audioBytes)) {
        throw Exception('Invalid audio data received');
      }

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      _currentTempFile = File('${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3');

      // Write bytes to file
      await _currentTempFile!.writeAsBytes(audioBytes);

      // Set source and play with error handling
      await _audioPlayer.setSource(DeviceFileSource(_currentTempFile!.path));
      await _audioPlayer.resume();

      _isPlaying = true;

    } catch (e) {
      await _cleanupTempFile();
      rethrow;
    }
  }

  bool _isValidAudioData(List<int> bytes) {
    if (bytes.isEmpty || bytes.length < 1024) { // At least 1KB
      return false;
    }

    // Check for common audio file signatures
    return _isValidMp3(bytes) || _isValidWav(bytes) || _isValidOgg(bytes);
  }

  bool _isValidMp3(List<int> bytes) {
    if (bytes.length < 3) return false;

    // MP3 with ID3 tag
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return true;
    }

    // MPEG audio frame
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return true;
    }

    return false;
  }

  bool _isValidWav(List<int> bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46;
  }

  bool _isValidOgg(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
  }

  Future<void> _cleanupTempFile() async {
    try {
      if (_currentTempFile != null && await _currentTempFile!.exists()) {
        await _currentTempFile!.delete();
      }
      _currentTempFile = null;
    } catch (e) {
      // Silent cleanup
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