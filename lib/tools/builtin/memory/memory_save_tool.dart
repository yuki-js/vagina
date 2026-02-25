import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemorySaveTool extends Tool {
  static const String toolKeyName = 'memory_save';

  /// Sub-namespace under the publisher-level storage namespace.
  ///
  /// Storage can be shared across tools from the same publisher, so we scope all
  /// memory entries under a dedicated prefix to avoid collisions.
  static const String _memoryKeyPrefix = 'memory/';

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

    // Storage may be shared across tools from the same publisher.
    // Keep memory entries isolated within that shared namespace.
    final storageKey = '$_memoryKeyPrefix$key';
    await context.toolStorageApi.save(storageKey, value);

    return jsonEncode({
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    });
  }
}
