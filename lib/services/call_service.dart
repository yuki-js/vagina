import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'audio_recorder_service.dart';
import 'audio_player_service.dart';
import 'realtime_api_client.dart';
import 'storage_service.dart';
import 'tool_service.dart';
import 'log_service.dart';
import '../models/chat_message.dart';
import '../models/realtime_events.dart';

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
  final ToolService _toolService;

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
  Timer? _callTimer;

  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<List<ChatMessage>> _chatController =
      StreamController<List<ChatMessage>>.broadcast();

  CallState _currentState = CallState.idle;
  int _callDuration = 0;
  bool _isMuted = false;
  
  // Chat history
  final List<ChatMessage> _chatMessages = [];
  int _messageIdCounter = 0;
  StringBuffer _currentAssistantTranscript = StringBuffer();
  String? _currentAssistantMessageId;
  String? _pendingUserMessageId; // Placeholder for user message waiting for transcript

  CallService({
    required AudioRecorderService recorder,
    required AudioPlayerService player,
    required RealtimeApiClient apiClient,
    required StorageService storage,
    required ToolService toolService,
  })  : _recorder = recorder,
        _player = player,
        _apiClient = apiClient,
        _storage = storage,
        _toolService = toolService;

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
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;
  
  /// Get current chat messages
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

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
  
  /// Send a text message (for chat input)
  void sendTextMessage(String text) {
    if (!isCallActive || text.trim().isEmpty) return;
    
    // Add user message to chat
    _addChatMessage('user', text);
    
    // Send to API
    _apiClient.sendTextMessage(text);
  }

  /// Start a call
  Future<void> startCall() async {
    if (isCallActive) {
      logService.warn(_tag, 'Call already active, ignoring startCall');
      return;
    }

    logService.info(_tag, 'Starting call');
    
    // Clear chat history for new call
    _chatMessages.clear();
    _messageIdCounter = 0;
    _currentAssistantTranscript = StringBuffer();
    _currentAssistantMessageId = null;

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

      // Configure tools before connecting
      _apiClient.setTools(_toolService.toolDefinitions);

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
      _responseAudioSubscription = _apiClient.audioStream.listen((audioData) async {
        logService.debug(_tag, 'Received audio from API: ${audioData.length} bytes');
        await _player.addAudioData(audioData);
      });
      
      // Listen for audio done events
      _audioDoneSubscription = _apiClient.audioDoneStream.listen((_) async {
        logService.info(_tag, 'Audio done event received, marking response complete');
        await _player.markResponseComplete();
        // Mark current assistant message as complete
        _completeCurrentAssistantMessage();
      });
      
      // Listen to assistant transcript (AI response)
      _transcriptSubscription = _apiClient.transcriptStream.listen((delta) {
        _appendAssistantTranscript(delta);
      });
      
      // Listen to user speech started (VAD) - create placeholder for correct ordering
      _speechStartedSubscription = _apiClient.speechStartedStream.listen((_) {
        _createUserMessagePlaceholder();
      });
      
      // Listen to user transcript (speech-to-text) - update the placeholder
      _userTranscriptSubscription = _apiClient.userTranscriptStream.listen((transcript) {
        _updateUserMessagePlaceholder(transcript);
      });
      
      // Listen to function calls
      _functionCallSubscription = _apiClient.functionCallStream.listen((functionCall) async {
        logService.info(_tag, 'Handling function call: ${functionCall.name}');
        final result = await _toolService.executeTool(
          functionCall.callId,
          functionCall.name,
          functionCall.arguments,
        );
        
        // Add tool call to chat history
        _addToolMessage(functionCall.name, functionCall.arguments, result.output);
        
        _apiClient.sendFunctionCallResult(result.callId, result.output);
      });
      
      // Listen to speech started events to stop audio when user starts speaking (interrupt)
      _responseStartedSubscription = _apiClient.responseStartedStream.listen((_) async {
        logService.info(_tag, 'User speech detected, stopping audio for interrupt');
        await _player.stop();
        // Complete previous assistant message if any
        _completeCurrentAssistantMessage();
      });

      // Start microphone recording
      logService.info(_tag, 'Starting microphone recording');
      final audioStream = await _recorder.startRecording();

      // Listen to audio stream and send to API
      // When muted, send silence instead of stopping the stream
      _audioStreamSubscription = audioStream.listen(
        (audioData) {
          if (_currentState == CallState.connected) {
            if (_isMuted) {
              // Send silence (zero-filled buffer) with same size as original audio
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
    
    // Don't clear chat on end - it will be cleared when starting a new call
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
  
  /// Add a chat message
  void _addChatMessage(String role, String content) {
    final message = ChatMessage(
      id: 'msg_${_messageIdCounter++}',
      role: role,
      content: content,
      timestamp: DateTime.now(),
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Add a tool call message to chat
  void _addToolMessage(String toolName, String arguments, String result) {
    final message = ChatMessage(
      id: 'msg_${_messageIdCounter++}',
      role: 'tool',
      content: '',  // Content is empty - tool info is shown as badge in UI
      timestamp: DateTime.now(),
      toolCall: ToolCallInfo(
        name: toolName,
        arguments: arguments,
        result: result,
      ),
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Create a placeholder for user message (called on speech_started)
  /// This ensures the user message appears BEFORE the AI response
  void _createUserMessagePlaceholder() {
    // Don't create another placeholder if one already exists
    if (_pendingUserMessageId != null) return;
    
    _pendingUserMessageId = 'msg_${_messageIdCounter++}';
    final message = ChatMessage(
      id: _pendingUserMessageId!,
      role: 'user',
      content: '...',  // Placeholder text while waiting for transcription
      timestamp: DateTime.now(),
      isComplete: false,
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
    logService.debug(_tag, 'Created user message placeholder: $_pendingUserMessageId');
  }
  
  /// Update the user message placeholder with actual transcript
  void _updateUserMessagePlaceholder(String transcript) {
    if (_pendingUserMessageId != null) {
      // Update existing placeholder
      final index = _chatMessages.indexWhere((m) => m.id == _pendingUserMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          content: transcript,
          isComplete: true,
        );
        _chatController.add(List.unmodifiable(_chatMessages));
        logService.debug(_tag, 'Updated user message placeholder with transcript');
      }
      _pendingUserMessageId = null;
    } else {
      // No placeholder exists - create new message directly
      // This can happen if transcription arrives without speech_started (e.g., text input)
      _addChatMessage('user', transcript);
    }
  }
  
  /// Clear chat history
  void clearChat() {
    _chatMessages.clear();
    _messageIdCounter = 0;
    _currentAssistantTranscript = StringBuffer();
    _currentAssistantMessageId = null;
    _pendingUserMessageId = null;
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Append to the current assistant transcript (streaming)
  void _appendAssistantTranscript(String delta) {
    if (_currentAssistantMessageId == null) {
      // Start a new assistant message
      _currentAssistantMessageId = 'msg_${_messageIdCounter++}';
      _currentAssistantTranscript = StringBuffer();
      _currentAssistantTranscript.write(delta);
      
      final message = ChatMessage(
        id: _currentAssistantMessageId!,
        role: 'assistant',
        content: _currentAssistantTranscript.toString(),
        timestamp: DateTime.now(),
        isComplete: false,
      );
      _chatMessages.add(message);
    } else {
      // Append to existing message
      _currentAssistantTranscript.write(delta);
      
      // Update the message
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          content: _currentAssistantTranscript.toString(),
        );
      }
    }
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Mark the current assistant message as complete
  void _completeCurrentAssistantMessage() {
    if (_currentAssistantMessageId != null) {
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(isComplete: true);
        _chatController.add(List.unmodifiable(_chatMessages));
      }
      _currentAssistantMessageId = null;
      _currentAssistantTranscript = StringBuffer();
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _cleanup();
    await _stateController.close();
    await _amplitudeController.close();
    await _durationController.close();
    await _errorController.close();
    await _chatController.close();
  }
}
