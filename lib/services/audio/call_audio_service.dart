import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:taudio/taudio.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:collection';
import 'package:vagina/utils/platform_compat.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/models/android_audio_config.dart';
import 'pcm_recorder.dart';
import '../log_service.dart';

/// Unified audio service for call session
///
/// Combines microphone recording (via PcmRecorder) and PCM audio playback,
/// abstracting platform differences (Windows uses just_audio, others use flutter_sound).
/// 
/// This service manages:
/// - Microphone recording (delegated to PcmRecorder)
/// - Audio playback with platform-specific implementations
/// - Platform-specific configuration (Android audio mode, etc.)
class CallAudioService {
  static const _tag = 'CallAudioService';

  final LogService _logService;
  
  // Use shared PcmRecorder for recording
  final PcmRecorder _recorder;

  // Player implementation (platform-specific)
  dynamic _playerImpl;
  bool _isPlayingAudio = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Audio buffer queue for flutter_sound (non-Windows)
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isProcessingQueue = false;
  Completer<void>? _processingCompleter;
  bool _isStartingPlayback = false;

  bool get isPlaying => _isPlayingAudio;
  bool get isRecording => _recorder.isRecording;

  /// Current Android audio configuration
  AndroidAudioConfig get androidAudioConfig => _recorder.androidAudioConfig;

  /// Stream of recording state changes
  Stream<RecordState>? get stateStream => _recorder.stateStream;

  /// Stream of audio amplitude levels
  Stream<Amplitude>? get amplitudeStream => _recorder.amplitudeStream;

  CallAudioService({LogService? logService})
      : _logService = logService ?? LogService(),
        _recorder = PcmRecorder(logService: logService) {
    if (PlatformCompat.isWindows) {
      _playerImpl = _WindowsPcmPlayer(logService: _logService);
    } else {
      _playerImpl = FlutterSoundPlayer();
    }
  }

  /// Update Android audio configuration
  void setAndroidAudioConfig(AndroidAudioConfig config) {
    _recorder.setAndroidAudioConfig(config);
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording microphone audio
  ///
  /// Returns a stream of PCM16 audio chunks at the configured sample rate
  Future<Stream<Uint8List>> startRecording() async {
    return await _recorder.startRecording();
  }

  /// Stop recording audio
  Future<void> stopRecording() async {
    await _recorder.stopRecording();
  }

  /// Add PCM16 audio data for playback
  Future<void> addAudioData(Uint8List pcmData) async {
    if (pcmData.isEmpty || _isDisposed) {
      return;
    }

    if (PlatformCompat.isWindows) {
      await _ensurePlayerInitialized();
      await (_playerImpl as _WindowsPcmPlayer).play(pcmData);
    } else {
      _audioQueue.add(pcmData);
      await _processAudioQueue();
    }
  }

  /// Ensure player is initialized
  Future<void> _ensurePlayerInitialized() async {
    if (_isInitialized || _isDisposed) return;

    _logService.info(_tag, 'Initializing audio player');

    if (PlatformCompat.isWindows) {
      await (_playerImpl as _WindowsPcmPlayer).initialize();
    } else {
      await (_playerImpl as FlutterSoundPlayer).openPlayer();
    }

    _isInitialized = true;
    _logService.info(_tag, 'Audio player initialized');
  }

  /// Start playback of buffered audio
  Future<void> _startPlayback() async {
    if (_isPlayingAudio || _isStartingPlayback || _isDisposed) {
      return;
    }

    _isStartingPlayback = true;

    try {
      await _ensurePlayerInitialized();

      if (PlatformCompat.isWindows) {
        _isPlayingAudio = true;
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

        _isPlayingAudio = true;
      }

      _logService.info(_tag, 'Streaming playback started');
    } catch (e) {
      _logService.error(_tag, 'Error starting playback: $e');
      _isPlayingAudio = false;
    } finally {
      _isStartingPlayback = false;
    }
  }

  /// Process queued audio chunks for playback
  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue || _isDisposed || PlatformCompat.isWindows) {
      return;
    }

    _isProcessingQueue = true;
    _processingCompleter = Completer<void>();

