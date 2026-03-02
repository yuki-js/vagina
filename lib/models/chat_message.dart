/// Represents the lifecycle state of a tool call
enum ToolCallStatus {
  /// Arguments are being streamed from the API
  generating,

  /// Arguments complete, tool function is executing locally
  executing,

  /// Tool execution completed successfully
  completed,

  /// Tool execution failed with an error
  error,

  /// Session was interrupted before completion
  /// Once set, this state is immutable
  cancelled;

  /// Check if this is a terminal state (cannot transition further)
  bool get isTerminal =>
      this == ToolCallStatus.completed ||
      this == ToolCallStatus.error ||
      this == ToolCallStatus.cancelled;
}

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
  ToolCallPart copy() => ToolCallPart(toolCall.copy());
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

/// Information about a tool call with lifecycle tracking
class ToolCallInfo {
  /// Unique identifier from the API (call_id)
  final String callId;

  /// Tool name
  final String name;

  /// Current lifecycle status
  final ToolCallStatus status;

  /// JSON arguments (nullable - not available during generating)
  final String? arguments;

  /// Execution result (nullable - not available until completed)
  final String? result;

  /// Error message if status is 'error'
  final String? errorMessage;

  /// Timestamp when the tool call was created
  final DateTime timestamp;

  ToolCallInfo({
    required this.callId,
    required this.name,
    required this.status,
    this.arguments,
    this.result,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create initial tool call (status: generating)
  factory ToolCallInfo.generating({
    required String callId,
    required String name,
  }) {
    return ToolCallInfo(
      callId: callId,
      name: name,
      status: ToolCallStatus.generating,
      arguments: null,
      result: null,
    );
  }

  /// Create copy with updated fields
  ToolCallInfo copyWith({
    String? callId,
    String? name,
    ToolCallStatus? status,
    String? arguments,
    String? result,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return ToolCallInfo(
      callId: callId ?? this.callId,
      name: name ?? this.name,
      status: status ?? this.status,
      arguments: arguments ?? this.arguments,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Create a deep copy
  ToolCallInfo copy() {
    return ToolCallInfo(
      callId: callId,
      name: name,
      status: status,
      arguments: arguments,
      result: result,
      errorMessage: errorMessage,
      timestamp: timestamp,
    );
  }

  /// Check if this tool call can be updated (not cancelled)
  bool get canUpdate => status != ToolCallStatus.cancelled;

  /// Check if arguments are complete
  bool get hasCompleteArguments =>
      status == ToolCallStatus.executing ||
      status == ToolCallStatus.completed ||
      status == ToolCallStatus.error;

  /// Check if result is available
  bool get hasResult =>
      status == ToolCallStatus.completed || status == ToolCallStatus.error;
}
