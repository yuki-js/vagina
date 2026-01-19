import 'tool.dart';
import 'tool_definition.dart';
import 'tool_factory.dart';

/// App-scope registry of [ToolFactory] instances.
///
/// This is the entrypoint for assembling a per-call [ToolRuntime].
///
/// ## Definition caching semantics
/// - The registry holds factories, not tool instances.
///   On the first call it instantiates each registered factory once to read
///   [Tool.definition], then discards those instances.
class ToolRegistry {
  ToolRegistry();

  final List<ToolFactory> _factories = <ToolFactory>[];

  /// Registers a factory at registry scope.
  void registerFactory(ToolFactory factory) {
    _factories.add(factory);
  }

  /// Clears cached definitions produced by [listDefinitions].
  void invalidateCache() {}

  /// Lists tool definitions known to the registry.
  ///
  /// On the first call, this method will:
  /// - Instantiate each factory via [ToolFactory.createTool]
  /// - Read [Tool.definition]
  ///
  /// On subsequent calls, it returns the cached list without instantiating tools.
  ///
  /// This method never calls [Tool.init].
  List<ToolDefinition> listDefinitions() {
    final definitionsByKey = <String, ToolDefinition>{};
    for (final factory in _factories) {
      final tool = factory.createTool();
      final definition = tool.definition;
      definitionsByKey[definition.toolKey] = definition;
    }

    final definitions = definitionsByKey.values.toList(growable: false);
    return definitions;
  }
}
