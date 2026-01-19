import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemorySaveTool implements Tool {
  static const String toolKeyName = 'memory_save';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'メモリ保存',
        displayDescription: '重要な情報を記憶します',
        categoryKey: 'memory',
        iconKey: 'save',
        sourceKey: 'builtin',
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
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final key = args['key'] as String;
    final value = args['value'] as String;

    await context.memoryApi.save(key, value);

    return jsonEncode({
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    });
  }
}
