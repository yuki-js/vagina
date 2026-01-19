import 'tool_context.dart';
import 'tool_definition.dart';

/// Tool runtime interface.
///
/// Implementations should be Flutter-free.
abstract class Tool {
  ToolDefinition get definition;

  late final ToolContext context;

  Future<void> init(ToolContext c) async {
    context = c;
    toWorker();
  }

  Future<String> execute(Map<String, dynamic> args);

  static Tool fromWorker(Map<String, dynamic> json) {
    final toolKey = json['toolKey'] as String;
    if (_toolCache.containsKey(toolKey)) {
      return _toolCache[toolKey]!;
    }
    throw Exception('Tool not found: $toolKey');
  }

  Map<String, dynamic> toWorker() {
    _toolCache[definition.toolKey] = this;
    return {
      'toolKey': definition.toolKey,
      '_badge': "ToolInstance",
    };
  }
}

Map<String, Tool> _toolCache = {};
