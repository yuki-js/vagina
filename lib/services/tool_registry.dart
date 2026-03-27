import 'package:vagina/services/tool_metadata.dart';
import 'package:vagina/tools/tools.dart';

/// Service that provides UI-facing tool metadata from the runtime toolbox.
///
/// This bridges the Flutter-free tool runtime with the Flutter UI layer.
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._internal();
  factory ToolRegistry() => _instance;
  ToolRegistry._internal();

  /// Get all registered tool metadata for UI display.
  List<ToolMetadata> get registeredToolMeta {
    final toolbox = RootToolbox();
    final tools = toolbox.tools;

    return tools.map((tool) {
      final def = tool.definition;
      return ToolMetadata(
        name: def.toolKey,
        displayName: def.displayName,
        displayDescription: def.displayDescription,
        description: def.description,
        iconKey: def.iconKey,
        category: ToolCategory.fromKey(def.categoryKey),
        source: ToolSource.fromKey(def.sourceKey),
        mcpServerUrl: def.mcpServerUrl,
      );
    }).toList();
  }
}
