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
      logger.fine('computeAvailableTools called before service started');
      return const [];
    }

    // Normalize extensions to lowercase for comparison
    final normalizedExtensions =
        activeExtensions.map((ext) => ext.toLowerCase()).toSet();

    final availableTools = _tools.values
        .where((tool) {
          final activation = tool.definition.activation;

          // Filter by extension activation rules
          return activation.isEnabledForExtensions(normalizedExtensions);
        })
        .map((tool) => tool.definition)
        .toList(growable: false);

    logger.fine(
        'Computed available tools: ${availableTools.length}/${_tools.length} (extensions: ${normalizedExtensions.join(", ")})');
    return availableTools;
  }

  @override
  Future<void> start() async {
    await super.start();

    logger.info('Starting ToolRunner with ${_toolbox.tools.length} tools');

    for (final tool in _toolbox.tools) {
      final key = tool.definition.toolKey;
      final context = ToolContext(
        toolKey: key,
        callApi: _callApi,
        filesystemApi: _filesystemApi,
        textAgentApi: _textAgentApi,
      );
      logger.fine('Initializing tool: $key');
      await tool.init(context);
      _tools[key] = tool;
    }

    logger.info('ToolRunner started successfully with ${_tools.length} tools');
  }

  /// Execute a tool by its key with JSON-encoded arguments.
  ///
  /// Returns the tool result as a JSON string.
  /// Throws if the tool key is unknown or the tool throws.
  Future<String> execute(String toolKey, String argumentsJson) async {
    ensureNotDisposed();
    if (!isStarted) {
      logger.severe('Tool execution attempted before service started: $toolKey');
      throw StateError('ToolRunner has not been started.');
    }

    logger.info('Executing tool: $toolKey');
    logger.fine('Tool arguments: $argumentsJson');

    final tool = _tools[toolKey];
    if (tool == null) {
      logger.warning('Unknown tool requested: $toolKey');
      return jsonEncode({
        'error': 'Unknown tool: $toolKey',
      });
    }
    
    final Map<String, dynamic> args;
    try {
      final decoded = jsonDecode(argumentsJson);
      args = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (e, stackTrace) {
      logger.warning('Invalid JSON arguments for tool $toolKey', e, stackTrace);
      return jsonEncode({
        'error': 'Invalid JSON arguments for tool $toolKey.',
      });
    }

    try {
      final result = await tool.execute(args);
      logger.info('Tool execution completed: $toolKey');
      logger.fine('Tool result length: ${result.length} chars');
      return result;
    } catch (e, stackTrace) {
      logger.severe('Tool execution failed: $toolKey', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing ToolRunner (${_tools.length} tools)');
    await super.dispose();
    _tools.clear();
    logger.info('ToolRunner disposed successfully');
  }
}
