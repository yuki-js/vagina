import 'tool.dart';
import 'tool_context.dart';
import 'tool_definition.dart';
import 'tool_factory.dart';
import 'tool_runtime.dart';

/// App-scope registry of [ToolFactory] instances.
///
/// This is the entrypoint for assembling a per-call [ToolRuntime].
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._internal();

  factory ToolRegistry() => _instance;

  ToolRegistry._internal();

  final Map<String, ToolFactory> _factoriesByKey = {};
  final Map<String, ToolDefinition> _definitionsByKey = {};

  /// Registers a factory at app scope.
  ///
  /// The tool key is derived from the tool instance created by [factory].
  void registerFactory(ToolFactory factory) {
    final tool = factory.createTool();
    final definition = tool.definition;

    _factoriesByKey[definition.toolKey] = factory;
    _definitionsByKey[definition.toolKey] = definition;
  }

  /// Lists tool definitions known to the registry.
  List<ToolDefinition> listDefinitions() {
    return _definitionsByKey.values.toList(growable: false);
  }

  /// Builds a per-call runtime containing fresh tool instances.
  ToolRuntime buildRuntimeForCall(ToolContext context) {
    final toolsByKey = <String, Tool>{};
    for (final entry in _factoriesByKey.entries) {
      toolsByKey[entry.key] = entry.value.createTool();
    }

    return ToolRuntime(
      context: context,
      toolsByKey: toolsByKey,
    );
  }
}
