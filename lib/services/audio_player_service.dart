import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'log_service.dart';

/// Service for playing streaming PCM audio from Azure OpenAI Realtime API
/// 
/// Uses flutter_sound's FlutterSoundPlayer with streaming for real-time
/// PCM16 playback at 24kHz mono.
class AudioPlayerService {
  static const _tag = 'AudioPlayer';
  
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamController<Uint8List>? _streamController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  
  // Audio format settings (must match Azure OpenAI Realtime API output)
  // PCM16, 24000Hz, mono
  static const int _sampleRate = 24000;
  static const int _numChannels = 1;

  bool get isPlaying => _isPlaying;

  /// Initialize the audio player for streaming playback
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    
    logService.info(_tag, 'Initializing FlutterSoundPlayer');
    await _player.openPlayer();
    _isInitialized = true;
    logService.info(_tag, 'FlutterSoundPlayer initialized');
  }

  /// Start streaming playback session
  Future<void> startPlayback() async {
    if (_isPlaying) {
      logService.debug(_tag, 'Already playing, skipping start');
      return;
    }
    
    await _ensureInitialized();
    
    logService.info(_tag, 'Starting streaming playback (PCM16, ${_sampleRate}Hz, $_numChannels ch)');
    
    // Create stream controller for feeding audio data
    _streamController = StreamController<Uint8List>();
    
    // Start the player with streaming input
    // Using the newer API without deprecated Food
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: _sampleRate,
      numChannels: _numChannels,
      bufferSize: 8192,
      interleaved: true,
    );
    
    _isPlaying = true;
    logService.info(_tag, 'Streaming playback started');
  }

  /// Add PCM16 audio data for playback
  /// 
  /// The data should be raw PCM16 (16-bit signed integer, little-endian)
  /// at 24000Hz mono, as returned by Azure OpenAI Realtime API.
  Future<void> addAudioData(Uint8List pcmData) async {
    if (pcmData.isEmpty) {
      logService.debug(_tag, 'Received empty audio data, skipping');
      return;
    }
    
    logService.debug(_tag, 'Adding audio data: ${pcmData.length} bytes');
    
    // Start playback if not already started
    if (!_isPlaying) {
      await startPlayback();
    }
    
    // Feed the audio data directly to the player
    try {
      await _player.feedUint8FromStream(pcmData);
      logService.debug(_tag, 'Fed ${pcmData.length} bytes to player');
    } catch (e) {
      logService.error(_tag, 'Error feeding audio: $e');
    }
  }

  /// Mark that the current response is complete
  /// This allows the player to flush any remaining buffered audio
  void markResponseComplete() {
    logService.info(_tag, 'Response marked complete');
    // The streaming will continue until explicitly stopped
    // or until the next response starts
  }

  /// Stop playback and clear any buffered audio
  Future<void> stop() async {
    logService.info(_tag, 'Stopping playback');
    
    _isPlaying = false;
    
    // Close stream controller
    await _streamController?.close();
    _streamController = null;
    
    // Stop the player
    if (_isInitialized) {
      try {
        await _player.stopPlayer();
      } catch (e) {
        logService.warn(_tag, 'Error stopping player: $e');
      }
    }
    
    logService.info(_tag, 'Playback stopped');
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_isInitialized) {
      await _player.setVolume(volume);
    }
  }

  /// Dispose the player and release resources
  Future<void> dispose() async {
    logService.info(_tag, 'Disposing AudioPlayerService');
    await stop();
    
    if (_isInitialized) {
      try {
        await _player.closePlayer();
      } catch (e) {
        logService.warn(_tag, 'Error closing player: $e');
      }
      _isInitialized = false;
    }
    
    logService.info(_tag, 'AudioPlayerService disposed');
  }
}
