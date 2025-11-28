import '../base_tool.dart';
import '../../storage_service.dart';

/// Tool for saving information to long-term memory
class MemorySaveTool extends BaseTool {
  final StorageService _storage;
  
  MemorySaveTool({required StorageService storage}) : _storage = storage;
  
  @override
  String get name => 'memory_save';
  
  @override
  String get description => 
      'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'key': {
        'type': 'string',
        'description': 'A unique key to identify this memory (e.g., "user_name", "favorite_color")',
      },
      'value': {
        'type': 'string',
        'description': 'The information to remember',
      },
    },
    'required': ['key', 'value'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    final value = arguments['value'] as String;
    
    await _storage.saveMemory(key, value);
    
    return {
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    };
  }
}
