import 'dart:convert';

import 'package:vagina/services/tools/base_tool.dart';

import 'tool.dart';
import 'tool_context.dart';
import 'tool_definition.dart';

/// Adapts a legacy [BaseTool] to the new tools_runtime [Tool] interface.
///
/// The adapter preserves the legacy payload contract from
/// [BaseTool.executeWithResult]:
/// - success => `jsonEncode(resultMap)`
/// - error => `jsonEncode({'error': e.toString()})`
class LegacyBaseToolAdapter implements Tool {
  final BaseTool _legacy;
  final ToolDefinition _definition;
  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  LegacyBaseToolAdapter(BaseTool legacy)
      : _legacy = legacy,
        _definition = ToolDefinition(
          toolKey: legacy.name,
          displayName: legacy.metadata.displayName,
          displayDescription: legacy.metadata.displayDescription,
          categoryKey: legacy.metadata.category.name,
          iconKey: legacy.metadata.iconKey,
          sourceKey: legacy.metadata.source.name,
          mcpServerUrl: legacy.metadata.mcpServerUrl,
          description: legacy.description,
          parametersSchema: legacy.parameters,
        );

  /// The wrapped legacy tool instance.
  BaseTool get legacy => _legacy;

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    try {
      final result = await _legacy.execute(args);
      return jsonEncode(result);
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }
}
