import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';

/// メモリ削除ツール
class MemoryDeleteTool extends BaseTool {
  final MemoryRepository _memoryRepo;

  MemoryDeleteTool({required MemoryRepository memoryRepository})
      : _memoryRepo = memoryRepository;

  @override
  String get name => 'memory_delete';

  @override
  String get description =>
      'Delete information from long-term memory. Use this when the user asks you to forget something.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description':
                'The key of the memory to delete. Use "all" to delete all memories.',
          },
        },
        'required': ['key'],
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'memory_delete',
        displayName: 'メモリ削除',
        displayDescription: '記憶した情報を削除します',
        description: 'Delete information from long-term memory.',
        iconKey: 'delete',
        category: ToolCategory.memory,
      );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    
    if (key == 'all') {
      await _memoryRepo.deleteAll();
      return {
        'success': true,
        'message': 'All memories deleted successfully',
      };
    }
    
    final existed = await _memoryRepo.delete(key);
    if (!existed) {
      return {
        'success': false,
        'message': 'Memory not found for key: $key',
      };
    }
    
    return {
      'success': true,
      'message': 'Memory deleted successfully',
      'key': key,
    };
  }
}
