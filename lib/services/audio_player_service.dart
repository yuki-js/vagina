import '../utils/platform_compat.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:taudio/taudio.dart';
import 'audio_player_service_windows.dart';
import 'log_service.dart';
import '../config/app_config.dart';

/// Service for playing streaming PCM audio from Azure OpenAI Realtime API
///
/// Uses just_audio for Windows (where flutter_sound is not supported)
/// and flutter_sound for other platforms.
class AudioPlayerService {
  static const _tag = 'AudioPlayer';

  final LogService _logService;
  dynamic _playerImpl;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Audio buffer queue for flutter_sound (non-Windows)
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isProcessingQueue = false;
  Completer<void>? _processingCompleter;
  bool _isStartingPlayback = false;

  bool get isPlaying => _isPlaying;

  AudioPlayerService({LogService? logService})
      : _logService = logService ?? LogService() {
    if (PlatformCompat.isWindows) {
      _playerImpl = AudioPlayerServiceWindows(logService: _logService);
    } else {
      _playerImpl = FlutterSoundPlayer();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isDisposed) return;

    _logService.info(_tag, 'Initializing audio player');

    if (PlatformCompat.isWindows) {
      await (_playerImpl as AudioPlayerServiceWindows).initialize();
    } else {
      await (_playerImpl as FlutterSoundPlayer).openPlayer();
    }

    _isInitialized = true;
    _logService.info(_tag, 'Audio player initialized');
  }

  Future<void> _startPlayback() async {
    if (_isPlaying || _isStartingPlayback || _isDisposed) {
      return;
    }

    _isStartingPlayback = true;

    try {
      await _ensureInitialized();

      if (PlatformCompat.isWindows) {
        _isPlaying = true;
      } else {
        if (_playerImpl == null || _isDisposed) {
          return;
        }

        await (_playerImpl as FlutterSoundPlayer).startPlayerFromStream(
          codec: Codec.pcm16,
          sampleRate: AppConfig.sampleRate,
          numChannels: AppConfig.channels,
          bufferSize: 8192,
          interleaved: true,
        );

        _isPlaying = true;
      }

      _logService.info(_tag, 'Streaming playback started');
    } catch (e) {
      _logService.error(_tag, 'Error starting playback: $e');
      _isPlaying = false;
    } finally {
      _isStartingPlayback = false;
    }
  }

  Future<void> addAudioData(Uint8List pcmData) async {
    if (pcmData.isEmpty || _isDisposed) {
      return;
    }

    _logService.debug(_tag, 'Queuing audio data: ${pcmData.length} bytes');

    if (PlatformCompat.isWindows) {
      await _ensureInitialized();
      await (_playerImpl as AudioPlayerServiceWindows).play(pcmData);
    } else {
      _audioQueue.add(pcmData);
      await _processAudioQueue();
    }
  }

  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue || _isDisposed || PlatformCompat.isWindows) {
      return;
    }

    _isProcessingQueue = true;
    _processingCompleter = Completer<void>();

    try {
      if (!_isPlaying && !_isStartingPlayback) {
        int totalBuffered =
            _audioQueue.fold(0, (sum, chunk) => sum + chunk.length);
        if (totalBuffered >= AppConfig.minAudioBufferSizeBeforeStart) {
          await _startPlayback();
        } else {
          _isProcessingQueue = false;
          _processingCompleter?.complete();
          return;
        }
      }

      while (_audioQueue.isNotEmpty && _isPlaying && !_isDisposed) {
        final chunk = _audioQueue.removeFirst();

        try {
          if (_playerImpl != null && _isPlaying) {
            await (_playerImpl as FlutterSoundPlayer)
                .feedUint8FromStream(chunk);
          }
        } catch (e) {
          _logService.error(_tag, 'Error feeding audio chunk: $e');
        }

        await Future.delayed(const Duration(milliseconds: 1));
      }
    } catch (e) {
      _logService.error(_tag, 'Error processing audio queue: $e');
    } finally {
      _isProcessingQueue = false;
      _processingCompleter?.complete();
    }
  }

  Future<void> markResponseComplete() async {
    _logService.info(_tag, 'Response marked complete');

    if (_isProcessingQueue && _processingCompleter != null) {
      await _processingCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
  }

  Future<void> stop() async {
    _logService.info(_tag, 'Stopping playback');

    _audioQueue.clear();
    final wasPlaying = _isPlaying;
    _isPlaying = false;

    if (_isProcessingQueue && _processingCompleter != null) {
      try {
        await _processingCompleter!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } on TimeoutException {
        // Timeout is expected during stop - we're stopping anyway
        _logService.debug(_tag, 'Queue processing timed out during stop');
      }
    }

    if (_isInitialized && wasPlaying) {
      try {
        if (PlatformCompat.isWindows) {
          await (_playerImpl as AudioPlayerServiceWindows).stop();
        } else if (_playerImpl != null) {
          await (_playerImpl as FlutterSoundPlayer).stopPlayer();
        }
        _logService.info(_tag, 'Player stopped');
      } catch (e) {
        _logService.warn(_tag, 'Error stopping player: $e');
      }
    }
  }

  Future<void> setVolume(double volume) async {
    if (_isInitialized) {
      if (PlatformCompat.isWindows) {
        // Volume control not implemented for Windows
      } else if (_playerImpl != null) {
        await (_playerImpl as FlutterSoundPlayer).setVolume(volume);
      }
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _logService.info(_tag, 'Disposing AudioPlayerService');
    _isDisposed = true;

    await stop();

    if (_isInitialized) {
      try {
        if (PlatformCompat.isWindows) {
          await (_playerImpl as AudioPlayerServiceWindows).dispose();
        } else if (_playerImpl != null) {
          await (_playerImpl as FlutterSoundPlayer).closePlayer();
        }
      } catch (e) {
        _logService.warn(_tag, 'Error closing player: $e');
      }
      _playerImpl = null;
      _isInitialized = false;
    }

    _logService.info(_tag, 'AudioPlayerService disposed');
  }
}
