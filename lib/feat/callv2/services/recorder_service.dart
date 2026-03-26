import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';
import 'package:vagina/models/android_audio_config.dart';
import 'package:vagina/utils/audio_utils.dart';

/// Lifecycle state for [RecorderService].
enum RecorderServiceState {
  uninitialized,
  idle,
  starting,
  recording,
  stopping,
  disposed,
}

/// Session-scoped microphone recorder service.
///
/// Owns microphone capture, mute behavior, amplitude reporting, and PCM stream
/// fan-out for call sessions.
final class RecorderService extends SubService {
  static const _tag = 'RecorderService';

  /// Interval for amplitude updates
  static const Duration amplitudeUpdateInterval = Duration(milliseconds: 100);

  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<bool> _muteStateController =
      StreamController<bool>.broadcast();
  final StreamController<RecorderServiceState> _stateController =
      StreamController<RecorderServiceState>.broadcast();

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _rawAudioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  AndroidAudioConfig _androidAudioConfig = const AndroidAudioConfig();
  RecorderServiceState _state = RecorderServiceState.uninitialized;
  bool _isMuted = false;

  RecorderService();

  RecorderServiceState get state => _state;

  bool get isMuted => _isMuted;

  bool get isRecording => _state == RecorderServiceState.recording;

  Stream<Uint8List> get audioStream => _audioController.stream;

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Stream<bool> get muteState => _muteStateController.stream;

  Stream<RecorderServiceState> get states => _stateController.stream;

  AndroidAudioConfig get androidAudioConfig => _androidAudioConfig;

  @override
  Future<void> start() async {
    await super.start();

    if (_state != RecorderServiceState.uninitialized) {
      return;
    }

    _recorder = AudioRecorder();
    _setState(RecorderServiceState.idle);
  }

  void configureAndroid(AndroidAudioConfig config) {
    ensureNotDisposed();
    _androidAudioConfig = config;
  }

  Future<bool> hasPermission() async {
    ensureNotDisposed();
    await start();
    return (_recorder ??= AudioRecorder()).hasPermission();
  }

  void setMute(bool muted) {
    ensureNotDisposed();
    if (_isMuted == muted) {
      return;
    }
    _isMuted = muted;
    if (!_muteStateController.isClosed) {
      _muteStateController.add(_isMuted);
    }
    if (_isMuted) {
      _emitAmplitude(0.0);
    }
  }

  Future<void> startRecordingSession() async {
    ensureNotDisposed();
    await start();

    if (_state == RecorderServiceState.recording ||
        _state == RecorderServiceState.starting) {
      return;
    }

    final recorder = _recorder ??= AudioRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission not granted.');
    }

    _setState(RecorderServiceState.starting);

    try {
      final rawStream = await recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AppConfig.sampleRate,
          numChannels: AppConfig.channels,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            audioSource: _androidAudioConfig.audioSource,
            audioManagerMode: _androidAudioConfig.audioManagerMode,
          ),
        ),
      );

      await _rawAudioSubscription?.cancel();
      _rawAudioSubscription = rawStream.listen(
        _onRawAudioChunk,
        onError: (Object error, StackTrace stackTrace) {
          if (!_audioController.isClosed) {
            _audioController.addError(error, stackTrace);
          }
        },
      );

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription =
          recorder.onAmplitudeChanged(amplitudeUpdateInterval).listen(
        (amplitude) {
          if (_isMuted) {
            _emitAmplitude(0.0);
            return;
          }
          _emitAmplitude(AudioUtils.normalizeAmplitude(amplitude.current));
        },
        onError: (Object error, StackTrace stackTrace) {},
      );

      _setState(RecorderServiceState.recording);
    } catch (e) {
      _setState(RecorderServiceState.idle);
      rethrow;
    }
  }

  Future<void> stopRecordingSession() async {
    if (_state == RecorderServiceState.idle ||
        _state == RecorderServiceState.uninitialized) {
      return;
    }
    if (_state == RecorderServiceState.stopping) {
      return;
    }

    _setState(RecorderServiceState.stopping);

    try {
      await _rawAudioSubscription?.cancel();
      _rawAudioSubscription = null;

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      await _recorder?.stop();
      _emitAmplitude(0.0);
      _setState(RecorderServiceState.idle);
    } catch (e) {
      _setState(RecorderServiceState.idle);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await super.dispose();

    await _rawAudioSubscription?.cancel();
    _rawAudioSubscription = null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      await _recorder?.stop();
    } catch (e) {}

    await _recorder?.dispose();
    _recorder = null;

    _setState(RecorderServiceState.disposed, emitWhenClosed: false);

    await _audioController.close();
    await _amplitudeController.close();
    await _muteStateController.close();
    await _stateController.close();
  }

  void _onRawAudioChunk(Uint8List bytes) {
    if (_audioController.isClosed) {
      return;
    }

    if (_isMuted) {
      _audioController.add(Uint8List(bytes.length));
      return;
    }

    _audioController.add(bytes);
  }

  void _emitAmplitude(double value) {
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(value.clamp(0.0, 1.0));
    }
  }

  void _setState(
    RecorderServiceState next, {
    bool emitWhenClosed = true,
  }) {
    _state = next;
    if (emitWhenClosed && !_stateController.isClosed) {
      _stateController.add(next);
    }
  }

}
