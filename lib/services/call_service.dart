import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/feat/callv2/models/active_file.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_sandbox_manager.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/utils/audio_utils.dart';

import 'audio/call_audio_service.dart';
import 'call_feedback_service.dart';
import 'chat/chat_message_manager.dart';
import 'log_service.dart';
import 'realtime_api_client.dart';

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

  final CallAudioService _audioService;
  final RealtimeApiClient _apiClient;
  final ConfigRepository _config;
  final SpeedDialRepository _speedDialRepo;
  final CallSessionRepository _sessionRepository;
  final VirtualFilesystemService _filesystemService;
  final LogService _logService;
  final CallFeedbackService _feedback;
  final ChatMessageManager _chatManager = ChatMessageManager();

  /// Session-scoped ToolSandboxManager (spawned on call start, disposed on call end)
  ToolSandboxManager? _sandboxManager;

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
  StreamSubscription<ToolCallStarted>? _toolCallStartedSubscription;
  StreamSubscription<ToolCallArgumentsDelta>?
      _toolCallArgumentsDeltaSubscription;
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
  final StreamController<String> _sessionSavedController =
      StreamController<String>.broadcast();
  final StreamController<List<ActiveFile>> _openFilesController =
      StreamController<List<ActiveFile>>.broadcast();

  CallState _currentState = CallState.idle;
  int _callDuration = 0;
  bool _isMuted = false;
  DateTime? _callStartTime;
  String _currentSpeedDialId = SpeedDial.defaultId;
  String? _endContext; // Store end context from tool call
  bool _isCleanedUp = false; // Track cleanup state to prevent double cleanup
  Map<String, bool> _toolConfig = const {};
  final Map<String, Tool> _allToolsByKey = <String, Tool>{};
  Set<String> _voiceVisibleToolKeys = <String>{};
  Set<String> _textVisibleToolKeys = <String>{};
  bool _hasSyncedVoiceTools = false;
  bool _hasSyncedTextTools = false;
  List<ActiveFile> _openFiles = const [];
  bool _isRefreshingToolset = false;
  bool _toolsetRefreshQueued = false;

  final Set<String> _activeToolCallIds = <String>{};
  final Set<String> _executingToolCallIds = <String>{};

  CallService({
    required CallAudioService audioService,
    required RealtimeApiClient apiClient,
    required ConfigRepository config,
    required SpeedDialRepository speedDialRepo,
    required CallSessionRepository sessionRepository,
    required VirtualFilesystemService filesystemService,
    LogService? logService,
    CallFeedbackService? feedbackService,
  })  : _audioService = audioService,
        _apiClient = apiClient,
        _config = config,
        _speedDialRepo = speedDialRepo,
        _sessionRepository = sessionRepository,
        _filesystemService = filesystemService,
        _logService = logService ?? LogService(),
        _feedback =
            feedbackService ?? CallFeedbackService(logService: logService);

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

  /// セッション保存完了通知ストリーム（セッションID）
  Stream<String> get sessionSavedStream => _sessionSavedController.stream;

  /// Stream of chat messages
  Stream<List<ChatMessage>> get chatStream => _chatManager.chatStream;

  /// Stream of active/open file state for the current call.
  Stream<List<ActiveFile>> get openFilesStream => _openFilesController.stream;

  /// Get current chat messages
  List<ChatMessage> get chatMessages => _chatManager.chatMessages;

  /// Current active/open files for the call.
  List<ActiveFile> get openFiles => List<ActiveFile>.from(_openFiles);

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

  /// Get the current speed dial ID
  String get currentSpeedDialId => _currentSpeedDialId;

  /// Set the current speed dial ID (call before startCall)
  void setSpeedDialId(String speedDialId) {
    _currentSpeedDialId = speedDialId;
  }

  /// Set assistant configuration (voice and instructions) before starting a call
  void setAssistantConfig(String voice, String instructions) {
    _apiClient.setVoiceAndInstructions(voice, instructions);
  }

  /// Check if Azure configuration exists
  Future<bool> hasAzureConfig() async {
    return await _config.hasAzureConfig();
  }

  /// Check microphone permission
  Future<bool> hasMicrophonePermission() async {
    return await _audioService.hasPermission();
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
      _logService.warn(_tag, 'Call already active, ignoring startCall');
      return;
    }

    _logService.info(_tag, 'Starting call');
    _endContext = null; // Clear previous end context for new call
    _isCleanedUp = false;

    try {
      _setState(CallState.connecting);

      // Play dial tone while connecting
      await _feedback.playDialTone();

      _logService.debug(_tag, 'Checking Azure config');
      final hasConfig = await hasAzureConfig();
      if (!hasConfig) {
        _logService.error(_tag, 'Azure config not found');
        _emitError('Azure OpenAI設定を先に行ってください');
        await _feedback.stopDialTone();
        _setState(CallState.idle);
        return;
      }

      _logService.debug(_tag, 'Checking microphone permission');
      final hasPermission = await _audioService.hasPermission();
      if (!hasPermission) {
        _logService.error(_tag, 'Microphone permission denied');
        _emitError('マイクの使用を許可してください');
        await _feedback.stopDialTone();
        _setState(CallState.idle);
        return;
      }

      final realtimeUrl = await _config.getRealtimeUrl();
      final apiKey = await _config.getApiKey();

      if (realtimeUrl == null || apiKey == null) {
        _logService.error(_tag, 'Azure credentials not found');
        _emitError('Azure OpenAI設定が見つかりません');
        await _feedback.stopDialTone();
        _setState(CallState.idle);
        return;
      }

      // Initialize tools for the call session
      await _initializeToolsForCall();

      _logService.info(_tag, 'Connecting to Azure OpenAI');
      await _apiClient.connect(realtimeUrl, apiKey);

      _setupApiSubscriptions();

      _logService.info(_tag, 'Starting microphone recording');
      final audioStream = await _audioService.startRecording();

      _setupAudioStream(audioStream);
      _setupAmplitudeMonitoring();
      _startCallTimer();

      // Track call start time for session saving
      _callStartTime = DateTime.now();

      // Enable wake lock to prevent device sleep during call
      await _enableWakeLock();

      _setState(CallState.connected);

      // Stop dial tone when connected
      await _feedback.stopDialTone();

      _resetSilenceTimer(); // Start silence detection
      _logService.info(_tag, 'Call connected successfully');
    } catch (e) {
      _logService.error(_tag, 'Failed to start call: $e');
      _emitError('接続に失敗しました: $e');
      await _feedback.stopDialTone();
      _setState(CallState.error);
      await _cleanup();
    }
  }

  /// Initialize tools for the call session
  ///
  /// This method:
  /// 1. Creates and starts the tool sandbox
  /// 2. Retrieves tool configuration from the current SpeedDial
  /// 3. Computes visible tool sets for voice/text from active files + config
  /// 4. Registers visible tools to each runtime consumer
  ///
  /// This is called once during call initialization. During the call,
  /// active file changes can trigger dynamic tool recomputation.
  Future<void> _initializeToolsForCall() async {
    _logService.debug(_tag, 'Initializing tools for call session');

    // 1. Create and start the tool sandbox
    _sandboxManager = ToolSandboxManager(
      filesystemService: _filesystemService,
      configRepository: _config,
      callService: this,
    );
    await _sandboxManager!.start();
    _logService.debug(_tag, 'Tool sandbox started');

    // 2. Get tool configuration from current SpeedDial
    final speedDial = await _speedDialRepo.getById(_currentSpeedDialId);
    final toolConfig = speedDial?.enabledTools ?? {};
    _logService.debug(
        _tag, 'Loaded tool config for SpeedDial: $_currentSpeedDialId');

    // 3. Cache all tool definitions for dynamic visible-tool computation.
    final sandbox = _sandboxManager!;
    final allTools = await sandbox.getToolsFromWorker();
    _allToolsByKey.clear();
    for (final tool in allTools) {
      _allToolsByKey[tool.definition.toolKey] = tool;
    }
    _toolConfig = Map<String, bool>.from(toolConfig);
    _voiceVisibleToolKeys = <String>{};
    _textVisibleToolKeys = <String>{};
    _hasSyncedVoiceTools = false;
    _hasSyncedTextTools = false;
    onActiveFilesChanged(const <Map<String, String>>[]);

    // 4. Apply initial visible tool sets and register them.
    await refreshToolsForActiveFiles();

    _logService.info(_tag,
        'Tool initialization complete: voice=${_voiceVisibleToolKeys.length}/${allTools.length}, text=${_textVisibleToolKeys.length}/${allTools.length}');
  }

  void _setupApiSubscriptions() {
    _errorSubscription = _apiClient.errorStream.listen((error) {
      _logService.error(_tag, 'API error received: $error');
      _emitError('API エラー: $error');
    });

    _responseAudioSubscription =
        _apiClient.audioStream.listen((audioData) async {
      await _audioService.addAudioData(audioData);
    });

    _audioDoneSubscription = _apiClient.audioDoneStream.listen((_) async {
      _logService.info(
          _tag, 'Audio done event received, marking response complete');
      await _audioService.markResponseComplete();
      _chatManager.completeCurrentAssistantMessage();
      // Haptic feedback: AI response ended, user's turn
      await _feedback.heavyImpact();
    });

    _transcriptSubscription = _apiClient.transcriptStream.listen((delta) {
      _chatManager.appendAssistantTranscript(delta);
    });

    _speechStartedSubscription = _apiClient.speechStartedStream.listen((_) {
      _chatManager.createUserMessagePlaceholder();
      _resetSilenceTimer(); // User started speaking, reset silence timer
      _logService.debug(_tag, 'Created user message placeholder');
      // Haptic feedback: VAD detected user speech started (fire-and-forget)
      unawaited(_feedback.selectionClick());
    });

    _userTranscriptSubscription =
        _apiClient.userTranscriptStream.listen((transcript) {
      _chatManager.updateUserMessagePlaceholder(transcript);
      _logService.debug(
          _tag, 'Updated user message placeholder with transcript');
    });

    // Tool call lifecycle: Start (generating state)
    _toolCallStartedSubscription =
        _apiClient.toolCallStartedStream.listen((event) {
      _chatManager.startToolCall(event.callId, event.name);
      _activeToolCallIds.add(event.callId);
      _logService.debug(
          _tag, 'Tool call started: ${event.name} (${event.callId})');
    });

    // Tool call lifecycle: Arguments streaming
    _toolCallArgumentsDeltaSubscription =
        _apiClient.toolCallArgumentsDeltaStream.listen((event) {
      _chatManager.updateToolCallArguments(event.callId, event.delta);
    });

    // Tool call lifecycle: Execute and complete
    _functionCallSubscription =
        _apiClient.functionCallStream.listen((functionCall) async {
      _logService.info(_tag, 'Handling function call: ${functionCall.name}');

      // Check if cancelled before execution
      if (_chatManager.isToolCallCancelled(functionCall.callId)) {
        _logService.debug(_tag,
            'Skipping execution for cancelled tool: ${functionCall.callId}');
        return;
      }

      // Transition to executing state
      _chatManager.transitionToolCallToExecuting(
          functionCall.callId, functionCall.arguments);
      _onToolCallExecuting(functionCall.callId);

      final sandbox = _sandboxManager;
      if (sandbox == null) {
        _logService.error(_tag, 'Tool sandbox not available');
        _chatManager.failToolCall(
            functionCall.callId, 'Tool sandbox not available');
        _onToolCallFailed(functionCall.callId);
        return;
      }

      final argsMap = _parseFunctionCallArguments(functionCall.arguments);
      if (argsMap == null) {
        final output = jsonEncode({'error': 'Invalid or empty JSON arguments'});
        _chatManager.failToolCall(functionCall.callId, 'Invalid arguments');
        _apiClient.sendFunctionCallResult(functionCall.callId, output);
        _onToolCallFailed(functionCall.callId);
        return;
      }

      try {
        final output = await sandbox.execute(
          functionCall.name,
          argsMap,
        );

        // Check if cancelled after execution
        if (_chatManager.isToolCallCancelled(functionCall.callId)) {
          _logService.debug(_tag,
              'Discarding result for cancelled tool: ${functionCall.callId}');
          _onToolCallFinished(functionCall.callId);
          return;
        }

        // Complete successfully
        _chatManager.completeToolCall(functionCall.callId, output);
        _apiClient.sendFunctionCallResult(functionCall.callId, output);
        _onToolCallCompleted(functionCall.callId);
      } catch (e) {
        // Handle execution error
        _logService.error(_tag, 'Tool execution failed: $e');
        final errorOutput = jsonEncode({'error': e.toString()});

        final isCancelled =
            _chatManager.isToolCallCancelled(functionCall.callId);

        // Only update if not cancelled
        if (!isCancelled) {
          _chatManager.failToolCall(functionCall.callId, e.toString());
          _apiClient.sendFunctionCallResult(functionCall.callId, errorOutput);
          _onToolCallFailed(functionCall.callId);
        } else {
          _onToolCallFinished(functionCall.callId);
        }
      }
    });

    _responseStartedSubscription =
        _apiClient.responseStartedStream.listen((_) async {
      _logService.info(
          _tag, 'User speech detected, stopping audio for interrupt');
      // Cancel all pending tool calls on interrupt
      _chatManager.cancelAllPendingToolCalls();
      _handleToolCallsCancelled(playSound: true);
      await _audioService.stop();
      _chatManager.completeCurrentAssistantMessage();
    });

    _responseAudioStartedSubscription =
        _apiClient.responseAudioStartedStream.listen((_) {
      _resetSilenceTimer(); // AI started speaking, reset silence timer
      // Haptic feedback: AI audio response started after user speech ended (fire-and-forget)
      unawaited(_feedback.selectionClick());
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
        _logService.error(_tag, 'Recording error: $error');
        _emitError('録音エラー: $error');
        endCall();
      },
    );
  }

  void _setupAmplitudeMonitoring() {
    final amplitudeStream = _audioService.amplitudeStream;
    if (amplitudeStream != null) {
      _amplitudeSubscription = amplitudeStream.listen((amplitude) {
        if (!_isMuted && isCallActive) {
          final normalizedLevel =
              AudioUtils.normalizeAmplitude(amplitude.current);
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
    if (AppConfig.silenceTimeoutSeconds <= 0 ||
        _currentState != CallState.connected) {
      return;
    }

    _logService.debug(
        _tag, 'Resetting silence timer (${AppConfig.silenceTimeoutSeconds}s)');

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

    _logService.info(_tag,
        'Silence timeout reached (${AppConfig.silenceTimeoutSeconds}s), ending call');
    _emitError('無音状態が続いたため通話を終了しました');
    endCall();
  }

  /// End the call
  ///
  /// [endContext] - Optional context explaining why the call ended
  /// (e.g., "processing in progress", "natural conclusion")
  Future<void> endCall({String? endContext}) async {
    if (!isCallActive && _currentState != CallState.error) {
      _logService.debug(_tag, 'Call not active, ignoring endCall');
      return;
    }

    // Store end context for session saving
    if (endContext != null && endContext.isNotEmpty) {
      _endContext = endContext;
      _logService.info(_tag, 'Call ending with context: $endContext');
    }

    // Play call end tone
    await _feedback.playCallEndTone();

    // Persist all active/open files before session capture and cleanup.
    await _persistOpenFilesForEndCall();

    // Save session before cleanup
    await _saveSession();

    await _cleanup();
    _setState(CallState.idle);
    _logService.info(_tag, 'Call ended');
  }

  /// Store end context for the current call
  ///
  /// This is called by the host API when the end_call tool is used with context
  void setEndContext(String? context) {
    if (context != null && context.isNotEmpty) {
      _endContext = context;
      _logService.debug(_tag, 'End context set: $context');
    }
  }

  /// Callback from FilesystemHostApi when active files are updated.
  ///
  /// Returns true when the active path set changed (open/close/move/delete).
  bool onActiveFilesChanged(List<Map<String, String>> activeFiles) {
    final previousPaths = _openFiles.map((file) => file.path).toSet();
    final next = activeFiles
        .map((entry) => ActiveFile(
              path: entry['path'] ?? '',
              content: entry['content'] ?? '',
            ))
        .where((file) => file.path.isNotEmpty)
        .toList();
    final nextPaths = next.map((file) => file.path).toSet();

    _openFiles = next;
    if (!_openFilesController.isClosed) {
      _openFilesController.add(List<ActiveFile>.from(_openFiles));
    }
    return !_sameStringSet(previousPaths, nextPaths);
  }

  Future<void> updateOpenFileContent(String path, String content) async {
    final sandbox = _sandboxManager;
    if (sandbox == null) {
      throw StateError('Tool sandbox not available');
    }
    await sandbox.updateActiveFile(path, content);
  }

  Future<void> closeOpenFile(String path, {bool persist = true}) async {
    final sandbox = _sandboxManager;
    if (sandbox == null) {
      throw StateError('Tool sandbox not available');
    }

    final active = await sandbox.getActiveFile(path);
    if (active == null) {
      return;
    }

    if (persist) {
      await sandbox.writeFile(path, active['content'] ?? '');
    }
    await sandbox.closeActiveFile(path);
  }

  Future<void> _persistOpenFilesForEndCall() async {
    final sandbox = _sandboxManager;
    if (sandbox == null) {
      return;
    }

    List<Map<String, String>> activeFiles;
    try {
      activeFiles = await sandbox.listActiveFiles();
      onActiveFilesChanged(activeFiles);
    } catch (e) {
      _logService.error(_tag, 'Failed to list active files before endCall: $e');
      return;
    }

    if (activeFiles.isEmpty) {
      return;
    }

    var persistedCount = 0;
    for (final activeFile in activeFiles) {
      final path = activeFile['path'];
      if (path == null || path.isEmpty) {
        continue;
      }

      final content = activeFile['content'] ?? '';
      try {
        await sandbox.writeFile(path, content);
        persistedCount++;
      } catch (e) {
        _logService.error(
          _tag,
          'Failed to persist active file during endCall: $path, error: $e',
        );
      }
    }

    _logService.info(
      _tag,
      'Persisted $persistedCount/${activeFiles.length} active file(s) during endCall',
    );
  }

  Future<void> refreshToolsForActiveFiles() async {
    if (_isRefreshingToolset) {
      _toolsetRefreshQueued = true;
      return;
    }

    final sandbox = _sandboxManager;
    if (sandbox == null || _allToolsByKey.isEmpty) {
      return;
    }

    _isRefreshingToolset = true;
    try {
      do {
        _toolsetRefreshQueued = false;

        final activeFiles = await sandbox.listActiveFiles();
        onActiveFilesChanged(activeFiles);

        final activePaths = activeFiles
            .map((entry) => entry['path'])
            .whereType<String>()
            .toList();
        final desiredVoiceToolKeys = _resolveVoiceToolKeys(activePaths);
        final desiredTextToolKeys = _resolveTextToolKeys(activePaths);

        final voiceToolsetChanged =
            !_sameStringSet(_voiceVisibleToolKeys, desiredVoiceToolKeys);
        final textToolsetChanged =
            !_sameStringSet(_textVisibleToolKeys, desiredTextToolKeys);

        if (voiceToolsetChanged || !_hasSyncedVoiceTools) {
          _voiceVisibleToolKeys = desiredVoiceToolKeys;
          final voiceTools = _allToolsByKey.values
              .where((tool) =>
                  _voiceVisibleToolKeys.contains(tool.definition.toolKey))
              .toList();
          _apiClient.setTools(voiceTools);
          _apiClient.updateSessionConfig();
          _hasSyncedVoiceTools = true;
        }

        if (textToolsetChanged || !_hasSyncedTextTools) {
          _textVisibleToolKeys = desiredTextToolKeys;
          final sortedTextToolKeys = _textVisibleToolKeys.toList()..sort();
          await sandbox.setTextAgentVisibleToolKeys(sortedTextToolKeys);
          _hasSyncedTextTools = true;
        }
      } while (_toolsetRefreshQueued);
    } finally {
      _isRefreshingToolset = false;
    }
  }

  bool _sameStringSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }
    return true;
  }

  Set<String> _resolveVoiceToolKeys(List<String> activePaths) {
    final activeExtensions = activePaths
        .map((path) => VirtualFile(path: path, content: '').extension)
        .where((extension) => extension.isNotEmpty)
        .map((extension) => extension.toLowerCase())
        .toSet();

    final desired = <String>{};
    for (final tool in _allToolsByKey.values) {
      final definition = tool.definition;
      final enabledByActivation =
          definition.activation.isEnabledForExtensions(activeExtensions);
      final enabledByConfig = _toolConfig[definition.toolKey] ?? true;
      if (enabledByActivation && enabledByConfig) {
        desired.add(definition.toolKey);
      }
    }
    return desired;
  }

  Set<String> _resolveTextToolKeys(List<String> activePaths) {
    final activeExtensions = activePaths
        .map((path) => VirtualFile(path: path, content: '').extension)
        .where((extension) => extension.isNotEmpty)
        .map((extension) => extension.toLowerCase())
        .toSet();

    final desired = <String>{};
    for (final tool in _allToolsByKey.values) {
      final definition = tool.definition;
      final enabledByActivation =
          definition.activation.isEnabledForExtensions(activeExtensions);
      if (enabledByActivation) {
        desired.add(definition.toolKey);
      }
    }
    return desired;
  }

  /// Get the last end context from the most recent session
  ///
  /// Returns the endContext from the last saved session within the last 24 hours,
  /// or null if not available. Contexts older than 24 hours are considered expired.
  Future<String?> getLastEndContext() async {
    try {
      final sessions = await _sessionRepository.getAll();
      if (sessions.isEmpty) {
        return null;
      }

      // Sort by end time descending to get the most recent
      sessions.sort((a, b) {
        final aTime = a.endTime ?? a.startTime;
        final bTime = b.endTime ?? b.startTime;
        return bTime.compareTo(aTime);
      });

      final lastSession = sessions.first;
      final sessionEndTime = lastSession.endTime ?? lastSession.startTime;
      final now = DateTime.now();
      final hoursSinceEnd = now.difference(sessionEndTime).inHours;

      // Context expires after 24 hours
      if (hoursSinceEnd > 24) {
        _logService.debug(
            _tag, 'Last end context expired ($hoursSinceEnd hours old)');
        return null;
      }

      final context = lastSession.endContext;

      if (context != null) {
        _logService.debug(_tag,
            'Retrieved last end context: $context ($hoursSinceEnd hours old)');
      }

      return context;
    } catch (e) {
      _logService.error(_tag, 'Failed to retrieve last end context: $e');
      return null;
    }
  }

  Future<void> _saveSession() async {
    if (_callStartTime == null || _callDuration == 0) {
      _logService.debug(_tag, 'Skipping session save (no meaningful data)');
      return;
    }

    try {
      // チャットメッセージをJSON文字列に変換
      final chatMessagesJson = _chatManager.chatMessages
          .map((msg) => jsonEncode({
                'role': msg.role,
                'content': msg.content,
                'timestamp': msg.timestamp.toIso8601String(),
              }))
          .toList();
      final sessionHistoryTabs = _openFiles
          .map(
            (file) => SessionNotepadTab(
              title: file.title,
              content: file.content,
              mimeType: file.mimeType,
            ),
          )
          .toList();

      final session = CallSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: _callStartTime!,
        endTime: DateTime.now(),
        duration: _callDuration,
        chatMessages: chatMessagesJson,
        notepadTabs: sessionHistoryTabs.isEmpty ? null : sessionHistoryTabs,
        speedDialId: _currentSpeedDialId,
        endContext: _endContext,
      );

      await _sessionRepository.save(session);
      _logService.info(_tag, 'セッション保存完了: ${session.id}');

      // セッション保存完了を通知（UIの更新用）
      _sessionSavedController.add(session.id);
    } catch (e) {
      _logService.error(_tag, 'セッション保存失敗: $e');
    }
  }

  Future<void> _cleanup() async {
    if (_isCleanedUp) {
      _logService.debug(_tag, 'Cleanup already completed, ignoring');
      return;
    }
    _isCleanedUp = true;

    _logService.debug(_tag, 'リソースのクリーンアップ');

    // Cancel all pending tool calls before cleanup
    _chatManager.cancelAllPendingToolCalls();
    _handleToolCallsCancelled(playSound: false);

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

    await _toolCallStartedSubscription?.cancel();
    _toolCallStartedSubscription = null;

    await _toolCallArgumentsDeltaSubscription?.cancel();
    _toolCallArgumentsDeltaSubscription = null;

    await _audioService.stopRecording();
    await _audioService.stop();
    await _apiClient.disconnect();

    // Disable wake lock to allow device to sleep normally
    await _disableWakeLock();

    // Dispose sandbox
    await _sandboxManager?.dispose();
    _sandboxManager = null;
    _toolConfig = const {};
    _allToolsByKey.clear();
    _voiceVisibleToolKeys = <String>{};
    _textVisibleToolKeys = <String>{};
    _hasSyncedVoiceTools = false;
    _hasSyncedTextTools = false;
    _isRefreshingToolset = false;
    _toolsetRefreshQueued = false;
    _openFiles = const [];
    if (!_openFilesController.isClosed) {
      _openFilesController.add(const []);
    }

    _callDuration = 0;
    _durationController.add(0);
    _amplitudeController.add(0.0);

    _logService.debug(_tag, 'Cleanup complete');
  }

  void _setState(CallState state) {
    _logService.info(_tag, 'State changed: $_currentState -> $state');
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
      _logService.info(_tag, 'Wake lock enabled');
    } catch (e) {
      _logService.error(_tag, 'Failed to enable wake lock: $e');
    }
  }

  /// Disable wake lock to allow device to sleep normally
  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      _logService.info(_tag, 'Wake lock disabled');
    } catch (e) {
      _logService.error(_tag, 'Failed to disable wake lock: $e');
    }
  }

  Map<String, dynamic>? _parseFunctionCallArguments(String argumentsJson) {
    final trimmed = argumentsJson.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _onToolCallExecuting(String callId) {
    _activeToolCallIds.add(callId);

    final wasEmpty = _executingToolCallIds.isEmpty;
    final added = _executingToolCallIds.add(callId);
    if (added && wasEmpty) {
      unawaited(_feedback.playToolExecuting());
    }
  }

  void _onToolCallCompleted(String callId) {
    _activeToolCallIds.remove(callId);
    _executingToolCallIds.remove(callId);

    if (_executingToolCallIds.isEmpty) {
      unawaited(_feedback.stopToolExecuting());
    }
  }

  void _onToolCallFailed(String callId) {
    _activeToolCallIds.remove(callId);
    _executingToolCallIds.remove(callId);

    if (_executingToolCallIds.isEmpty) {
      unawaited(_feedback.stopToolExecuting());
    }
    unawaited(_feedback.playToolError());
  }

  void _onToolCallFinished(String callId) {
    _activeToolCallIds.remove(callId);
    _executingToolCallIds.remove(callId);

    if (_executingToolCallIds.isEmpty) {
      unawaited(_feedback.stopToolExecuting());
    }
  }

  void _handleToolCallsCancelled({required bool playSound}) {
    final hadPendingToolCalls = _activeToolCallIds.isNotEmpty;

    _activeToolCallIds.clear();
    _executingToolCallIds.clear();

    unawaited(_feedback.stopToolExecuting());

    if (playSound && hadPendingToolCalls) {
      unawaited(_feedback.playToolCancelled());
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _cleanup();
    await _feedback.dispose();
    await _stateController.close();
    await _amplitudeController.close();
    await _durationController.close();
    await _errorController.close();
    await _sessionSavedController.close();
    await _openFilesController.close();
    await _chatManager.dispose();
  }
}
