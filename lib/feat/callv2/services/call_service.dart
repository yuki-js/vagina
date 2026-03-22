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
  final VoiceAgentInfo voiceAgent;
  final List<TextAgentInfo> textAgents;
  final VirtualFilesystemRepository _filesystemRepository;

  late final VirtualFilesystemService _vfs;
  late final NotepadService _notepadService;
  late final CallFilesystemApi _filesystemApi;
  late final RealtimeService _realtimeService;
  late final RecorderService _recorderService;
  late final PlaybackService _playbackService;
  late final ToolRunner _toolRunner;

  /// Item IDs for function-call items that have already been dispatched
  /// (or are currently being executed). Prevents double-dispatch.
  final Set<String> _dispatchedToolCallIds = <String>{};

  StreamSubscription<RealtimeThread>? _threadSubscription;
  StreamSubscription<void>? _assistantAudioCompletedSubscription;
  StreamSubscription<List<ActiveFile>>? _activeFilesSubscription;

  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  CallState _state = CallState.uninitialized;

  CallService({
    required this.voiceAgent,
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

  RecorderService get recorderService => _recorderService;

  PlaybackService get playbackService => _playbackService;

  NotepadService get notepadService => _notepadService;

  /// Stream of active files for UI.
  ///
  /// Re-exposes NotepadService.activeFiles for UI compatibility.
  Stream<List<ActiveFile>> get activeFilesStream => _notepadService.activeFiles;

  Future<void> startCall() async {
    if (state != CallState.uninitialized) {
      throw StateError(
          'startCall() can only be called from uninitialized state.');
    }

    await _initialize();
    state = CallState.connecting;

    await _startCall();

    state = CallState.active;
  }

  Future<void> _initialize() async {
    // 1. Initialize VFS
    _vfs = VirtualFilesystemService(_filesystemRepository);
    await _vfs.initialize();

    // 2. Initialize NotepadService
    _notepadService = NotepadService(_vfs);

    // 3. Initialize CallFilesystemApi (adapter to NotepadService)
    _filesystemApi = CallFilesystemApi(notepadService: _notepadService);

    // 4. Initialize RealtimeService, RecorderService, PlaybackService
    _realtimeService = RealtimeService(voiceAgent: voiceAgent);
    _recorderService = RecorderService();
    _playbackService = PlaybackService();

    // 5. Initialize ToolRunner with dependencies
    _toolRunner = ToolRunner(
      filesystemApi: _filesystemApi,
      callApi: CallControlApi(callService: this),
    );

    // 6. Start all services
    await Future.wait<void>([
      _realtimeService.start(),
      _recorderService.start(),
      _playbackService.start(),
      _notepadService.start(),
      _toolRunner.start(
        enabledToolKeys: Set<String>.from(voiceAgent.enabledTools),
      ),
    ]);

    // 7. Subscribe to activeFiles stream and update tool registration
    _activeFilesSubscription =
        _notepadService.activeFiles.listen(_onActiveFilesChanged);
  }

  /// Register tools with the model and start watching for function calls.
  Future<void> _startCall() async {
    // 1. Register only tools whose activation matches the current active
    //    extension set (initially empty, so only always-available tools).
    final initialDefinitions = _toolRunner.computeAvailableTools(<String>{});

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

  /// Execute a single tool call and send the result back to the model.
  Future<void> _executeTool(RealtimeThreadItem item) async {
    final callId = item.callId;
    final name = item.name;
    final arguments = item.arguments;

    if (callId == null || callId.isEmpty) {
      return;
    }
    if (name == null || name.isEmpty) {
      await _realtimeService.sendFunctionOutput(
        callId: callId,
        output: jsonEncode({'error': 'Missing tool name.'}),
      );
      return;
    }

    try {
      final result = await _toolRunner.execute(
        name,
        arguments ?? '{}',
      );
      // Only send if we haven't started disposing.
      if (state != CallState.disposing && state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: result,
        );
      }
    } catch (e) {
      if (state != CallState.disposing && state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: jsonEncode({'error': e.toString()}),
        );
      }
    }
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

    // Compute available tools based on extensions
    final definitions = _toolRunner.computeAvailableTools(extensions);

    // Re-register tools with the model
    if (state == CallState.active) {
      unawaited(_realtimeService.registerTools(definitions));
    }
  }

  Future<void> endCall({String? endContext}) async {
    if (state == CallState.disposing || state == CallState.disposed) {
      return;
    }

    state = CallState.disposing;

    // Persist all active files before cleanup
    await _notepadService.persistAll();

    // Export session tabs (could be used for session saving)
    _notepadService.exportSessionTabs();
    // TODO: Save exported session tabs to CallSession when session repository is wired

    await _dispose();

    state = CallState.disposed;
    await _stateController.close();
  }

  Future<void> _dispose() async {
    await _threadSubscription?.cancel();
    _threadSubscription = null;
    await _assistantAudioCompletedSubscription?.cancel();
    _assistantAudioCompletedSubscription = null;
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
  }
}
