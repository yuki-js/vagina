import 'dart:async';
import 'dart:convert';

import 'package:vagina/feat/callv2/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/feat/callv2/models/voice_agent_info.dart';
import 'package:vagina/feat/callv2/services/call_control_api.dart';
import 'package:vagina/feat/callv2/services/call_filesystem_api.dart';
import 'package:vagina/feat/callv2/services/notepad_service.dart';
import 'package:vagina/feat/callv2/services/playback_service.dart';
import 'package:vagina/feat/callv2/services/realtime_service.dart';
import 'package:vagina/feat/callv2/services/recorder_service.dart';
import 'package:vagina/feat/callv2/services/tool_runner.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/feat/callv2/models/active_file.dart';
import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

/// One-way lifecycle state for a single call session.
enum CallState {
  uninitialized, // constructed, but start not triggered
  connecting, // starting session resources and connecting
  active, // connected, and call end not triggered
  disposing, // call end triggered, and cleanup in progress
  disposed, // cleanup completed, and service is no longer reusable
}

/// Session-scoped call service instantiated by the call screen.
///
/// Orchestrates all call-related services:
/// - NotepadService: active file management
/// - ToolRunner: tool catalog and execution
/// - RealtimeService: model connection
/// - RecorderService: microphone input
/// - PlaybackService: audio output
class CallService {
  VoiceAgentInfo? _voiceAgent;
  final List<TextAgentInfo> textAgents;
  final VirtualFilesystemRepository _filesystemRepository;

  late final VirtualFilesystemService _vfs;
  late final NotepadService _notepadService;
  late final CallFilesystemApi _filesystemApi;
  late final RealtimeService _realtimeService;
  late final RecorderService _recorderService;
  late final PlaybackService _playbackService;
  late final ToolRunner _toolRunner;
  late final Set<String> _exposedToolKeys;

  /// Item IDs for function-call items that have already been dispatched
  /// (or are currently being executed). Prevents double-dispatch.
  final Set<String> _dispatchedToolCallIds = <String>{};

  StreamSubscription<RealtimeThread>? _threadSubscription;
  StreamSubscription<void>? _assistantAudioCompletedSubscription;
  StreamSubscription<bool>? _userSpeakingStateSubscription;
  StreamSubscription<List<ActiveFile>>? _activeFilesSubscription;

  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _speakerMuteController =
      StreamController<bool>.broadcast();
  CallState _state = CallState.uninitialized;
  Timer? _callDurationTimer;
  DateTime? _callStartedAt;
  Duration _callDuration = Duration.zero;
  bool _speakerMuted = false;

  CallService({
    this.textAgents = const [],
    required VirtualFilesystemRepository filesystemRepository,
  }) : _filesystemRepository = filesystemRepository;

  CallState get state => _state;

  set state(CallState value) {
    if (_state == value) {
      return;
    }
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }

  Stream<CallState> get states => _stateController.stream;

  Stream<Duration> get durationStream => _durationController.stream;

  Duration get currentCallDuration => _callDuration;

  Stream<bool> get speakerMuteStates => _speakerMuteController.stream;

  bool get isSpeakerMuted => _speakerMuted;

  RecorderService get recorderService => _recorderService;

  PlaybackService get playbackService => _playbackService;

  NotepadService get notepadService => _notepadService;

  RealtimeService? get realtimeService {
    if (state == CallState.uninitialized || state == CallState.disposed) {
      return null;
    }
    return _realtimeService;
  }

  /// Stream of active files for UI.
  ///
  /// Re-exposes NotepadService.activeFiles for UI compatibility.
  Stream<List<ActiveFile>> get activeFilesStream => _notepadService.activeFiles;

  void setVoiceAgent(VoiceAgentInfo voiceAgent) {
    if (state != CallState.uninitialized) {
      throw StateError(
        'setVoiceAgent() can only be called from uninitialized state.',
      );
    }
    if (_voiceAgent != null) {
      throw StateError('Voice agent has already been set.');
    }

    _voiceAgent = voiceAgent;
  }

  Future<void> startCall() async {
    if (state != CallState.uninitialized) {
      throw StateError(
          'startCall() can only be called from uninitialized state.');
    }

    // 1. サービスインスタンス生成
    await _instantiateServices();

    // 2. 事前条件検証（fail-fast、この時点ではリソース未確保）
    await _checkPreconditions();

    state = CallState.connecting;

    // 3. リソース確保と接続（ここからはエラー時に dispose 必要）
    try {
      await _igniteCall();
      _startDurationTracking();
      state = CallState.active;
    } catch (e) {
      // リソース確保後のエラーなので cleanup が必要
      state = CallState.disposing;
      try {
        await _dispose();
      } catch (_) {
        // cleanup失敗は無視
      }
      rethrow;
    }
  }

