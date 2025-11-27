import 'dart:convert';
import '../models/tool_definition.dart';
import 'storage_service.dart';
import 'log_service.dart';

/// Handler function type for tool execution
typedef ToolHandler = Future<Map<String, dynamic>> Function(Map<String, dynamic> arguments);

/// Service for managing and executing tools for the Realtime API
class ToolService {
  static const _tag = 'ToolService';
  
  final StorageService _storage;
  
  /// Map of tool name to handler function
  final Map<String, ToolHandler> _handlers = {};
  
  /// List of tool definitions
  final List<ToolDefinition> _tools = [];

  ToolService({required StorageService storage}) : _storage = storage {
    _registerBuiltInTools();
  }

  /// Get all tool definitions for session configuration
  List<Map<String, dynamic>> get toolDefinitions {
    return _tools.map((t) => t.toJson()).toList();
  }

  /// Register built-in tools
  void _registerBuiltInTools() {
    // Tool 1: Get current time
    _registerTool(
      ToolDefinition(
        name: 'get_current_time',
        description: 'Get the current date and time. Use this when the user asks about the current time or date.',
        parameters: {
          'type': 'object',
          'properties': {
            'timezone': {
              'type': 'string',
              'description': 'Timezone name (e.g., "Asia/Tokyo", "UTC"). Defaults to local time if not specified.',
            },
          },
          'required': [],
        },
      ),
      _handleGetCurrentTime,
    );

    // Tool 2: Memory - Save to long-term storage
    _registerTool(
      ToolDefinition(
        name: 'memory_save',
        description: 'Save information to long-term memory that persists across sessions. Use this when the user asks you to remember something.',
        parameters: {
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
        },
      ),
      _handleMemorySave,
    );

    // Tool 3: Memory - Recall from long-term storage
    _registerTool(
      ToolDefinition(
        name: 'memory_recall',
        description: 'Recall information from long-term memory. Use this when you need to remember something the user previously asked you to save.',
        parameters: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The key of the memory to recall. Use "all" to get all stored memories.',
            },
          },
          'required': ['key'],
        },
      ),
      _handleMemoryRecall,
    );

    // Tool 4: Simple calculator
    _registerTool(
      ToolDefinition(
        name: 'calculator',
        description: 'Perform basic arithmetic calculations. Use this for mathematical operations.',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'Mathematical expression to evaluate (e.g., "2 + 3 * 4", "100 / 5")',
            },
          },
          'required': ['expression'],
        },
      ),
      _handleCalculator,
    );
  }

  /// Register a tool with its handler
  void _registerTool(ToolDefinition definition, ToolHandler handler) {
    _tools.add(definition);
    _handlers[definition.name] = handler;
    logService.info(_tag, 'Registered tool: ${definition.name}');
  }

  /// Execute a tool call
  Future<ToolCallResult> executeTool(String callId, String name, String argumentsJson) async {
    logService.info(_tag, 'Executing tool: $name with arguments: $argumentsJson');
    
    final handler = _handlers[name];
    if (handler == null) {
      logService.error(_tag, 'Unknown tool: $name');
      return ToolCallResult(
        callId: callId,
        output: jsonEncode({'error': 'Unknown tool: $name'}),
        success: false,
      );
    }

    try {
      final arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;
      final result = await handler(arguments);
      logService.info(_tag, 'Tool $name completed successfully');
      return ToolCallResult(
        callId: callId,
        output: jsonEncode(result),
        success: true,
      );
    } catch (e) {
      logService.error(_tag, 'Tool $name failed: $e');
      return ToolCallResult(
        callId: callId,
        output: jsonEncode({'error': e.toString()}),
        success: false,
      );
    }
  }

  // Tool handlers

  Future<Map<String, dynamic>> _handleGetCurrentTime(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final timezone = arguments['timezone'] as String?;
    
    // For simplicity, we just return local time with timezone info
    // A full implementation would handle timezone conversion
    return {
      'current_time': now.toIso8601String(),
      'formatted': '${now.year}年${now.month}月${now.day}日 ${now.hour}時${now.minute}分${now.second}秒',
      'timezone': timezone ?? 'local',
      'unix_timestamp': now.millisecondsSinceEpoch ~/ 1000,
    };
  }

  Future<Map<String, dynamic>> _handleMemorySave(Map<String, dynamic> arguments) async {
    final key = arguments['key'] as String;
    final value = arguments['value'] as String;
    
    await _storage.saveMemory(key, value);
    
    return {
      'success': true,
      'message': 'Memory saved successfully',
      'key': key,
    };
  }

  Future<Map<String, dynamic>> _handleMemoryRecall(Map<String, dynamic> arguments) async {
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

  Future<Map<String, dynamic>> _handleCalculator(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'] as String;
    
    try {
      // Simple expression parser for basic arithmetic
      final result = _evaluateExpression(expression);
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

  /// Simple arithmetic expression evaluator
  double _evaluateExpression(String expression) {
    // Remove whitespace
    expression = expression.replaceAll(' ', '');
    
    // Parse and evaluate (simple implementation for basic operations)
    return _parseAddSub(expression, 0).$1;
  }

  (double, int) _parseAddSub(String expr, int pos) {
    var (left, newPos) = _parseMulDiv(expr, pos);
    
    while (newPos < expr.length) {
      final op = expr[newPos];
      if (op != '+' && op != '-') break;
      
      final (right, nextPos) = _parseMulDiv(expr, newPos + 1);
      left = op == '+' ? left + right : left - right;
      newPos = nextPos;
    }
    
    return (left, newPos);
  }

  (double, int) _parseMulDiv(String expr, int pos) {
    var (left, newPos) = _parseNumber(expr, pos);
    
    while (newPos < expr.length) {
      final op = expr[newPos];
      if (op != '*' && op != '/') break;
      
      final (right, nextPos) = _parseNumber(expr, newPos + 1);
      left = op == '*' ? left * right : left / right;
      newPos = nextPos;
    }
    
    return (left, newPos);
  }

  (double, int) _parseNumber(String expr, int pos) {
    // Handle parentheses
    if (pos < expr.length && expr[pos] == '(') {
      final (value, endPos) = _parseAddSub(expr, pos + 1);
      // Skip closing parenthesis
      return (value, endPos + 1);
    }
    
    // Handle negative numbers
    var negative = false;
    if (pos < expr.length && expr[pos] == '-') {
      negative = true;
      pos++;
    }
    
    // Parse number
    var end = pos;
    while (end < expr.length && '0123456789.'.contains(expr[end])) {
      end++;
    }
    
    var value = double.parse(expr.substring(pos, end));
    if (negative) value = -value;
    
    return (value, end);
  }
}
