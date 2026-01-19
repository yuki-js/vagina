import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

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
            'Delete information from long-term memory. Use this when the user asks you to forget something.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description':
                  'The key of the memory to delete. Use "all" to delete all memories.',
            },
          },
          'required': ['key'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final key = args['key'] as String;

    if (key == 'all') {
      final allMemories = await context.memoryApi.list();
      for (final memoryKey in allMemories.keys) {
        await context.memoryApi.delete(memoryKey);
      }
      return jsonEncode({
        'success': true,
        'message': 'All memories deleted successfully',
      });
    }

    final existed = await context.memoryApi.delete(key);
    if (!existed) {
      return jsonEncode({
        'success': false,
        'message': 'Memory not found for key: $key',
      });
    }

    return jsonEncode({
      'success': true,
      'message': 'Memory deleted successfully',
      'key': key,
    });
  }
}
