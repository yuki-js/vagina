import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'realtime_api_client.dart';
import 'secure_storage_service.dart';

/// Enum representing the current state of the call
enum CallState {
  idle,
  connecting,
  connected,
  error,
}

/// Service that manages the entire call lifecycle including
/// microphone recording, Azure OpenAI Realtime API connection, and audio playback
class CallService {
  final AudioRecorderService _recorder;
  final AudioPlayerService _player;
  final RealtimeApiClient _apiClient;
  final SecureStorageService _storage;

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
    required SecureStorageService storage,
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
    if (isCallActive) return;

    try {
      _setState(CallState.connecting);

      // Check Azure config
      final hasConfig = await _storage.hasAzureConfig();
      if (!hasConfig) {
        _emitError('Azure OpenAI設定を先に行ってください');
        _setState(CallState.idle);
        return;
      }

      // Check microphone permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _emitError('マイクの使用を許可してください');
        _setState(CallState.idle);
        return;
      }

      // Get Azure credentials
      final realtimeUrl = await _storage.getRealtimeUrl();
      final apiKey = await _storage.getApiKey();

      if (realtimeUrl == null || apiKey == null) {
        _emitError('Azure OpenAI設定が見つかりません');
        _setState(CallState.idle);
        return;
      }

      // Connect to Azure OpenAI Realtime API
      await _apiClient.connect(realtimeUrl, apiKey);

      // Listen to API errors
      _errorSubscription = _apiClient.errorStream.listen((error) {
        _emitError('API エラー: $error');
      });

      // Listen to response audio
      _responseAudioSubscription = _apiClient.audioStream.listen((audioData) {
        _player.addAudioData(audioData);
      });

      // Start microphone recording
      final audioStream = await _recorder.startRecording();

      // Listen to audio stream and send to API
      _audioStreamSubscription = audioStream.listen(
        (audioData) {
          if (!_isMuted && _currentState == CallState.connected) {
            _apiClient.sendAudio(audioData);
          }
        },
        onError: (error) {
          _emitError('録音エラー: $error');
          endCall();
        },
      );

      // Listen to amplitude for visualization
      final amplitudeStream = _recorder.amplitudeStream;
      if (amplitudeStream != null) {
        _amplitudeSubscription = amplitudeStream.listen((amplitude) {
          if (!_isMuted && isCallActive) {
            // Convert dBFS to 0-1 range
            final normalizedLevel =
                ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
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
    } catch (e) {
      _emitError('接続に失敗しました: $e');
      _setState(CallState.error);
      await _cleanup();
    }
  }

  /// End the call
  Future<void> endCall() async {
    if (!isCallActive && _currentState != CallState.error) return;

    await _cleanup();
    _setState(CallState.idle);
  }

  Future<void> _cleanup() async {
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
  }

  void _setState(CallState state) {
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
