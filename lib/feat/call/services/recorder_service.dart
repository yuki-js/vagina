import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/call/services/subservice.dart';
import 'package:vagina/utils/audio_utils.dart';


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

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _rawAudioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _isRecording = false;
  bool _isMuted = false;

  RecorderService();

  bool get isMuted => _isMuted;

  bool get isRecording => _isRecording;

  Stream<Uint8List> get audioStream => _audioController.stream;

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Stream<bool> get muteState => _muteStateController.stream;

  @override
  Future<void> start() async {
    await super.start();
    logger.info('RecorderService started');
  }

  Future<bool> hasPermission() async {
    ensureNotDisposed();
    await start();
    final hasPermission = await _recorder.hasPermission();
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

    if (_isRecording) {
      logger.fine('Recording session already started');
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      logger.severe('Microphone permission not granted');
      throw StateError('Microphone permission not granted.');
    }

    logger.info(
        'Starting recording session: sampleRate=${AppConfig.sampleRate}, channels=${AppConfig.channels}');

    try {
      _isRecording = true;
      final rawStream = await _recorder.startStream(
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
          _recorder.onAmplitudeChanged(amplitudeUpdateInterval).listen(
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

      logger.info('Recording started successfully');
    } catch (e, stackTrace) {
      logger.severe('Failed to start recording session', e, stackTrace);
      _isRecording = false;
      rethrow;
    }
  }

  Future<void> stopRecordingSession() async {
    if (!_isRecording) {
      logger.fine('Recording session already stopped');
      return;
    }

    logger.info('Stopping recording session');
    _isRecording = false;

    try {
      await _rawAudioSubscription?.cancel();
      _rawAudioSubscription = null;

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      await _recorder.stop();
      _emitAmplitude(0.0);
      logger.info('Recording stopped successfully');
    } catch (e, stackTrace) {
      logger.severe('Failed to stop recording session', e, stackTrace);
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
      await _recorder.stop();
    } catch (e, stackTrace) {
      logger.warning('Error stopping recorder during disposal', e, stackTrace);
    }

    await _recorder.dispose();

    await _audioController.close();
    await _amplitudeController.close();
    await _muteStateController.close();
    
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
}
