import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemoryRecallTool extends Tool {
  static const String toolKeyName = 'memory_recall';

  /// Sub-namespace under the publisher-level storage namespace.
  static const String _memoryKeyPrefix = 'memory/';

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
      final allEntries =
          (await context.toolStorageApi.list())["data"]; // todo: list関数はdataをunwrapするべきだ。このレイヤーでunwrapなんてしたくない。
      final memories = <String, dynamic>{};

      for (final entry in allEntries.entries) {
        final k = entry.key;
        if (k.startsWith(_memoryKeyPrefix)) {
          memories[k.substring(_memoryKeyPrefix.length)] = entry.value;
        }
      }

      return jsonEncode({
        'success': true,
        'memories': memories,
      });
    }

    final storageKey = '$_memoryKeyPrefix$key';
    final value = await context.toolStorageApi.get(storageKey);
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
