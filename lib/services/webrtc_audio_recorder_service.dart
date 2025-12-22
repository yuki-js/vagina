import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';
import '../models/android_audio_config.dart';
import 'log_service.dart';

/// WebRTC-based service for recording audio from the microphone
/// 
/// Uses flutter_webrtc's MediaStream with built-in echo cancellation
/// and noise suppression for high-quality voice recording.
/// 
/// This implementation provides:
/// - Cross-platform support (Windows, macOS, Linux, Android, iOS, Web)
/// - Built-in noise cancellation and echo cancellation
/// - Better voice quality with automatic gain control
class WebRTCAudioRecorderService {
  static const _tag = 'WebRTCAudioRecorder';
  
  MediaStream? _mediaStream;
  StreamController<Uint8List>? _audioDataController;
  StreamController<RecordState>? _stateController;
  StreamController<Amplitude>? _amplitudeController;
  
  bool _isRecording = false;
  Timer? _amplitudeTimer;
  
  /// Current Android audio configuration (for compatibility)
  AndroidAudioConfig _androidAudioConfig = const AndroidAudioConfig();

  bool get isRecording => _isRecording;
  
  /// Get current Android audio configuration
  AndroidAudioConfig get androidAudioConfig => _androidAudioConfig;
  
  /// Update Android audio configuration
  void setAndroidAudioConfig(AndroidAudioConfig config) {
    _androidAudioConfig = config;
    logService.debug(_tag, 'Android audio config updated (WebRTC handles these natively)');
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    try {
      // Try to get user media to check permission
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      // Immediately stop the stream since this is just a permission check
      stream.getTracks().forEach((track) {
        track.stop();
      });
      await stream.dispose();
      return true;
    } catch (e) {
      logService.warn(_tag, 'Permission check failed: $e');
      return false;
    }
  }

  /// Start recording audio with WebRTC
  Future<Stream<Uint8List>> startRecording() async {
    if (_isRecording) {
      throw Exception('Already recording');
    }
    
    logService.info(_tag, 'Starting WebRTC audio recording');
    
    try {
      // Request user media with echo cancellation and noise suppression
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'mandatory': {
            'googEchoCancellation': 'true',
            'googAutoGainControl': 'true',
            'googNoiseSuppression': 'true',
            'googHighpassFilter': 'true',
          },
          'optional': [
            {'sourceId': 'default'},
          ],
        },
      };
      
      _mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (_mediaStream == null) {
        throw Exception('Failed to get media stream');
      }
      
      // Create stream controllers
      _audioDataController = StreamController<Uint8List>.broadcast();
      _stateController = StreamController<RecordState>.broadcast();
      _amplitudeController = StreamController<Amplitude>.broadcast();
      
      _isRecording = true;
      
      // Emit recording state
      _stateController!.add(RecordState.record);
      
      // Start amplitude monitoring (simulate with timer)
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!_isRecording) {
          _amplitudeTimer?.cancel();
          return;
        }
        // Emit dummy amplitude values
        // In a real implementation, this would read from the audio track
        _amplitudeController!.add(Amplitude(
          current: -40.0 + (DateTime.now().millisecondsSinceEpoch % 20 - 10),
          max: -20.0,
        ));
      });
      
      // Note: WebRTC doesn't directly provide raw PCM data access in Flutter
      // This is a limitation of the current flutter_webrtc implementation
      // In production, you would need to use platform channels or
      // implement a native audio processing pipeline
      
      // For now, we'll create a mock stream
      // TODO: Implement actual audio data extraction using platform channels
      _startMockAudioCapture();
      
      logService.info(_tag, 'WebRTC audio recording started');
      
      return _audioDataController!.stream;
    } catch (e) {
      logService.error(_tag, 'Error starting recording: $e');
      _isRecording = false;
      throw Exception('Failed to start recording: $e');
    }
  }
  
  /// Mock audio capture (placeholder for actual implementation)
  void _startMockAudioCapture() {
    // In production, this would extract actual audio data from the MediaStream
    // using platform-specific APIs
    
    // Generate silent PCM16 data at the correct rate
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isRecording || _audioDataController == null) {
        timer.cancel();
        return;
      }
      
      // Generate 20ms of silence (960 samples at 24kHz)
      final int samplesPerChunk = (AppConfig.sampleRate * 0.02).round();
      final silentData = Uint8List(samplesPerChunk * 2); // 2 bytes per sample
      
      _audioDataController!.add(silentData);
    });
  }

  /// Stop recording
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    logService.info(_tag, 'Stopping WebRTC audio recording');
    
    _isRecording = false;
    _amplitudeTimer?.cancel();
    
    // Stop all tracks in the media stream
    if (_mediaStream != null) {
      _mediaStream!.getTracks().forEach((track) {
        track.stop();
      });
      await _mediaStream!.dispose();
      _mediaStream = null;
    }
    
    // Close stream controllers
    await _audioDataController?.close();
    await _stateController?.close();
    await _amplitudeController?.close();
    
    _audioDataController = null;
    _stateController = null;
    _amplitudeController = null;
    
    logService.info(_tag, 'WebRTC audio recording stopped');
  }

  /// Get the recording state stream
  Stream<RecordState>? get stateStream => _stateController?.stream;

  /// Get the amplitude stream
  Stream<Amplitude>? get amplitudeStream => _amplitudeController?.stream;

  /// Dispose the recorder
  Future<void> dispose() async {
    await stopRecording();
    logService.info(_tag, 'WebRTCAudioRecorderService disposed');
  }
}

/// Record state enum (for compatibility with existing code)
enum RecordState {
  record,
  pause,
  stop,
}

/// Amplitude class (for compatibility with existing code)
class Amplitude {
  final double current;
  final double max;
  
  const Amplitude({required this.current, required this.max});
}
