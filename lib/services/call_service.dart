import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'realtime_api_client.dart';
import 'storage_service.dart';
import 'log_service.dart';

/// Enum representing the current state of the call
enum CallState {
  idle,
  connecting,
  connected,
  error,
}

/// Audio level normalization constants
/// dBFS (decibels Full Scale) typically ranges from -160 to 0
/// -60 dB is considered quiet ambient noise, 0 dB is maximum
const double _dbfsQuietThreshold = -60.0;
const double _dbfsRange = 60.0;

/// Service that manages the entire call lifecycle including
/// microphone recording, Azure OpenAI Realtime API connection, and audio playback
class CallService {
  static const _tag = 'CallService';
  
  final AudioRecorderService _recorder;
  final AudioPlayerService _player;
  final RealtimeApiClient _apiClient;
  final StorageService _storage;

  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _responseAudioSubscription;
  StreamSubscription<String>? _errorSubscription;
  Timer? _callTimer;

  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  CallState _currentState = CallState.idle;
  int _callDuration = 0;
  bool _isMuted = false;

  CallService({
    required AudioRecorderService recorder,
    required AudioPlayerService player,
    required RealtimeApiClient apiClient,
    required StorageService storage,
  })  : _recorder = recorder,
        _player = player,
        _apiClient = apiClient,
        _storage = storage;

  /// Current call state
  CallState get currentState => _currentState;

  /// Stream of call state changes
  Stream<CallState> get stateStream => _stateController.stream;

  /// Stream of audio amplitude levels (0.0 - 1.0)
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Stream of call duration in seconds
  Stream<int> get durationStream => _durationController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Current call duration in seconds
  int get callDuration => _callDuration;

  /// Whether the call is active
  bool get isCallActive =>
      _currentState == CallState.connecting ||
      _currentState == CallState.connected;

  /// Set mute state
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _amplitudeController.add(0.0);
    }
  }

  /// Check if Azure configuration exists
  Future<bool> hasAzureConfig() async {
    return await _storage.hasAzureConfig();
  }

  /// Check microphone permission
  Future<bool> hasMicrophonePermission() async {
    return await _recorder.hasPermission();
  }

  /// Start a call
  Future<void> startCall() async {
    if (isCallActive) {
      logService.warn(_tag, 'Call already active, ignoring startCall');
      return;
    }

    logService.info(_tag, 'Starting call');

    try {
      _setState(CallState.connecting);

      // Check Azure config
      logService.debug(_tag, 'Checking Azure config');
      final hasConfig = await _storage.hasAzureConfig();
      if (!hasConfig) {
        logService.error(_tag, 'Azure config not found');
        _emitError('Azure OpenAI設定を先に行ってください');
        _setState(CallState.idle);
        return;
      }

      // Check microphone permission
      logService.debug(_tag, 'Checking microphone permission');
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        logService.error(_tag, 'Microphone permission denied');
        _emitError('マイクの使用を許可してください');
        _setState(CallState.idle);
        return;
      }

      // Get Azure credentials
      final realtimeUrl = await _storage.getRealtimeUrl();
      final apiKey = await _storage.getApiKey();

      if (realtimeUrl == null || apiKey == null) {
        logService.error(_tag, 'Azure credentials not found');
        _emitError('Azure OpenAI設定が見つかりません');
        _setState(CallState.idle);
        return;
      }

      // Connect to Azure OpenAI Realtime API
      logService.info(_tag, 'Connecting to Azure OpenAI');
      await _apiClient.connect(realtimeUrl, apiKey);

      // Listen to API errors
      _errorSubscription = _apiClient.errorStream.listen((error) {
        logService.error(_tag, 'API error received: $error');
        _emitError('API エラー: $error');
      });

      // Listen to response audio
      logService.debug(_tag, 'Setting up audio stream listener');
      _responseAudioSubscription = _apiClient.audioStream.listen((audioData) {
        logService.debug(_tag, 'Received audio from API: ${audioData.length} bytes');
        _player.addAudioData(audioData);
      });

      // Start microphone recording
      logService.info(_tag, 'Starting microphone recording');
      final audioStream = await _recorder.startRecording();

      // Listen to audio stream and send to API
      _audioStreamSubscription = audioStream.listen(
        (audioData) {
          if (!_isMuted && _currentState == CallState.connected) {
            _apiClient.sendAudio(audioData);
          }
        },
        onError: (error) {
          logService.error(_tag, 'Recording error: $error');
          _emitError('録音エラー: $error');
          endCall();
        },
      );

      // Listen to amplitude for visualization
      final amplitudeStream = _recorder.amplitudeStream;
      if (amplitudeStream != null) {
        _amplitudeSubscription = amplitudeStream.listen((amplitude) {
          if (!_isMuted && isCallActive) {
            // Convert dBFS to 0-1 range using constants
            final normalizedLevel =
                ((amplitude.current - _dbfsQuietThreshold) / _dbfsRange).clamp(0.0, 1.0);
            _amplitudeController.add(normalizedLevel);
          } else {
            _amplitudeController.add(0.0);
          }
        });
      }

      // Start call timer
      _callDuration = 0;
      _durationController.add(_callDuration);
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _callDuration++;
        _durationController.add(_callDuration);
      });

      _setState(CallState.connected);
      logService.info(_tag, 'Call connected successfully');
    } catch (e) {
      logService.error(_tag, 'Failed to start call: $e');
      _emitError('接続に失敗しました: $e');
      _setState(CallState.error);
      await _cleanup();
    }
  }

  /// End the call
  Future<void> endCall() async {
    if (!isCallActive && _currentState != CallState.error) {
      logService.debug(_tag, 'Call not active, ignoring endCall');
      return;
    }

    await _cleanup();
    _setState(CallState.idle);
    logService.info(_tag, 'Call ended');
  }

  Future<void> _cleanup() async {
    logService.debug(_tag, 'Cleaning up call resources');
    
    _callTimer?.cancel();
    _callTimer = null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    await _responseAudioSubscription?.cancel();
    _responseAudioSubscription = null;

    await _errorSubscription?.cancel();
    _errorSubscription = null;

    await _recorder.stopRecording();
    await _player.stop();
    await _apiClient.disconnect();

    _callDuration = 0;
    _durationController.add(0);
    _amplitudeController.add(0.0);
    
    logService.debug(_tag, 'Cleanup complete');
  }

  void _setState(CallState state) {
    logService.info(_tag, 'State changed: $_currentState -> $state');
    _currentState = state;
    _stateController.add(state);
  }

  void _emitError(String message) {
    _errorController.add(message);
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _cleanup();
    await _stateController.close();
    await _amplitudeController.close();
    await _durationController.close();
    await _errorController.close();
  }
}
