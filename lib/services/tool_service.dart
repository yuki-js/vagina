import 'dart:convert';
import '../models/tool_definition.dart';
import 'storage_service.dart';
import 'log_service.dart';
import 'tools/tool_handlers.dart';
import 'tools/tool_definitions.dart';

/// Service for managing and executing tools for the Realtime API
class ToolService {
  static const _tag = 'ToolService';
  
  late final BuiltInToolHandlers _handlers;
  
  /// Map of tool name to handler function
  final Map<String, ToolHandler> _handlerMap = {};
  
  /// List of tool definitions
  final List<ToolDefinition> _tools = [];

  ToolService({required StorageService storage}) {
    _handlers = BuiltInToolHandlers(storage: storage);
    _registerBuiltInTools();
  }

  /// Get all tool definitions for session configuration
  List<Map<String, dynamic>> get toolDefinitions {
    return _tools.map((t) => t.toJson()).toList();
  }

  /// Register built-in tools
  void _registerBuiltInTools() {
    final definitions = ToolDefinitions.getBuiltInTools();
    
    for (final definition in definitions) {
      final handler = _getHandler(definition.name);
      if (handler != null) {
        _registerTool(definition, handler);
      }
    }
  }

  ToolHandler? _getHandler(String name) {
    switch (name) {
      case 'get_current_time':
        return _handlers.handleGetCurrentTime;
      case 'memory_save':
        return _handlers.handleMemorySave;
      case 'memory_recall':
        return _handlers.handleMemoryRecall;
      case 'memory_delete':
        return _handlers.handleMemoryDelete;
      case 'calculator':
        return _handlers.handleCalculator;
      default:
        return null;
    }
  }

  /// Register a tool with its handler
  void _registerTool(ToolDefinition definition, ToolHandler handler) {
    _tools.add(definition);
    _handlerMap[definition.name] = handler;
    logService.info(_tag, 'Registered tool: ${definition.name}');
  }

  /// Execute a tool call
  Future<ToolCallResult> executeTool(String callId, String name, String argumentsJson) async {
    logService.info(_tag, 'Executing tool: $name with arguments: $argumentsJson');
    
    final handler = _handlerMap[name];
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
}