  /// サービスインスタンス生成
  Future<void> _instantiateServices() async {
    // 1. Initialize VFS
    _vfs = VirtualFilesystemService(_filesystemRepository);
    await _vfs.initialize();

    // 2. Initialize NotepadService
    _notepadService = NotepadService(_vfs);

    // 3. Initialize CallFilesystemApi (adapter to NotepadService)
    _filesystemApi = CallFilesystemApi(notepadService: _notepadService);

    // 4. Initialize RealtimeService, RecorderService, PlaybackService
    _realtimeService = RealtimeService(voiceAgent: _voiceAgent!);
    _recorderService = RecorderService();
    _playbackService = PlaybackService();

    // 5. Initialize ToolRunner with dependencies
    _toolRunner = ToolRunner(
      filesystemApi: _filesystemApi,
      callApi: CallControlApi(callService: this),
    );

    _exposedToolKeys = Set<String>.from(_voiceAgent!.enabledTools);
  }

  /// 事前条件検証
  Future<void> _checkPreconditions() async {
    // Voice agent設定検証
    if (_voiceAgent == null) {
      throw StateError('Voice agent not set');
    }

    final config = _voiceAgent!.apiConfig;
    if (config is SelfhostedVoiceAgentApiConfig) {
      if (config.baseUrl.isEmpty || config.apiKey.isEmpty) {
        throw Exception('Realtime APIの設定が不完全です');
      }
    }

    // マイク権限検証
    final hasPermission = await _recorderService.hasPermission();
    if (!hasPermission) {
      throw Exception('マイクの使用を許可してください');
    }
  }

  /// リソース確保と接続開始
  Future<void> _igniteCall() async {
    await Future.wait<void>([
      _realtimeService.start(),
      _recorderService.start(),
      _playbackService.start(),
      _notepadService.start(),
      _toolRunner.start(),
    ]);

    _activeFilesSubscription =
        _notepadService.activeFiles.listen(_onActiveFilesChanged);

    final initialDefinitions = _computeExposedTools(<String>{});

    await _realtimeService.registerTools(initialDefinitions);
    await _recorderService.startRecordingSession();
    await _realtimeService.bindAudioInput(_recorderService.audioStream);
    await _playbackService
        .bindInputStream(_realtimeService.assistantAudioStream);

    // 2. Subscribe to thread updates and watch for completed function calls.
    _threadSubscription =
        _realtimeService.threadUpdates.listen(_onThreadUpdate);
    _assistantAudioCompletedSubscription =
        _realtimeService.assistantAudioCompleted.listen((_) {
      unawaited(_playbackService.markResponseComplete());
    });
    _userSpeakingStateSubscription =
        _realtimeService.userSpeakingStates.listen((isSpeaking) {
      if (!isSpeaking) {
        return;
      }
      unawaited(_interruptAssistantOutput());
    });
  }

  Future<void> interruptAssistantOutput() async {
    if (state != CallState.connecting && state != CallState.active) {
      return;
    }

    await _interruptAssistantOutput();
  }

  Future<void> setSpeakerMuted(bool muted) async {
    if (state == CallState.uninitialized || state == CallState.disposed) {
      return;
    }
    if (_speakerMuted == muted) {
      return;
    }

    _speakerMuted = muted;
    if (!_speakerMuteController.isClosed) {
      _speakerMuteController.add(_speakerMuted);
    }
    if (_speakerMuted) {
      await _playbackService.interrupt();
    }
    await _playbackService.setVolume(_speakerMuted ? 0.0 : 1.0);
  }

  Future<void> toggleSpeakerMuted() async {
    await setSpeakerMuted(!_speakerMuted);
  }

