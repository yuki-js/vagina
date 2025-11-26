import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// Service for playing audio
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;
  bool _isProcessing = false;

  bool get isPlaying => _isPlaying;

  /// Add PCM audio data to the playback queue
  void addAudioData(Uint8List pcmData) {
    _audioQueue.add(pcmData);
    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _isPlaying = true;

    while (_audioQueue.isNotEmpty) {
      // Remove the audio chunk from queue
      _audioQueue.removeAt(0);
      
      // TODO: In production, implement proper PCM to playable audio conversion
      // For now, this is a placeholder that processes the queue without blocking
      // Real implementation would:
      // 1. Convert PCM16 to WAV or use a streaming audio source
      // 2. Play the audio chunk
      // 3. Wait for playback completion before processing next chunk
      
      // Simulate minimal processing delay to prevent busy loop
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    _isPlaying = false;
    _isProcessing = false;
  }

  /// Stop all playback and clear queue
  Future<void> stop() async {
    _audioQueue.clear();
    _isPlaying = false;
    _isProcessing = false;
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
