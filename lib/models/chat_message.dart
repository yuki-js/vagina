/// Represents a chat message in the conversation
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isComplete;
  
  /// Tool calls associated with this message (for assistant messages)
  /// Tool badges are displayed in order within the message balloon
  final List<ToolCallInfo> toolCalls;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isComplete = true,
    this.toolCalls = const [],
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isComplete,
    List<ToolCallInfo>? toolCalls,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
      toolCalls: toolCalls ?? this.toolCalls,
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
