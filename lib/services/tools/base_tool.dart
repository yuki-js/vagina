import 'dart:convert';

/// Abstract base class for all tools
/// 
/// Each tool must extend this class and implement:
/// - [name]: Unique identifier for the tool
/// - [description]: Description of what the tool does (used by AI)
/// - [parameters]: JSON Schema for the tool's parameters
/// - [execute]: The actual implementation of the tool
abstract class BaseTool {
  /// Unique name for this tool
  String get name;
  
  /// Description of what this tool does (shown to AI)
  String get description;
  
  /// JSON Schema for the tool's parameters
  Map<String, dynamic> get parameters;
  
  /// Execute the tool with the given arguments
  /// Returns a map that will be JSON-encoded as the result
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments);
  
  /// Reference to the tool manager (set when tool is registered)
  ToolManagerRef? _managerRef;
  
  /// Get access to the tool manager
  /// Allows tools to register/unregister other tools dynamically
  ToolManagerRef? get manager => _managerRef;
  
  /// Called internally when tool is registered to a manager
  void setManagerRef(ToolManagerRef ref) {
    _managerRef = ref;
  }
  
  /// Generate the JSON definition for the Realtime API
  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'name': name,
      'description': description,
      'parameters': parameters,
    };
  }
  
  /// Execute the tool and return a formatted result
  Future<ToolExecutionResult> executeWithResult(String callId, String argumentsJson) async {
    try {
      final arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;
      final result = await execute(arguments);
      return ToolExecutionResult(
        callId: callId,
        output: jsonEncode(result),
        success: true,
      );
    } catch (e) {
      return ToolExecutionResult(
        callId: callId,
        output: jsonEncode({'error': e.toString()}),
        success: false,
      );
    }
  }
}

/// Result of a tool execution
class ToolExecutionResult {
  final String callId;
  final String output;
  final bool success;

  const ToolExecutionResult({
    required this.callId,
    required this.output,
    this.success = true,
  });
}

/// Reference to the tool manager that tools can use
/// This provides a limited interface for tools to interact with the manager
abstract class ToolManagerRef {
  /// Register a new tool
  void registerTool(BaseTool tool);
  
  /// Unregister a tool by name
  void unregisterTool(String name);
  
  /// Check if a tool is registered
  bool hasTool(String name);
  
  /// Get a list of all registered tool names
  List<String> get registeredToolNames;
}
