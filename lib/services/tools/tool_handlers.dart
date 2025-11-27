import '../storage_service.dart';
import 'expression_evaluator.dart';

/// Handler function type for tool execution
typedef ToolHandler = Future<Map<String, dynamic>> Function(Map<String, dynamic> arguments);

/// Built-in tool handlers
class BuiltInToolHandlers {
  final StorageService _storage;
  final ExpressionEvaluator _evaluator = ExpressionEvaluator();

  BuiltInToolHandlers({required StorageService storage}) : _storage = storage;

  /// Handle get_current_time tool
  Future<Map<String, dynamic>> handleGetCurrentTime(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final timezone = arguments['timezone'] as String?;
    
    return {
      'current_time': now.toIso8601String(),
      'formatted': '${now.year}年${now.month}月${now.day}日 ${now.hour}時${now.minute}分${now.second}秒',
      'timezone': timezone ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Handle memory_save tool
  Future<Map<String, dynamic>> handleMemorySave(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    final value = arguments['value'] as String;
    
    await _storage.saveMemory(key, value);
    
    return {
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    };
  }

  /// Handle memory_recall tool
  Future<Map<String, dynamic>> handleMemoryRecall(Map<String, dynamic> arguments) async {
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

  /// Handle memory_delete tool
  Future<Map<String, dynamic>> handleMemoryDelete(Map<String, dynamic> arguments) async {
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

  /// Handle calculator tool
  Future<Map<String, dynamic>> handleCalculator(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'] as String;
    
    try {
      final result = _evaluator.evaluate(expression);
      return {
        'success': true,
        'expression': expression,
        'result': result,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to evaluate expression: $e',
      };
    }
  }
}
