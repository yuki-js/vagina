import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'log_service.dart';

/// Service for playing streaming PCM audio from Azure OpenAI Realtime API
/// 
/// Uses flutter_sound's FlutterSoundPlayer with streaming for real-time
/// PCM16 playback at 24kHz mono.
/// 
/// This implementation uses a queue-based approach to safely feed audio data
/// to the native player without race conditions.
class AudioPlayerService {
  static const _tag = 'AudioPlayer';
  
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isStartingPlayback = false;
  bool _isDisposed = false;
  
  // Audio buffer queue to prevent race conditions
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isProcessingQueue = false;
  Completer<void>? _processingCompleter;
  
  // Audio format settings (must match Azure OpenAI Realtime API output)
  // PCM16, 24000Hz, mono
  static const int _sampleRate = 24000;
  static const int _numChannels = 1;
  
  // Buffer settings
  static const int _minBufferSizeBeforeStart = 4800; // ~100ms of audio at 24kHz mono 16-bit
  
  // Delay settings for setSpeed workaround
  // These delays are needed to work around a timing bug in flutter_sound where
  // onPrepared() is called before audioTrack.play() completes.
  static const Duration _speedApplyDelayAfterFeed = Duration(milliseconds: 50);
  static const Duration _speedApplyDelayDuringPlayback = Duration(milliseconds: 30);
  
  // Playback speed setting (stored to apply when playback starts)
  double _playbackSpeed = 1.0;
  
  // Track if speed has been applied after first data feed
  // This is needed because setSpeed may not work immediately after startPlayerFromStream
  // due to a timing issue in flutter_sound where onPrepared() is called before play()
  bool _speedAppliedAfterFirstFeed = false;

  bool get isPlaying => _isPlaying;

