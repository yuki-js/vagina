import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';
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

  @override
  Future<void> start() async {
    await super.start();

    if (_state != RecorderServiceState.uninitialized) {
      return;
    }

    logger.info('Starting RecorderService');
    _recorder = AudioRecorder();
    _setState(RecorderServiceState.idle);
  }

  Future<bool> hasPermission() async {
    ensureNotDisposed();
    await start();
    final hasPermission = await (_recorder ??= AudioRecorder()).hasPermission();
    logger.fine('Microphone permission check: $hasPermission');
    return hasPermission;
  }

  void setMute(bool muted) {
    ensureNotDisposed();
    if (_isMuted == muted) {
      return;
    }
    _isMuted = muted;
    logger.info('Mute state changed: ${_isMuted ? "muted" : "unmuted"}');
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
      logger.fine('Recording session already started or starting');
      return;
    }

    final recorder = _recorder ??= AudioRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      logger.severe('Microphone permission not granted');
      throw StateError('Microphone permission not granted.');
    }

    logger.info(
        'Starting recording session: sampleRate=${AppConfig.sampleRate}, channels=${AppConfig.channels}');
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
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
          ),
        ),
      );

      await _rawAudioSubscription?.cancel();
      _rawAudioSubscription = rawStream.listen(
        _onRawAudioChunk,
        onError: (Object error, StackTrace stackTrace) {
          logger.severe('Audio stream error', error, stackTrace);
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
        onError: (Object error, StackTrace stackTrace) {
          logger.warning('Amplitude stream error', error, stackTrace);
        },
      );

      _setState(RecorderServiceState.recording);
    } catch (e, stackTrace) {
      logger.severe('Failed to start recording session', e, stackTrace);
      _setState(RecorderServiceState.idle);
      rethrow;
    }
  }

  Future<void> stopRecordingSession() async {
    if (_state == RecorderServiceState.idle ||
        _state == RecorderServiceState.uninitialized) {
      logger.fine('Recording session already stopped');
      return;
    }
    if (_state == RecorderServiceState.stopping) {
      logger.fine('Recording session already stopping');
      return;
    }

    logger.info('Stopping recording session');
    _setState(RecorderServiceState.stopping);

    try {
      await _rawAudioSubscription?.cancel();
      _rawAudioSubscription = null;

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      await _recorder?.stop();
      _emitAmplitude(0.0);
      _setState(RecorderServiceState.idle);
    } catch (e, stackTrace) {
      logger.severe('Failed to stop recording session', e, stackTrace);
      _setState(RecorderServiceState.idle);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing RecorderService');
    await super.dispose();

    await _rawAudioSubscription?.cancel();
    _rawAudioSubscription = null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      await _recorder?.stop();
    } catch (e, stackTrace) {
      logger.warning('Error stopping recorder during disposal', e, stackTrace);
    }

    await _recorder?.dispose();
    _recorder = null;

    _setState(RecorderServiceState.disposed, emitWhenClosed: false);

    await _audioController.close();
    await _amplitudeController.close();
    await _muteStateController.close();
    await _stateController.close();
    
    logger.info('RecorderService disposed successfully');
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
    final previous = _state;
    _state = next;
    logger.info('State transition: $previous → $next');
    if (emitWhenClosed && !_stateController.isClosed) {
      _stateController.add(next);
    }
  }

}
