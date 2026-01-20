import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemoryRecallTool extends Tool {
  static const String toolKeyName = 'memory_recall';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'メモリ検索',
        displayDescription: '記憶した情報を検索します',
        categoryKey: 'memory',
        iconKey: 'search',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Recall information from long-term memory. Use this when you need to remember something the user previously asked you to save.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description':
                  'The key of the memory to recall. Use "all" to get all stored memories.',
            },
          },
          'required': ['key'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final key = args['key'] as String;

    if (key == 'all') {
      // Use tool-isolated storage (toolStorageApi)
      // This returns only memories for this specific tool
      final allMemories = await context.toolStorageApi.list();
      return jsonEncode({
        'success': true,
        'memories': allMemories,
      });
    }

    // Use tool-isolated storage (toolStorageApi)
    final value = await context.toolStorageApi.get(key);
    if (value == null) {
      return jsonEncode({
        'success': false,
        'message': 'Memory not found for key: $key',
      });
    }

    return jsonEncode({
      'success': true,
      'key': key,
      'value': value,
    });
  }
}
