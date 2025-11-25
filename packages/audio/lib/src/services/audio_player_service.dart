import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// Service for playing audio
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Add PCM audio data to the playback queue
  void addAudioData(Uint8List pcmData) {
    _audioQueue.add(pcmData);
    if (!_isPlaying) {
      _playNextInQueue();
    }
  }

  Future<void> _playNextInQueue() async {
    if (_audioQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    // Note: In production, convert PCM to playable format
    // This is a placeholder for the audio streaming implementation
    _audioQueue.removeAt(0);
    await _playNextInQueue();
  }

  /// Stop all playback and clear queue
  Future<void> stop() async {
    _audioQueue.clear();
    _isPlaying = false;
    await _player.stop();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Dispose the player
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
