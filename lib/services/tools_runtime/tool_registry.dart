import 'tool.dart';
import 'tool_context.dart';
import 'tool_definition.dart';
import 'tool_factory.dart';
import 'tool_runtime.dart';

/// App-scope registry of [ToolFactory] instances.
///
/// This is the entrypoint for assembling a per-call [ToolRuntime].
///
/// ## Definition caching semantics
/// - The registry holds factories, not tool instances.
/// - [listDefinitions] lazily builds and caches a snapshot of tool definitions.
///   On the first call it instantiates each registered factory once to read
///   [Tool.definition], then discards those instances.
/// - Subsequent calls to [listDefinitions] return the cached list without
///   instantiating any tools.
/// - [invalidateCache] clears cached definitions.
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._internal();

  factory ToolRegistry() => _instance;

  ToolRegistry._internal();

  final List<ToolFactory> _factories = <ToolFactory>[];

  List<ToolDefinition>? _cachedDefinitions;

  /// Registers a factory at app scope.
  ///
  /// Registering a new factory invalidates any cached definitions.
  void registerFactory(ToolFactory factory) {
    _factories.add(factory);
    invalidateCache();
  }

  /// Clears cached definitions produced by [listDefinitions].
  void invalidateCache() {
    _cachedDefinitions = null;
  }

  /// Lists tool definitions known to the registry.
  ///
  /// On the first call, this method will:
  /// - Instantiate each factory via [ToolFactory.createTool]
  /// - Read [Tool.definition]
  /// - Cache and return the resulting list
  ///
  /// On subsequent calls, it returns the cached list without instantiating tools.
  ///
  /// This method never calls [Tool.init].
  List<ToolDefinition> listDefinitions() {
    final cached = _cachedDefinitions;
    if (cached != null) {
      return cached;
    }

    final definitionsByKey = <String, ToolDefinition>{};
    for (final factory in _factories) {
      final tool = factory.createTool();
      final definition = tool.definition;
      definitionsByKey[definition.toolKey] = definition;
    }

    final definitions = definitionsByKey.values.toList(growable: false);
    _cachedDefinitions = definitions;
    return definitions;
  }

  /// Builds a per-call runtime containing fresh tool instances.
  ///
  /// Instances created here are always fresh (per-call) and are never reused
  /// from [listDefinitions].
  ToolRuntime buildRuntimeForCall(ToolContext context) {
    final toolsByKey = <String, Tool>{};
    for (final factory in _factories) {
      final tool = factory.createTool();
      toolsByKey[tool.definition.toolKey] = tool;
    }

    return ToolRuntime(
      context: context,
      toolsByKey: toolsByKey,
    );
  }
}
