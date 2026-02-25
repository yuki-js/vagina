/// Represents a content part in a message (either text or tool call)
sealed class ContentPart {
  /// Creates a deep copy of this content part
  ContentPart copy();
}

/// Text content part
/// Note: `text` is mutable for efficient streaming accumulation.
/// Always use copy() when storing in immutable message lists.
class TextPart extends ContentPart {
  String text;

  TextPart(this.text);

  @override
  TextPart copy() => TextPart(text);
}

/// Tool call content part
class ToolCallPart extends ContentPart {
  final ToolCallInfo toolCall;

  ToolCallPart(this.toolCall);

  @override
  ToolCallPart copy() => ToolCallPart(toolCall);
}

/// Represents a chat message in the conversation
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;
  final bool isComplete;

  /// Content parts in order (text and tool calls interleaved as generated)
  final List<ContentPart> contentParts;

  ChatMessage({
    required this.id,
    required this.role,
    required this.timestamp,
    this.isComplete = true,
    this.contentParts = const [],
  });

  /// Get plain text content (concatenated from all text parts)
  String get content {
    return contentParts.whereType<TextPart>().map((p) => p.text).join();
  }

  /// Get all tool calls in order
  List<ToolCallInfo> get toolCalls {
    return contentParts
        .whereType<ToolCallPart>()
        .map((p) => p.toolCall)
        .toList();
  }

  ChatMessage copyWith({
    String? id,
    String? role,
    DateTime? timestamp,
    bool? isComplete,
    List<ContentPart>? contentParts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
      contentParts: contentParts ?? this.contentParts,
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
