import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Tool to delete information from tool-isolated storage
/// 
/// Each tool has its own isolated memory namespace.
/// Deletion only affects the current tool's memories.
class MemoryDeleteTool extends Tool {
  static const String toolKeyName = 'memory_delete';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'メモリ削除',
        displayDescription: '記憶した情報を削除します',
        categoryKey: 'memory',
        iconKey: 'delete',
        sourceKey: 'builtin',
        description:
            'Delete information from tool-isolated long-term storage. '
            'Use this when the user asks you to forget something. '
            'Each tool only sees and deletes its own isolated memories.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description':
                  'The key of the memory to delete. Use "all" to delete all memories for this tool.',
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
      // This only deletes memories from this specific tool
      final allMemories = await context.toolStorageApi.list();
      for (final memoryKey in allMemories.keys) {
        await context.toolStorageApi.delete(memoryKey);
      }
      return jsonEncode({
        'success': true,
        'message': 'All memories deleted successfully (tool-isolated storage)',
      });
    }

    // Use tool-isolated storage (toolStorageApi)
    final existed = await context.toolStorageApi.delete(key);
    if (!existed) {
      return jsonEncode({
        'success': false,
        'message': 'Memory not found for key: $key (tool-isolated storage)',
      });
    }

    return jsonEncode({
      'success': true,
      'message': 'Memory deleted successfully (tool-isolated storage)',
      'key': key,
    });
  }
}
