/// Definition of a tool that can be called by the AI
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'name': name,
      'description': description,
      'parameters': parameters,
    };
  }
}

/// Result of a tool call
class ToolCallResult {
  final String callId;
  final String output;
  final bool success;

  const ToolCallResult({
    required this.callId,
    required this.output,
    this.success = true,
  });
}
