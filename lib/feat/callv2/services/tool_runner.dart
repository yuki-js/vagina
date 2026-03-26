import 'dart:convert';

import 'package:vagina/feat/callv2/services/subservice.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/tools.dart';

/// Session-scoped tool runner backing service for a single call.
///
/// Pure tool catalog and execution engine. Does not subscribe to streams,
/// hold active file state, or decide whether a tool may be called.
/// Tool definition visibility is computed on-demand via
/// [computeAvailableTools].
final class ToolRunner extends SubService {
  final FilesystemApi _filesystemApi;
  final CallApi _callApi;
  final TextAgentApi _textAgentApi;
  final Toolbox _toolbox = RootToolbox();

  final Map<String, Tool> _tools = <String, Tool>{};

  ToolRunner({
    required FilesystemApi filesystemApi,
    required CallApi callApi,
    required TextAgentApi textAgentApi,
  })  : _filesystemApi = filesystemApi,
        _callApi = callApi,
        _textAgentApi = textAgentApi;

  /// Tool definitions registered for this session.
  List<ToolDefinition> get allDefinitions {
    return _tools.values.map((t) => t.definition).toList(growable: false);
  }

  /// Compute tool definitions exposed to the model based on active file
  /// extensions.
  ///
  /// Filters the session-registered tool definitions by extension activation
  /// rules for each tool.
  ///
  /// Returns a fresh list of tool definitions on each call.
  List<ToolDefinition> computeAvailableTools(Set<String> activeExtensions) {
    if (!isStarted) {
      return const [];
    }

    // Normalize extensions to lowercase for comparison
    final normalizedExtensions =
        activeExtensions.map((ext) => ext.toLowerCase()).toSet();

    return _tools.values
        .where((tool) {
          final activation = tool.definition.activation;

          // Filter by extension activation rules
          return activation.isEnabledForExtensions(normalizedExtensions);
        })
        .map((tool) => tool.definition)
        .toList(growable: false);
  }

  @override
  Future<void> start() async {
    await super.start();

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
  }

  /// Execute a tool by its key with JSON-encoded arguments.
  ///
  /// Returns the tool result as a JSON string.
  /// Throws if the tool key is unknown or the tool throws.
  Future<String> execute(String toolKey, String argumentsJson) async {
    ensureNotDisposed();
    if (!isStarted) {
      throw StateError('ToolRunner has not been started.');
    }

    final tool = _tools[toolKey];
    if (tool == null) {
      return jsonEncode({
        'error': 'Unknown tool: $toolKey',
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

  @override
  Future<void> dispose() async {
    await super.dispose();
    _tools.clear();
  }
}
