import 'package:vagina/models/tool_metadata.dart';
import 'package:vagina/tools/tools.dart';

/// Provides UI-facing tool metadata from the runtime toolbox.
///
/// This bridges the Flutter-free tool runtime with the Flutter UI layer.
List<ToolMetadata> registeredToolMetadata() {
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
