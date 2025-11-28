import '../base_tool.dart';
import '../../storage_service.dart';

/// Tool for recalling information from long-term memory
class MemoryRecallTool extends BaseTool {
  final StorageService _storage;
  
  MemoryRecallTool({required StorageService storage}) : _storage = storage;
  
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
        'description': 'The key of the memory to recall. Use "all" to get all stored memories.',
      },
    },
    'required': ['key'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    
    if (key == 'all') {
      final allMemories = await _storage.getAllMemories();
      return {
        'success': true,
        'memories': allMemories,
      };
    }
    
    final value = await _storage.getMemory(key);
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
