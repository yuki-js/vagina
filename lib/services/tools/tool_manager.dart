import 'base_tool.dart';
import '../log_service.dart';

/// Session-scoped tool manager
/// 
/// Created when a call starts, destroyed when the call ends.
/// Manages tool registration/unregistration and provides tool definitions.
class ToolManager implements ToolManagerRef {
  static const _tag = 'ToolManager';
  
  /// Map of tool name to tool instance
  final Map<String, BaseTool> _tools = {};
  
  /// Callback to notify when tools change (for updating session config)
  final void Function()? onToolsChanged;
  
  ToolManager({this.onToolsChanged});

  @override
  void registerTool(BaseTool tool) {
    if (_tools.containsKey(tool.name)) {
      logService.warn(_tag, 'Tool ${tool.name} already registered, replacing');
    }
    tool.setManagerRef(this);
    _tools[tool.name] = tool;
    logService.info(_tag, 'Registered tool: ${tool.name}');
    onToolsChanged?.call();
  }
  
  /// Register multiple tools at once
  void registerTools(List<BaseTool> tools) {
    for (final tool in tools) {
      registerTool(tool);
    }
  }

  @override
  void unregisterTool(String name) {
    if (_tools.containsKey(name)) {
      _tools.remove(name);
      logService.info(_tag, 'Unregistered tool: $name');
      onToolsChanged?.call();
    } else {
      logService.warn(_tag, 'Attempted to unregister unknown tool: $name');
    }
  }

  @override
  bool hasTool(String name) => _tools.containsKey(name);

  @override
  List<String> get registeredToolNames => _tools.keys.toList();
  
  /// Get all tool definitions for the Realtime API session configuration
  List<Map<String, dynamic>> get toolDefinitions {
    return _tools.values.map((t) => t.toJson()).toList();
  }
  
  /// Execute a tool by name
  Future<ToolExecutionResult> executeTool(String callId, String name, String argumentsJson) async {
    final tool = _tools[name];
    if (tool == null) {
      logService.error(_tag, 'Unknown tool: $name');
      return ToolExecutionResult(
        callId: callId,
        output: '{"error": "Unknown tool: $name"}',
        success: false,
      );
    }
    
    logService.info(_tag, 'Executing tool: $name');
    final result = await tool.executeWithResult(callId, argumentsJson);
    if (result.success) {
      logService.info(_tag, 'Tool $name completed successfully');
    } else {
      logService.error(_tag, 'Tool $name failed');
    }
    return result;
  }
  
  /// Get the number of registered tools
  int get toolCount => _tools.length;
  
  /// Dispose the manager and clean up
  void dispose() {
    _tools.clear();
    logService.info(_tag, 'ToolManager disposed');
  }
}
