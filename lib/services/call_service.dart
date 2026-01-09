import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'realtime_api_client.dart';
import 'storage_service.dart';
import 'tool_service.dart';
import 'haptic_service.dart';
import 'notepad_service.dart';
import 'log_service.dart';
import 'chat/chat_message_manager.dart';
import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../models/call_session.dart';
import '../models/realtime_events.dart';
import '../utils/audio_utils.dart';

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
  static const _tag = 'CallService';
  
  final AudioRecorderService _recorder;
  final AudioPlayerService _player;
  final RealtimeApiClient _apiClient;
  final StorageService _storage;
  final ToolService _toolService;
  final HapticService _hapticService;
  final NotepadService _notepadService;
  final ChatMessageManager _chatManager = ChatMessageManager();
  
  /// Session-scoped tool manager (created on call start, disposed on call end)
  ToolManager? _toolManager;

  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _responseAudioSubscription;
  StreamSubscription<void>? _audioDoneSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<String>? _userTranscriptSubscription;
  StreamSubscription<FunctionCall>? _functionCallSubscription;
  StreamSubscription<void>? _responseStartedSubscription;
  StreamSubscription<void>? _speechStartedSubscription;
  StreamSubscription<void>? _responseAudioStartedSubscription;
  Timer? _callTimer;
  Timer? _silenceTimer;

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
  DateTime? _callStartTime;
  String? _currentSpeedDialId;

  CallService({
    required AudioRecorderService recorder,
    required AudioPlayerService player,
    required RealtimeApiClient apiClient,
    required StorageService storage,
    required ToolService toolService,
    required HapticService hapticService,
    required NotepadService notepadService,
  })  : _recorder = recorder,
        _player = player,
        _apiClient = apiClient,
        _storage = storage,
        _toolService = toolService,
        _hapticService = hapticService,
        _notepadService = notepadService;

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
  
  /// Stream of chat messages
  Stream<List<ChatMessage>> get chatStream => _chatManager.chatStream;
  
  /// Get current chat messages
  List<ChatMessage> get chatMessages => _chatManager.chatMessages;

  /// Current call duration in seconds
  int get callDuration => _callDuration;

  /// Whether the call is active
  bool get isCallActive =>
      _currentState == CallState.connecting ||
      _currentState == CallState.connected;
  
  /// Get the current session's tool manager (null if no active call)
  ToolManager? get toolManager => _toolManager;

  /// Set mute state
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _amplitudeController.add(0.0);
    }
  }

  /// Set the current speed dial ID (call before startCall)
  void setSpeedDialId(String? speedDialId) {
    _currentSpeedDialId = speedDialId;
  }

  /// Set assistant configuration (voice and instructions) before starting a call
  void setAssistantConfig(String voice, String instructions) {
    _apiClient.setVoiceAndInstructions(voice, instructions);
  }

  /// Check if Azure configuration exists
  Future<bool> hasAzureConfig() async {
    return await _storage.hasAzureConfig();
  }

  /// Check microphone permission
  Future<bool> hasMicrophonePermission() async {
    return await _recorder.hasPermission();
  }
  
  /// Send a text message (for chat input)
  void sendTextMessage(String text) {
    if (!isCallActive || text.trim().isEmpty) return;
    _chatManager.addChatMessage('user', text);
    _apiClient.sendTextMessage(text);
  }

  /// Start a call
  Future<void> startCall() async {
    if (isCallActive) {
      logService.warn(_tag, 'Call already active, ignoring startCall');
      return;
    }

    logService.info(_tag, 'Starting call');
    _chatManager.clearChat();

    try {
      _setState(CallState.connecting);

      logService.debug(_tag, 'Checking Azure config');
      final hasConfig = await _storage.hasAzureConfig();
      if (!hasConfig) {
        logService.error(_tag, 'Azure config not found');
        _emitError('Azure OpenAI設定を先に行ってください');
        _setState(CallState.idle);
        return;
      }

      logService.debug(_tag, 'Checking microphone permission');
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        logService.error(_tag, 'Microphone permission denied');
        _emitError('マイクの使用を許可してください');
        _setState(CallState.idle);
        return;
      }

      final realtimeUrl = await _storage.getRealtimeUrl();
      final apiKey = await _storage.getApiKey();

      if (realtimeUrl == null || apiKey == null) {
        logService.error(_tag, 'Azure credentials not found');
        _emitError('Azure OpenAI設定が見つかりません');
        _setState(CallState.idle);
        return;
      }

      // Create session-scoped tool manager (async now)
      _toolManager = await _toolService.createToolManager(
        onToolsChanged: _onToolsChanged,
      );
      _apiClient.setTools(_toolManager!.toolDefinitions);

      logService.info(_tag, 'Connecting to Azure OpenAI');
      await _apiClient.connect(realtimeUrl, apiKey);

      _setupApiSubscriptions();

      logService.info(_tag, 'Starting microphone recording');
      final audioStream = await _recorder.startRecording();

      _setupAudioStream(audioStream);
      _setupAmplitudeMonitoring();
      _startCallTimer();
      
      // Track call start time for session saving
      _callStartTime = DateTime.now();

      // Enable wake lock to prevent device sleep during call
      await _enableWakeLock();

      _setState(CallState.connected);
      _resetSilenceTimer(); // Start silence detection
      logService.info(_tag, 'Call connected successfully');
    } catch (e) {
      logService.error(_tag, 'Failed to start call: $e');
      _emitError('接続に失敗しました: $e');
      _setState(CallState.error);
      await _cleanup();
    }
  }
  
  /// Called when tools change (via ToolManager)
  void _onToolsChanged() {
    if (_toolManager != null && _currentState == CallState.connected) {
      _apiClient.setTools(_toolManager!.toolDefinitions);
      _apiClient.updateSessionConfig();
      logService.info(_tag, 'Tools updated, session config refreshed');
    }
  }

  void _setupApiSubscriptions() {
    _errorSubscription = _apiClient.errorStream.listen((error) {
      logService.error(_tag, 'API error received: $error');
      _emitError('API エラー: $error');
    });

    _responseAudioSubscription = _apiClient.audioStream.listen((audioData) async {
      logService.debug(_tag, 'Received audio from API: ${audioData.length} bytes');
      await _player.addAudioData(audioData);
    });
    
    _audioDoneSubscription = _apiClient.audioDoneStream.listen((_) async {
      logService.info(_tag, 'Audio done event received, marking response complete');
      await _player.markResponseComplete();
      _chatManager.completeCurrentAssistantMessage();
      // Haptic feedback: AI response ended, user's turn
      await _hapticService.heavyImpact();
    });
    
    _transcriptSubscription = _apiClient.transcriptStream.listen((delta) {
      _chatManager.appendAssistantTranscript(delta);
    });
    
    _speechStartedSubscription = _apiClient.speechStartedStream.listen((_) {
      _chatManager.createUserMessagePlaceholder();
      _resetSilenceTimer(); // User started speaking, reset silence timer
      logService.debug(_tag, 'Created user message placeholder');
      // Haptic feedback: VAD detected user speech started (fire-and-forget)
      unawaited(_hapticService.selectionClick());
    });
    
    _userTranscriptSubscription = _apiClient.userTranscriptStream.listen((transcript) {
      _chatManager.updateUserMessagePlaceholder(transcript);
      logService.debug(_tag, 'Updated user message placeholder with transcript');
    });
    
    _functionCallSubscription = _apiClient.functionCallStream.listen((functionCall) async {
      logService.info(_tag, 'Handling function call: ${functionCall.name}');
      if (_toolManager == null) {
        logService.error(_tag, 'Tool manager not available');
        return;
      }
      final result = await _toolManager!.executeTool(
        functionCall.callId,
        functionCall.name,
        functionCall.arguments,
      );
      _chatManager.addToolCall(functionCall.name, functionCall.arguments, result.output);
      _apiClient.sendFunctionCallResult(result.callId, result.output);
    });
    
    _responseStartedSubscription = _apiClient.responseStartedStream.listen((_) async {
      logService.info(_tag, 'User speech detected, stopping audio for interrupt');
      await _player.stop();
      _chatManager.completeCurrentAssistantMessage();
    });
    
    _responseAudioStartedSubscription = _apiClient.responseAudioStartedStream.listen((_) {
      _resetSilenceTimer(); // AI started speaking, reset silence timer
      // Haptic feedback: AI audio response started after user speech ended (fire-and-forget)
      unawaited(_hapticService.selectionClick());
    });
  }

  void _setupAudioStream(Stream<Uint8List> audioStream) {
    _audioStreamSubscription = audioStream.listen(
      (audioData) {
        if (_currentState == CallState.connected) {
          if (_isMuted) {
            final silenceData = Uint8List(audioData.length);
            _apiClient.sendAudio(silenceData);
          } else {
            _apiClient.sendAudio(audioData);
          }
        }
      },
      onError: (error) {
        logService.error(_tag, 'Recording error: $error');
        _emitError('録音エラー: $error');
        endCall();
      },
    );
  }

  void _setupAmplitudeMonitoring() {
    final amplitudeStream = _recorder.amplitudeStream;
    if (amplitudeStream != null) {
      _amplitudeSubscription = amplitudeStream.listen((amplitude) {
        if (!_isMuted && isCallActive) {
          final normalizedLevel = AudioUtils.normalizeAmplitude(amplitude.current);
          _amplitudeController.add(normalizedLevel);
        } else {
          _amplitudeController.add(0.0);
        }
      });
    }
  }

  void _startCallTimer() {
    _callDuration = 0;
    _durationController.add(_callDuration);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      _durationController.add(_callDuration);
    });
  }

  /// Start or reset the silence detection timer
  /// Call this method whenever audio activity is detected
  void _resetSilenceTimer() {
    // Cancel any existing timer
    _silenceTimer?.cancel();
    
    // Only start silence timer if configured (timeout > 0) and call is connected
    if (AppConfig.silenceTimeoutSeconds <= 0 || _currentState != CallState.connected) {
      return;
    }
    
    logService.debug(_tag, 'Resetting silence timer (${AppConfig.silenceTimeoutSeconds}s)');
    
    _silenceTimer = Timer(
      Duration(seconds: AppConfig.silenceTimeoutSeconds),
      _onSilenceTimeout,
    );
  }

  /// Called when silence timeout is reached
  void _onSilenceTimeout() {
    if (_currentState != CallState.connected) {
      return;
    }
    
    logService.info(_tag, 'Silence timeout reached (${AppConfig.silenceTimeoutSeconds}s), ending call');
    _emitError('無音状態が続いたため通話を終了しました');
    endCall();
  }

  /// End the call
  Future<void> endCall() async {
    if (!isCallActive && _currentState != CallState.error) {
      logService.debug(_tag, 'Call not active, ignoring endCall');
      return;
    }

    // Save session before cleanup
    await _saveSession();
    
    await _cleanup();
    _setState(CallState.idle);
    logService.info(_tag, 'Call ended');
  }

  Future<void> _saveSession() async {
    if (_callStartTime == null || _callDuration == 0) {
      logService.debug(_tag, 'Skipping session save (no meaningful data)');
      return;
    }

    try {
      // Convert chat messages to JSON strings
      final chatMessagesJson = _chatManager.chatMessages
          .map((msg) => jsonEncode({
                'role': msg.role,
                'content': msg.content,
                'timestamp': msg.timestamp.toIso8601String(),
              }))
          .toList();

      // Collect all notepad content
      final notepadTabs = _notepadService.tabs;
      String? notepadContent;
      List<SessionNotepadTab>? notepadTabsData;
      
      if (notepadTabs.isNotEmpty) {
        // Save tabs as structured data
        notepadTabsData = notepadTabs.map((tab) {
          return SessionNotepadTab(
            title: tab.title,
            content: tab.content,
          );
        }).toList();
        
        // Also keep concatenated version for backward compatibility
        notepadContent = notepadTabs.map((tab) {
          final header = '# ${tab.title}\n\n';
          return header + tab.content;
        }).join('\n\n---\n\n');
      }

      final session = CallSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: _callStartTime!,
        endTime: DateTime.now(),
        duration: _callDuration,
        chatMessages: chatMessagesJson,
        notepadContent: notepadContent,
        notepadTabs: notepadTabsData,
        speedDialId: _currentSpeedDialId,
      );

      await _storage.saveCallSession(session);
      logService.info(_tag, 'Session saved: ${session.id}');
    } catch (e) {
      logService.error(_tag, 'Failed to save session: $e');
    }
  }

  Future<void> _cleanup() async {
    logService.debug(_tag, 'Cleaning up call resources');
    
    _callTimer?.cancel();
    _callTimer = null;
    
    _silenceTimer?.cancel();
    _silenceTimer = null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    await _responseAudioSubscription?.cancel();
    _responseAudioSubscription = null;
    
    await _audioDoneSubscription?.cancel();
    _audioDoneSubscription = null;

    await _errorSubscription?.cancel();
    _errorSubscription = null;
    
    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;
    
    await _userTranscriptSubscription?.cancel();
    _userTranscriptSubscription = null;
    
    await _speechStartedSubscription?.cancel();
    _speechStartedSubscription = null;
    
    await _functionCallSubscription?.cancel();
    _functionCallSubscription = null;
    
    await _responseStartedSubscription?.cancel();
    _responseStartedSubscription = null;
    
    await _responseAudioStartedSubscription?.cancel();
    _responseAudioStartedSubscription = null;

    await _recorder.stopRecording();
    await _player.stop();
    await _apiClient.disconnect();
    
    // Disable wake lock to allow device to sleep normally
    await _disableWakeLock();
    
    // Dispose session-scoped tool manager
    _toolManager?.dispose();
    _toolManager = null;

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

  /// Enable wake lock to prevent device from sleeping during call
  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      logService.info(_tag, 'Wake lock enabled');
    } catch (e) {
      logService.error(_tag, 'Failed to enable wake lock: $e');
    }
  }

  /// Disable wake lock to allow device to sleep normally
  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      logService.info(_tag, 'Wake lock disabled');
    } catch (e) {
      logService.error(_tag, 'Failed to disable wake lock: $e');
    }
  }
  
  /// Clear chat history
  void clearChat() {
    _chatManager.clearChat();
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _cleanup();
    await _stateController.close();
    await _amplitudeController.close();
    await _durationController.close();
    await _errorController.close();
    await _chatManager.dispose();
  }
}