  /// Initialize the audio player for streaming playback
  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isDisposed) return;
    
    logService.info(_tag, 'Initializing FlutterSoundPlayer');
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    _isInitialized = true;
    logService.info(_tag, 'FlutterSoundPlayer initialized');
  }

  /// Start streaming playback session
  Future<void> _startPlayback() async {
    if (_isPlaying || _isStartingPlayback || _isDisposed) {
      logService.debug(_tag, 'Already playing or starting, skipping start');
      return;
    }
    
    _isStartingPlayback = true;
    
    try {
      await _ensureInitialized();
      
      if (_player == null || _isDisposed) {
        logService.warn(_tag, 'Player not available, cannot start playback');
        return;
      }
      
      logService.info(_tag, 'Starting streaming playback (PCM16, ${_sampleRate}Hz, $_numChannels ch)');
      
      // Start the player with streaming input
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        bufferSize: 8192,
        interleaved: true,
      );
      
      _isPlaying = true;
      logService.info(_tag, 'Streaming playback started');
      
      // Reset speed tracking for new playback session
      _speedAppliedAfterFirstFeed = false;
      
      // Note: We don't apply speed immediately here anymore.
      // Due to a timing bug in flutter_sound (onPrepared is called before play()),
      // setSpeed may not work reliably right after startPlayerFromStream returns.
      // Instead, we apply speed after the first data feed in _processAudioQueue().
    } catch (e) {
      logService.error(_tag, 'Error starting playback: $e');
      _isPlaying = false;
    } finally {
      _isStartingPlayback = false;
    }
  }

  /// Add PCM16 audio data for playback
  /// 
  /// The data should be raw PCM16 (16-bit signed integer, little-endian)
  /// at 24000Hz mono, as returned by Azure OpenAI Realtime API.
  Future<void> addAudioData(Uint8List pcmData) async {
    if (pcmData.isEmpty || _isDisposed) {
      logService.debug(_tag, 'Received empty audio data or disposed, skipping');
      return;
    }
    
    logService.debug(_tag, 'Queueing audio data: ${pcmData.length} bytes');
    
    // Add to queue
    _audioQueue.add(pcmData);
    
    // Process queue
    await _processAudioQueue();
  }
  
  /// Process queued audio data safely
  Future<void> _processAudioQueue() async {
    // Prevent concurrent queue processing
    if (_isProcessingQueue || _isDisposed) {
      return;
    }
    
    _isProcessingQueue = true;
    _processingCompleter = Completer<void>();
    
    try {
      // Start playback if not yet started and we have enough buffered data
      if (!_isPlaying && !_isStartingPlayback) {
        int totalBuffered = _audioQueue.fold(0, (sum, chunk) => sum + chunk.length);
        if (totalBuffered >= _minBufferSizeBeforeStart) {
          await _startPlayback();
        } else {
          logService.debug(_tag, 'Waiting for more data before starting: $totalBuffered bytes buffered');
          _isProcessingQueue = false;
          _processingCompleter?.complete();
          return;
        }
      }
      
      // Process all queued audio
      while (_audioQueue.isNotEmpty && _isPlaying && !_isDisposed) {
        final chunk = _audioQueue.removeFirst();
        
        try {
          if (_player != null && _isPlaying) {
            await _player!.feedUint8FromStream(chunk);
            logService.debug(_tag, 'Fed ${chunk.length} bytes to player');
            
            // Apply playback speed after first successful data feed
            // This workaround is needed because flutter_sound's setSpeed may not work
            // immediately after startPlayerFromStream due to a timing issue where
            // the Dart callback fires before the native AudioTrack.play() is called.
            // By waiting until after data is fed, we ensure the AudioTrack is fully ready.
            if (!_speedAppliedAfterFirstFeed && _playbackSpeed != 1.0) {
              // Add a small delay to ensure the AudioTrack has processed the first chunk
              await Future.delayed(_speedApplyDelayAfterFeed);
              try {
                await _player!.setSpeed(_playbackSpeed);
                _speedAppliedAfterFirstFeed = true;
                logService.info(_tag, 'Applied playback speed after first feed: ${_playbackSpeed}x');
              } catch (e) {
                logService.warn(_tag, 'Error applying playback speed: $e');
                // Don't set the flag so we can retry on next chunk
              }
            }
          }
        } catch (e) {
          logService.error(_tag, 'Error feeding audio chunk: $e');
          // Don't re-queue failed chunks to avoid infinite loops
          // Just log and continue
        }
        
        // Small delay to prevent overwhelming the audio system
        await Future.delayed(const Duration(milliseconds: 1));
      }
    } catch (e) {
      logService.error(_tag, 'Error processing audio queue: $e');
    } finally {
      _isProcessingQueue = false;
      _processingCompleter?.complete();
    }
  }

  /// Mark that the current response is complete
  /// This allows the player to flush any remaining buffered audio
  Future<void> markResponseComplete() async {
    logService.info(_tag, 'Response marked complete');
    
    // Wait for queue to be processed
    if (_isProcessingQueue && _processingCompleter != null) {
      await _processingCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          logService.warn(_tag, 'Timeout waiting for audio queue to process');
        },
      );
    }
  }

  /// Stop playback and clear any buffered audio
  Future<void> stop() async {
    logService.info(_tag, 'Stopping playback');
    
    // Clear the queue first
    _audioQueue.clear();
    
    // Mark as not playing before stopping to prevent new data being fed
    final wasPlaying = _isPlaying;
    _isPlaying = false;
    
    // Wait for any ongoing processing to finish
    if (_isProcessingQueue && _processingCompleter != null) {
      try {
        await _processingCompleter!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            logService.warn(_tag, 'Timeout waiting for queue processing to stop');
          },
        );
      } catch (e) {
        // Ignore
      }
    }
    
    // Stop the player only if it was actually playing
    if (_isInitialized && wasPlaying && _player != null) {
      try {
        await _player!.stopPlayer();
        logService.info(_tag, 'Player stopped');
      } catch (e) {
        logService.warn(_tag, 'Error stopping player: $e');
      }
    }
    
    logService.info(_tag, 'Playback stopped');
  }

  /// Set playback speed (1.0 = normal, 2.0 = double speed)
  /// The speed setting is stored and applied when playback starts if not currently playing.
  /// If called during playback, it will be applied immediately.
  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    logService.info(_tag, 'Playback speed setting stored: ${speed}x');
    
    if (_isInitialized && _player != null && _isPlaying) {
      try {
        // Add a small delay before applying speed during playback
        // This helps ensure the AudioTrack is in a stable state
        await Future.delayed(_speedApplyDelayDuringPlayback);
        await _player!.setSpeed(speed);
        logService.info(_tag, 'Playback speed applied: ${speed}x');
        // Mark as applied so we don't re-apply in _processAudioQueue
        _speedAppliedAfterFirstFeed = true;
      } catch (e) {
        logService.warn(_tag, 'Error setting playback speed: $e');
      }
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_isInitialized && _player != null) {
      await _player!.setVolume(volume);
    }
  }

  /// Dispose the player and release resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    logService.info(_tag, 'Disposing AudioPlayerService');
    _isDisposed = true;
    
    await stop();
    
    if (_isInitialized && _player != null) {
      try {
        await _player!.closePlayer();
      } catch (e) {
        logService.warn(_tag, 'Error closing player: $e');
      }
      _player = null;
      _isInitialized = false;
    }
    
    logService.info(_tag, 'AudioPlayerService disposed');
  }
}
