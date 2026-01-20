import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemorySaveTool extends Tool {
  static const String toolKeyName = 'memory_save';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'メモリ保存',
        displayDescription: '重要な情報を記憶します',
        categoryKey: 'memory',
        iconKey: 'save',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description':
                  'A unique key to identify this memory (e.g., "user_name", "favorite_color")',
            },
            'value': {
              'type': 'string',
              'description': 'The information to remember',
            },
          },
          'required': ['key', 'value'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final key = args['key'] as String;
    final value = args['value'] as String;

    // Use tool-isolated storage (toolStorageApi)
    // Each tool has its own namespace, so this memory is isolated per tool
    await context.toolStorageApi.save(key, value);

    return jsonEncode({
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    });
  }
}
