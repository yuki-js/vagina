import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../config/app_config.dart';

/// Service for recording audio from the microphone
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  
  Stream<RecordState>? _stateStream;
  Stream<Amplitude>? _amplitudeStream;

  bool _isRecording = false;

  bool get isRecording => _isRecording;

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
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConfig.sampleRate,
        numChannels: AppConfig.channels,
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
