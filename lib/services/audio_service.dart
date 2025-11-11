import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  AudioService() {
    _setupListeners();
  }

  void _setupListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
    });
  }

  Future<void> playAudioBytes(List<int> audioBytes, String contentType) async {
    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();

      // Determine file extension
      String fileExtension = _getFileExtension(contentType);

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}$fileExtension');

      // Write bytes to file
      await tempFile.writeAsBytes(audioBytes);

      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));

      _isPlaying = true;

      // Clean up file after playback completes
      _audioPlayer.onPlayerComplete.listen((event) async {
        await tempFile.delete();
      });

    } catch (e) {
      rethrow;
    }
  }

  String _getFileExtension(String contentType) {
    if (contentType.contains('mpeg') || contentType.contains('mp3')) {
      return '.mp3';
    } else if (contentType.contains('wav')) {
      return '.wav';
    } else if (contentType.contains('m4a')) {
      return '.m4a';
    } else if (contentType.contains('ogg')) {
      return '.ogg';
    }
    return '.mp3'; // default
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  bool get isPlaying => _isPlaying;

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}

final audioService = AudioService();