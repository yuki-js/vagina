import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:vagina/config/app_config.dart';
import 'package:vagina/models/android_audio_config.dart';

/// Service for recording audio from the microphone
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  
  Stream<RecordState>? _stateStream;
  Stream<Amplitude>? _amplitudeStream;

  bool _isRecording = false;
  
  /// Current Android audio configuration
  AndroidAudioConfig _androidAudioConfig = const AndroidAudioConfig();

  bool get isRecording => _isRecording;
  
  /// Get current Android audio configuration
  AndroidAudioConfig get androidAudioConfig => _androidAudioConfig;
  
  /// Update Android audio configuration
  void setAndroidAudioConfig(AndroidAudioConfig config) {
    _androidAudioConfig = config;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<Stream<Uint8List>> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConfig.sampleRate,
        numChannels: AppConfig.channels,
        // Enable echo cancellation to prevent AI voice from being picked up.
        // This is applied on all platforms that support it (Android, iOS, etc.)
        echoCancel: true,
        // Enable noise suppression for clearer audio.
        // This is applied on all platforms that support it.
        noiseSuppress: true,
        // Android-specific configuration for voice communication.
        // iOS uses the default IosRecordConfig which is suitable for this use case
        // as echo cancellation and noise suppression are handled by the
        // platform-level echoCancel and noiseSuppress flags above.
        androidConfig: AndroidRecordConfig(
          // Use configurable audio source (default: voiceCommunication)
          audioSource: _androidAudioConfig.audioSource,
          // Use configurable audio manager mode (default: modeInCommunication)
          audioManagerMode: _androidAudioConfig.audioManagerMode,
        ),
      ),
    );

    _isRecording = true;
    _stateStream = _recorder.onStateChanged();
    _amplitudeStream = _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 100),
    );

    return stream;
  }

  /// Stop recording
  Future<void> stopRecording() async {
    await _recorder.stop();
    _isRecording = false;
    await _stateSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
  }

  /// Get the recording state stream
  Stream<RecordState>? get stateStream => _stateStream;

  /// Get the amplitude stream
  Stream<Amplitude>? get amplitudeStream => _amplitudeStream;

  /// Dispose the recorder
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.dispose();
  }
}
