import 'dart:async';
import 'dart:convert';

import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/services/call_control_api.dart';
import 'package:vagina/feat/call/services/call_filesystem_api.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/services/tool_runner.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
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
class CallService {
  final VoiceAgentInfo voiceAgent;
  final List<TextAgentInfo> textAgents;
  final VirtualFilesystemRepository _filesystemRepository;

  late final VirtualFilesystemService _filesystemService;
  late final RealtimeService _realtimeService;
  late final ToolRunner _toolRunner;
  late final NotepadService _notepadService;
  late final CallFilesystemApi _filesystemApi;

  /// Item IDs for function-call items that have already been dispatched
  /// (or are currently being executed). Prevents double-dispatch.
  final Set<String> _dispatchedToolCallIds = <String>{};

  /// Active file extensions from currently open files, used for dynamic tool
  /// visibility computation.
  Set<String> _currentActiveExtensions = <String>{};

  StreamSubscription<RealtimeThread>? _threadSubscription;

  final StreamController<List<Map<String, String>>> _openFilesController =
      StreamController<List<Map<String, String>>>.broadcast();

  CallState _state = CallState.uninitialized;

  CallService({
    required this.voiceAgent,
    this.textAgents = const [],
    required VirtualFilesystemRepository filesystemRepository,
  }) : _filesystemRepository = filesystemRepository;

  CallState get state => _state;

  Stream<List<Map<String, String>>> get openFilesStream =>
      _openFilesController.stream;

  Future<void> startCall() async {
    if (_state != CallState.uninitialized) {
      throw StateError(
          'startCall() can only be called from uninitialized state.');
    }

    await _initialize();
    _state = CallState.connecting;

    await _startCall();

    _state = CallState.active;
  }

  Future<void> _initialize() async {
    // Forward-create all internal services
    _filesystemService = VirtualFilesystemService(_filesystemRepository);

    _realtimeService = RealtimeService(voiceAgent: voiceAgent);

    _filesystemApi = CallFilesystemApi(
      filesystemService: _filesystemService,
      onActiveFilesChanged: _onActiveFilesChanged,
    );

    final callApi = CallControlApi(callService: this);

    final textAgentApi = _StubTextAgentApi();

    _toolRunner = ToolRunner(
      filesystemApi: _filesystemApi,
      callApi: callApi,
      textAgentApi: textAgentApi,
    );

    _notepadService = NotepadService();

    await Future.wait<void>([
      _realtimeService.start(),
      _toolRunner.start(
        enabledToolKeys: Set<String>.from(voiceAgent.enabledTools),
      ),
      _notepadService.start(),
    ]);
  }

  /// Register tools with the model and start watching for function calls.
  Future<void> _startCall() async {
    // 1. Register only tools whose activation matches the current active
    //    extension set (initially empty, so only always-available tools).
    _currentActiveExtensions = <String>{};
    final initialDefinitions = _toolRunner.enabledDefinitions.where((d) {
      return d.activation.isEnabledForExtensions(_currentActiveExtensions);
    }).toList();

    await _realtimeService.registerTools(initialDefinitions);

    // 2. Subscribe to thread updates and watch for completed function calls.
    _threadSubscription =
        _realtimeService.threadUpdates.listen(_onThreadUpdate);
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
      if (_state != CallState.disposing && _state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: result,
        );
      }
    } catch (e) {
      if (_state != CallState.disposing && _state != CallState.disposed) {
        await _realtimeService.sendFunctionOutput(
          callId: callId,
          output: jsonEncode({'error': e.toString()}),
        );
      }
    }
  }

  /// Called by [CallFilesystemApi] whenever the active file set changes.
  ///
  /// Emits to UI and recomputes visible tool sets based on active file
  /// extensions.
  void _onActiveFilesChanged(List<Map<String, String>> activeFiles) {
    // Emit to UI
    if (!_openFilesController.isClosed) {
      _openFilesController.add(activeFiles);
    }

    // Recompute tool visibility based on active file extensions
    final newExtensions = activeFiles
        .map((f) =>
            VirtualFile(path: f['path']!, content: '').extension.toLowerCase())
        .where((ext) => ext.isNotEmpty)
        .toSet();

    if (!_sameStringSet(_currentActiveExtensions, newExtensions)) {
      _currentActiveExtensions = newExtensions;
      unawaited(_refreshToolRegistration());
    }
  }

  /// Re-register tools with the model based on current active file extensions.
  Future<void> _refreshToolRegistration() async {
    if (_state != CallState.active) return;

    final definitions = _toolRunner.enabledDefinitions.where((d) {
      return d.activation.isEnabledForExtensions(_currentActiveExtensions);
    }).toList();

    await _realtimeService.registerTools(definitions);
  }

  bool _sameStringSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  Future<void> endCall({String? endContext}) async {
    if (_state == CallState.disposing || _state == CallState.disposed) {
      return;
    }

    _state = CallState.disposing;

    await _dispose();

    _state = CallState.disposed;
  }

  Future<void> _dispose() async {
    await _threadSubscription?.cancel();
    _threadSubscription = null;
    _dispatchedToolCallIds.clear();
    await _openFilesController.close();

    await Future.wait<void>([
      _realtimeService.dispose(),
      _toolRunner.dispose(),
      _notepadService.dispose(),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Stub API implementation (until text agents are wired)
// ---------------------------------------------------------------------------

final class _StubTextAgentApi implements TextAgentApi {
  @override
  Future<String> sendQuery(String agentId, String prompt) async {
    return jsonEncode({
      'error': 'Text agent API is not available in this session.',
    });
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return const <Map<String, dynamic>>[];
  }
}
