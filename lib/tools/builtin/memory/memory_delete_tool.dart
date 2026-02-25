import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Tool to delete information from long-term memory.
///
/// Storage may be shared across tools from the same publisher.
/// This tool only touches entries under the `memory/` prefix to avoid deleting
/// other tools' data.
class MemoryDeleteTool extends Tool {
  static const String toolKeyName = 'memory_delete';

  /// Sub-namespace under the publisher-level storage namespace.
  static const String _memoryKeyPrefix = 'memory/';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'メモリ削除',
        displayDescription: '記憶した情報を削除します',
        categoryKey: 'memory',
        iconKey: 'delete',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description: 'Delete information from tool-isolated long-term storage. '
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
      final allEntries = (await context.toolStorageApi.list())[
          "data"]; // todo: list関数はdataをunwrapするべきだ。このレイヤーでunwrapなんてしたくない。
      final keysToDelete =
          allEntries.keys.where((k) => k.startsWith(_memoryKeyPrefix)).toList();

      for (final memoryKey in keysToDelete) {
        await context.toolStorageApi.delete(memoryKey);
      }

      return jsonEncode({
        'success': true,
        'message': 'All memories deleted successfully',
        'deletedCount': keysToDelete.length,
      });
    }

    final storageKey = '$_memoryKeyPrefix$key';
    final existed = await context.toolStorageApi.delete(storageKey);
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
