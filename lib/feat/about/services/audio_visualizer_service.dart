import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:vagina/services/audio/pcm_recorder.dart';
import 'package:vagina/services/log_service.dart';

/// Audio visualizer service for real-time voice visualization.
///
/// This service provides a simplified interface for recording audio in visualization
/// contexts (e.g., voice waveform display, amplitude monitoring). It uses the shared
/// PcmRecorder to ensure consistent audio recording configuration across the app.
///
/// Unlike CallAudioService (which handles playback + recording), this service focuses
/// only on recording for UI visualization purposes.
class AudioVisualizerService {
  static const _tag = 'AudioVisualizerService';

  final LogService _logService;
  final PcmRecorder _recorder;

  bool get isRecording => _recorder.isRecording;

  /// Stream of recording state changes
  Stream<RecordState>? get stateStream => _recorder.stateStream;

  /// Stream of audio amplitude levels for visualization
  Stream<Amplitude>? get amplitudeStream => _recorder.amplitudeStream;

  AudioVisualizerService({LogService? logService})
      : _logService = logService ?? LogService(),
        _recorder = PcmRecorder(logService: logService);

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio for visualization
  ///
  /// Returns a stream of PCM16 audio chunks at the configured sample rate.
  /// Throws if microphone permission is not granted.
  Future<Stream<Uint8List>> startRecording() async {
    _logService.debug(_tag, 'Starting audio recording for visualization');
    return await _recorder.startRecording();
  }

  /// Stop recording audio
  Future<void> stopRecording() async {
    _logService.debug(_tag, 'Stopping audio recording');
    await _recorder.stopRecording();
  }

  /// Dispose the service and cleanup resources
  Future<void> dispose() async {
    _logService.debug(_tag, 'Disposing AudioVisualizerService');
    await _recorder.dispose();
  }
}