    try {
      if (!_isPlayingAudio && !_isStartingPlayback) {
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

      while (_audioQueue.isNotEmpty && _isPlayingAudio && !_isDisposed) {
        final chunk = _audioQueue.removeFirst();

        try {
          if (_playerImpl != null && _isPlayingAudio) {
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

  /// Mark audio response as complete (allows queue processing to finish)
  Future<void> markResponseComplete() async {
    _logService.info(_tag, 'Response marked complete');

    if (_isProcessingQueue && _processingCompleter != null) {
      await _processingCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
  }

  /// Stop all audio playback
  Future<void> stop() async {
    _logService.info(_tag, 'Stopping playback');

    _audioQueue.clear();
    final wasPlaying = _isPlayingAudio;
    _isPlayingAudio = false;

    if (_isProcessingQueue && _processingCompleter != null) {
      try {
        await _processingCompleter!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } on TimeoutException {
        _logService.debug(_tag, 'Queue processing timed out during stop');
      }
    }

    if (_isInitialized && wasPlaying) {
      try {
        if (PlatformCompat.isWindows) {
          await (_playerImpl as _WindowsPcmPlayer).stop();
        } else if (_playerImpl != null) {
          await (_playerImpl as FlutterSoundPlayer).stopPlayer();
        }
        _logService.info(_tag, 'Player stopped');
      } catch (e) {
        _logService.warn(_tag, 'Error stopping player: $e');
      }
    }
  }

  /// Set playback volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    if (_isInitialized) {
      if (PlatformCompat.isWindows) {
        // Volume control not implemented for Windows yet
      } else if (_playerImpl != null) {
        await (_playerImpl as FlutterSoundPlayer).setVolume(volume);
      }
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _logService.info(_tag, 'Disposing CallAudioService');
    _isDisposed = true;

    await stopRecording();
    await stop();

    if (_isInitialized) {
      try {
        if (PlatformCompat.isWindows) {
          await (_playerImpl as _WindowsPcmPlayer).dispose();
        } else if (_playerImpl != null) {
          await (_playerImpl as FlutterSoundPlayer).closePlayer();
        }
      } catch (e) {
        _logService.warn(_tag, 'Error closing player: $e');
      }
      _playerImpl = null;
      _isInitialized = false;
    }

    await _recorder.dispose();
    _logService.info(_tag, 'CallAudioService disposed');
  }
}

/// Windows-specific PCM player using just_audio
/// 
/// This is a private implementation detail, used internally by CallAudioService
/// to provide audio playback on Windows where flutter_sound is not available.
class _WindowsPcmPlayer {
  final LogService _logService;
  final ja.AudioPlayer _player = ja.AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;
  int _currentFileIndex = 0;

  _WindowsPcmPlayer({LogService? logService})
      : _logService = logService ?? LogService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        _playNextInQueue();
      }
    });
  }

  /// Initialize the audio player
  Future<void> initialize() async {
    await _player.setVolume(1.0);
  }

  /// Play PCM16 audio data
  Future<void> play(Uint8List audioData) async {
    _audioQueue.add(audioData);

    if (!_isPlaying) {
      await _playNextInQueue();
    }
  }

  /// Play the next audio chunk from queue
  Future<void> _playNextInQueue() async {
    if (_audioQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    final audioData = _audioQueue.removeAt(0);

    try {
      // Write PCM data to temporary WAV file
      final wavFile = await _createWavFile(audioData);

      // Play the file
      await _player.setFilePath(wavFile.path);
      await _player.play();

      // Clean up after playback
      _player.playerStateStream.firstWhere(
        (state) => state.processingState == ja.ProcessingState.completed
      ).then((_) {
        wavFile.deleteSync();
      });
    } catch (e) {
      _logService.error('CallAudioService', 'Error playing audio: $e');
      _isPlaying = false;
      // Try next in queue
      await _playNextInQueue();
    }
  }

  /// Convert PCM16 data to WAV file
  Future<File> _createWavFile(Uint8List pcm16Data) async {
    final tempDir = await getTemporaryDirectory();
    final wavFilePath = path.join(
      tempDir.path,
      'audio_${_currentFileIndex++}_${DateTime.now().millisecondsSinceEpoch}.wav'
    );

    // Create WAV header for 24kHz mono PCM16
    const sampleRate = 24000;
    const numChannels = 1;
    const bitsPerSample = 16;
    final dataSize = pcm16Data.length;

    final header = ByteData(44);
    // "RIFF" chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataSize, Endian.little);

    // "WAVE" format
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // "data" sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and PCM data
    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcm16Data);

    // Write to file
    final file = File(wavFilePath);
    await file.writeAsBytes(wavData);

    return file;
  }

  /// Stop all playback and clear queue
  Future<void> stop() async {
    await _player.stop();
    _audioQueue.clear();
    _isPlaying = false;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
    _audioQueue.clear();
  }
}
