import 'dart:collection';

/// A single text agent's conversation thread (mutable).
/// 
/// Manages the message history for Chat Completions API calls,
/// storing messages as `Map<String, dynamic>` to match the API format.
/// 
/// Messages are accumulated during a call session and automatically
/// cleared when the isolate is disposed (at call end).
class TextAgentThread {
  final List<Map<String, dynamic>> _messages = [];

  /// Read-only view of the messages.
  UnmodifiableListView<Map<String, dynamic>> get messages =>
      UnmodifiableListView(_messages);

  /// Add a user message.
  void addUser(String content) {
    _messages.add({
      'role': 'user',
      'content': content,
    });
  }

  /// Add an assistant message (directly from API response).
  /// 
  /// The [message] map should be the assistant message object from
  /// the Chat Completions API response, which may contain `content`
  /// and/or `tool_calls`.
  void addAssistant(Map<String, dynamic> message) {
    if (message['role'] != 'assistant') {
      throw ArgumentError('Expected assistant message, got: ${message['role']}');
    }
    _messages.add(message);
  }

  /// Add a tool result message.
  void addTool(String toolCallId, String name, String content) {
    _messages.add({
      'role': 'tool',
      'tool_call_id': toolCallId,
      'name': name,
      'content': content,
    });
  }

  /// Remove the oldest [count] messages from the thread.
  /// 
  /// Used for context length error recovery.
  /// If [count] is greater than the current message count, all messages are removed.
  void trimOldest(int count) {
    if (count <= 0 || _messages.isEmpty) return;
    final removeCount = count.clamp(0, _messages.length);
    _messages.removeRange(0, removeCount);
  }

  /// Number of messages in the thread.
  int get length => _messages.length;

  /// Whether the thread is empty.
  bool get isEmpty => _messages.isEmpty;

  /// Clear all messages from the thread.
  void clear() {
    _messages.clear();
  }
}
