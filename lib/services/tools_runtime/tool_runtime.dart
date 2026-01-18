import 'dart:convert';

import 'tool.dart';
import 'tool_context.dart';

/// Per-call container for tool instances.
class ToolRuntime {
  final ToolContext context;
  final Map<String, Tool> _toolsByKey;

  ToolRuntime({
    required this.context,
    required Map<String, Tool> toolsByKey,
  }) : _toolsByKey = Map<String, Tool>.from(toolsByKey);

  /// Realtime API compatible tool definitions (function tools).
  List<Map<String, dynamic>> get toolDefinitionsForRealtime {
    return _toolsByKey.values
        .map((t) => t.definition.toRealtimeJson())
        .toList(growable: false);
  }

  /// Executes a tool by key.
  ///
  /// [args] must already be parsed from JSON.
  ///
  /// This method never throws for predictable behavior when used by adapters
  /// that expect legacy-style JSON error payloads.
  Future<String> execute({
    required String toolKey,
    required Map<String, dynamic> args,
  }) async {
    final tool = _toolsByKey[toolKey];
    if (tool == null) {
      return jsonEncode({'error': 'Unknown tool: $toolKey'});
    }

    try {
      await tool.init();
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }

    try {
      return await tool.execute(args, context);
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  /// Returns a tool instance by key, if present.
  Tool? getTool(String toolKey) => _toolsByKey[toolKey];

  /// Returns the set of tool keys currently present.
  List<String> get toolKeys => _toolsByKey.keys.toList(growable: false);
}
