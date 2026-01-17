import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';

/// メモリ検索ツール
class MemoryRecallTool extends BaseTool {
  final MemoryRepository _memoryRepo;

  MemoryRecallTool({required MemoryRepository memoryRepository})
      : _memoryRepo = memoryRepository;

  @override
  String get name => 'memory_recall';

  @override
  String get description =>
      'Recall information from long-term memory. Use this when you need to remember something the user previously asked you to save.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description':
                'The key of the memory to recall. Use "all" to get all stored memories.',
          },
        },
        'required': ['key'],
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'memory_recall',
        displayName: 'メモリ検索',
        displayDescription: '記憶した情報を検索します',
        description: 'Recall information from long-term memory.',
        iconKey: 'search',
        category: ToolCategory.memory,
      );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    
    if (key == 'all') {
      final allMemories = await _memoryRepo.getAll();
      return {
        'success': true,
        'memories': allMemories,
      };
    }
    
    final value = await _memoryRepo.get(key);
    if (value == null) {
      return {
        'success': false,
        'message': 'Memory not found for key: $key',
      };
    }
    
    return {
      'success': true,
      'key': key,
      'value': value,
    };
  }
}
