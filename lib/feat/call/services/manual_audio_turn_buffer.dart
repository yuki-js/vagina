import 'dart:typed_data';

import 'package:vagina/core/config/app_config.dart';

/// A completed client-managed manual audio turn captured from the microphone.
final class ManualAudioTurn {
  final Uint8List audioBytes;
  final Duration duration;

  const ManualAudioTurn({required this.audioBytes, required this.duration});
}

/// Owns client-side/manual audio turn accumulation for CallService.
///
/// This class intentionally does not know about realtime providers. It only
/// gates raw PCM microphone chunks into a single completed manual turn.
final class ManualAudioTurnBuffer {
  final BytesBuilder _builder = BytesBuilder(copy: false);
  bool _isCapturing = false;
  int _capturedBytes = 0;

  bool get isCapturing => _isCapturing;

  int get capturedBytes => _capturedBytes;

  Duration get capturedDuration => _durationForBytes(_capturedBytes);

  void begin() {
    _builder.clear();
    _capturedBytes = 0;
    _isCapturing = true;
  }

  void append(Uint8List chunk) {
    if (!_isCapturing || chunk.isEmpty) {
      return;
    }

    _builder.add(chunk);
    _capturedBytes += chunk.length;
  }

  ManualAudioTurn? finish({required Duration minAudioDuration}) {
    if (!_isCapturing) {
      return null;
    }

    _isCapturing = false;
    final totalBytes = _capturedBytes;
    final duration = _durationForBytes(totalBytes);
    final audioBytes = _builder.toBytes();
    _clearCapturedAudio();

    if (duration < minAudioDuration) {
      return null;
    }

    return ManualAudioTurn(audioBytes: audioBytes, duration: duration);
  }

  void cancel() {
    _isCapturing = false;
    _clearCapturedAudio();
  }

  void _clearCapturedAudio() {
    _builder.clear();
    _capturedBytes = 0;
  }

  Duration _durationForBytes(int bytes) {
    final bytesPerSample = AppConfig.bitDepth ~/ 8;
    final bytesPerSecond =
        AppConfig.sampleRate * AppConfig.channels * bytesPerSample;
    return Duration(
      microseconds: (bytes * Duration.microsecondsPerSecond) ~/ bytesPerSecond,
    );
  }
}
