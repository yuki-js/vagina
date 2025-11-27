/// Represents a chat message in the conversation
class ChatMessage {
  final String id;
  final String role; // 'user', 'assistant', or 'tool'
  final String content;
  final DateTime timestamp;
  final bool isComplete;
  
  /// Tool call information (for tool messages)
  final ToolCallInfo? toolCall;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isComplete = true,
    this.toolCall,
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isComplete,
    ToolCallInfo? toolCall,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
      toolCall: toolCall ?? this.toolCall,
    );
  }
}

/// Information about a tool call
class ToolCallInfo {
  final String name;
  final String arguments;
  final String result;

  ToolCallInfo({
    required this.name,
    required this.arguments,
    required this.result,
  });
}
