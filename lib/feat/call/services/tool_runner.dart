import 'dart:convert';

import 'package:vagina/feat/call/services/call_control_api.dart';
import 'package:vagina/feat/call/services/call_filesystem_api.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';
import 'package:vagina/tools/tools.dart';

/// Session-scoped tool runner backing service for a single call.
///
/// Executes tools in-process (no isolate). Safe because builtin tools are
/// pure-Dart with no blocking I/O.
class ToolRunner {
  late final VirtualFilesystemService _filesystemService;
  late final FilesystemApi _filesystemApi;
  late final CallApi _callApi;
  late final TextAgentApi _textAgentApi;
  final Toolbox _toolbox = RootToolbox();

  final Map<String, Tool> _tools = <String, Tool>{};
  Set<String> _enabledToolKeys = <String>{};
  bool _started = false;

  ToolRunner({
    required VirtualFilesystemRepository filesystemRepository,
    required void Function(List<Map<String, String>>) onActiveFilesChanged,
    required CallService callService,
  }) {
    _filesystemService = VirtualFilesystemService(filesystemRepository);
    _filesystemApi = CallFilesystemApi(
      filesystemService: _filesystemService,
      onActiveFilesChanged: onActiveFilesChanged,
    );
    _callApi = CallControlApi(callService: callService);
    _textAgentApi = const _StubTextAgentApi();
  }

  /// Whether [start] has been called.
  bool get isStarted => _started;

  /// Tool definitions for the currently enabled tools.
  ///
  /// Only meaningful after [start] has been called.
  List<ToolDefinition> get enabledDefinitions {
    if (_enabledToolKeys.isEmpty) {
      return _tools.values.map((t) => t.definition).toList(growable: false);
    }
    return _tools.entries
        .where((e) => _enabledToolKeys.contains(e.key))
        .map((e) => e.value.definition)
        .toList(growable: false);
  }

  /// All registered tool definitions regardless of enabled state.
  List<ToolDefinition> get allDefinitions {
    return _tools.values.map((t) => t.definition).toList(growable: false);
  }

  /// Instantiate and initialise every tool from the toolbox.
  Future<void> start({
    Set<String> enabledToolKeys = const <String>{},
  }) async {
    if (_started) {
      return;
    }

    _enabledToolKeys = Set<String>.from(enabledToolKeys);
    await _filesystemService.initialize();

    for (final tool in _toolbox.tools) {
      final key = tool.definition.toolKey;
      final context = ToolContext(
        toolKey: key,
        callApi: _callApi,
        filesystemApi: _filesystemApi,
        textAgentApi: _textAgentApi,
      );
      await tool.init(context);
      _tools[key] = tool;
    }

    _started = true;
  }

  /// Execute a tool by its key with JSON-encoded arguments.
  ///
  /// Returns the tool result as a JSON string.
  /// Throws if the tool key is unknown or the tool throws.
  Future<String> execute(String toolKey, String argumentsJson) async {
    if (!_started) {
      throw StateError('ToolRunner has not been started.');
    }

    final tool = _tools[toolKey];
    if (tool == null) {
      return jsonEncode({
        'error': 'Unknown tool: $toolKey',
      });
    }
    if (_enabledToolKeys.isNotEmpty && !_enabledToolKeys.contains(toolKey)) {
      return jsonEncode({
        'error': 'Tool is not enabled for this session: $toolKey',
      });
    }

    final Map<String, dynamic> args;
    try {
      final decoded = jsonDecode(argumentsJson);
      args = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return jsonEncode({
        'error': 'Invalid JSON arguments for tool $toolKey.',
      });
    }

    return tool.execute(args);
  }

  /// Release resources.
  Future<void> dispose() async {
    _tools.clear();
    _enabledToolKeys.clear();
    _started = false;
  }
}

final class _StubTextAgentApi implements TextAgentApi {
  const _StubTextAgentApi();

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
