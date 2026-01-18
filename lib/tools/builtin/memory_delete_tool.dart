import 'dart:convert';

import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class MemoryDeleteTool implements Tool {
  static const String toolKeyName = 'memory_delete';

  final MemoryRepository _memoryRepo;
  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  MemoryDeleteTool({required MemoryRepository memoryRepository})
      : _memoryRepo = memoryRepository;

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
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final key = args['key'] as String;

    if (key == 'all') {
      await _memoryRepo.deleteAll();
      return jsonEncode({
        'success': true,
        'message': 'All memories deleted successfully',
      });
    }

    final existed = await _memoryRepo.delete(key);
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