  Future<void> sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state != CallState.active) {
      return;
    }

    await _interruptAssistantOutput();
    await _realtimeService.sendText(trimmed);
  }

  /// Called on every thread mutation. Scans for completed function-call items
  /// that have not yet been dispatched.
  void _onThreadUpdate(RealtimeThread thread) {
    for (final item in thread.items) {
      if (item.type != RealtimeThreadItemType.functionCall) {
        continue;
      }
      if (item.status != RealtimeThreadItemStatus.completed) {
        continue;
      }
      if (_dispatchedToolCallIds.contains(item.id)) {
        continue;
      }
      // Mark dispatched immediately to prevent duplicate execution.
      _dispatchedToolCallIds.add(item.id);
      // Fire and forget — errors are caught inside _executeTool.
      unawaited(_executeTool(item));
    }
  }

  Future<void> _interruptAssistantOutput() async {
    await _playbackService.interrupt();
    if (_realtimeService.isConnected) {
      await _realtimeService.interrupt();
    }
  }

  /// Execute a single tool call and send the result back to the model.
  Future<void> _executeTool(RealtimeThreadItem item) async {
    final callId = item.callId;
    final name = item.name;
    final arguments = item.arguments;

    if (callId == null || callId.isEmpty) {
      return;
    }
    if (name == null || name.isEmpty) {
      const errorMessage = 'Missing tool name.';
      await _realtimeService.sendFunctionOutput(
        callId: callId,
        output: jsonEncode({'error': errorMessage}),
        disposition: RealtimeToolOutputDisposition.error,
        errorMessage: errorMessage,
      );
      return;
    }

    try {
      final result = await _toolRunner.execute(
        name,
        arguments ?? '{}',
      );
      final outputMetadata = _deriveToolOutputMetadata(result);
      // Only send if we haven't started disposing.
      if (state != CallState.disposing && state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: result,
          disposition: outputMetadata.disposition,
          errorMessage: outputMetadata.errorMessage,
        );
      }
    } catch (e) {
      final errorMessage = e.toString();
      if (state != CallState.disposing && state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: jsonEncode({'error': errorMessage}),
          disposition: RealtimeToolOutputDisposition.error,
          errorMessage: errorMessage,
        );
      }
    }
  }

  _ToolOutputMetadata _deriveToolOutputMetadata(String output) {
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        return _ToolOutputMetadata(
          disposition: RealtimeToolOutputDisposition.error,
          errorMessage: decoded['error'].toString(),
        );
      }
    } catch (_) {
      // Non-JSON output is treated as a successful tool result.
    }

    return const _ToolOutputMetadata(
      disposition: RealtimeToolOutputDisposition.success,
    );
  }

  List<ToolDefinition> _computeExposedTools(Set<String> activeExtensions) {
    final availableDefinitions = _toolRunner.computeAvailableTools(
      activeExtensions,
    );

    return availableDefinitions
        .where((definition) => _exposedToolKeys.contains(definition.toolKey))
        .toList(growable: false);
  }

  /// Called whenever active files change via NotepadService stream.
  ///
  /// Recomputes visible tool sets based on active file extensions and
  /// re-registers tools with the model.
  void _onActiveFilesChanged(List<ActiveFile> activeFiles) {
    // Extract extensions from active files
    final extensions = activeFiles
        .map((file) => file.extension.toLowerCase())
        .where((ext) => ext.isNotEmpty)
        .toSet();

    final definitions = _computeExposedTools(extensions);

    // Re-register tools with the model
    if (state == CallState.active) {
      unawaited(_realtimeService.registerTools(definitions));
    }
  }

  void _startDurationTracking() {
    _callDurationTimer?.cancel();
    _callStartedAt = DateTime.now();
    _callDuration = Duration.zero;

    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final callStartedAt = _callStartedAt;
      if (callStartedAt == null) {
        return;
      }

      _callDuration = DateTime.now().difference(callStartedAt);
      if (!_durationController.isClosed) {
        _durationController.add(_callDuration);
      }
    });
  }

  Future<void> endCall({String? endContext}) async {
    if (state == CallState.disposing || state == CallState.disposed) {
      return;
    }

    state = CallState.disposing;

    // Persist all active files before cleanup - エラーがあっても継続
    try {
      await _notepadService.persistAll();
      _notepadService.exportSessionTabs();
      // TODO: Save exported session tabs to CallSession when session repository is wired
      await _dispose();
    } catch (e) {
      // 継続
    }
  }

  Future<void> _dispose() async {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    await _threadSubscription?.cancel();
    _threadSubscription = null;
    await _assistantAudioCompletedSubscription?.cancel();
    _assistantAudioCompletedSubscription = null;
    await _userSpeakingStateSubscription?.cancel();
    _userSpeakingStateSubscription = null;
    await _activeFilesSubscription?.cancel();
    _activeFilesSubscription = null;
    _dispatchedToolCallIds.clear();
    await _realtimeService.unbindAudioInput();
    await _playbackService.unbindInputStream();
    await _recorderService.stopRecordingSession();

    await Future.wait<void>([
      _realtimeService.dispose(),
      _recorderService.dispose(),
      _playbackService.dispose(),
      _toolRunner.dispose(),
      _notepadService.dispose(),
    ]);

    state = CallState.disposed;
    await _durationController.close();
    await _speakerMuteController.close();
    await _stateController.close();
  }
}

final class _ToolOutputMetadata {
  final RealtimeToolOutputDisposition disposition;
  final String? errorMessage;

  const _ToolOutputMetadata({
    required this.disposition,
    this.errorMessage,
  });
}
