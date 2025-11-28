import '../base_tool.dart';
import '../../storage_service.dart';

/// Tool for deleting information from long-term memory
class MemoryDeleteTool extends BaseTool {
  final StorageService _storage;
  
  MemoryDeleteTool({required StorageService storage}) : _storage = storage;
  
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
        'description': 'The key of the memory to delete. Use "all" to delete all memories.',
      },
    },
    'required': ['key'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    
    if (key == 'all') {
      await _storage.deleteAllMemories();
      return {
        'success': true,
        'message': 'All memories deleted successfully',
      };
    }
    
    final existed = await _storage.deleteMemory(key);
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
