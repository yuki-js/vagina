import 'dart:async';
import '../../models/chat_message.dart';

/// Service for managing chat message state
class ChatMessageManager {
  final StreamController<List<ChatMessage>> _chatController =
      StreamController<List<ChatMessage>>.broadcast();

  final List<ChatMessage> _chatMessages = [];
  int _messageIdCounter = 0;
  StringBuffer _currentAssistantTranscript = StringBuffer();
  String? _currentAssistantMessageId;
  String? _pendingUserMessageId;

  /// Stream of chat messages
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;
  
  /// Get current chat messages
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  /// Add a chat message
  void addChatMessage(String role, String content) {
    final message = ChatMessage(
      id: 'msg_${_messageIdCounter++}',
      role: role,
      content: content,
      timestamp: DateTime.now(),
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Add a tool call message to chat
  void addToolMessage(String toolName, String arguments, String result) {
    final message = ChatMessage(
      id: 'msg_${_messageIdCounter++}',
      role: 'tool',
      content: 'ツールを使用しました: $toolName',
      timestamp: DateTime.now(),
      toolCall: ToolCallInfo(
        name: toolName,
        arguments: arguments,
        result: result,
      ),
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Create a placeholder for user message (called on speech_started)
  /// This ensures the user message appears BEFORE the AI response
  String? createUserMessagePlaceholder() {
    if (_pendingUserMessageId != null) return null;
    
    _pendingUserMessageId = 'msg_${_messageIdCounter++}';
    final message = ChatMessage(
      id: _pendingUserMessageId!,
      role: 'user',
      content: '...',
      timestamp: DateTime.now(),
      isComplete: false,
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
    return _pendingUserMessageId;
  }
  
  /// Update the user message placeholder with actual transcript
  void updateUserMessagePlaceholder(String transcript) {
    if (_pendingUserMessageId != null) {
      final index = _chatMessages.indexWhere((m) => m.id == _pendingUserMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          content: transcript,
          isComplete: true,
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
      _pendingUserMessageId = null;
    } else {
      addChatMessage('user', transcript);
    }
  }
  
  /// Append to the current assistant transcript (streaming)
  void appendAssistantTranscript(String delta) {
    if (_currentAssistantMessageId == null) {
      _currentAssistantMessageId = 'msg_${_messageIdCounter++}';
      _currentAssistantTranscript = StringBuffer();
      _currentAssistantTranscript.write(delta);
      
      final message = ChatMessage(
        id: _currentAssistantMessageId!,
        role: 'assistant',
        content: _currentAssistantTranscript.toString(),
        timestamp: DateTime.now(),
        isComplete: false,
      );
      _chatMessages.add(message);
    } else {
      _currentAssistantTranscript.write(delta);
      
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          content: _currentAssistantTranscript.toString(),
        );
      }
    }
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Mark the current assistant message as complete
  void completeCurrentAssistantMessage() {
    if (_currentAssistantMessageId != null) {
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(isComplete: true);
        _chatController.add(List.unmodifiable(_chatMessages));
      }
      _currentAssistantMessageId = null;
      _currentAssistantTranscript = StringBuffer();
    }
  }
  
  /// Clear chat history
  void clearChat() {
    _chatMessages.clear();
    _messageIdCounter = 0;
    _currentAssistantTranscript = StringBuffer();
    _currentAssistantMessageId = null;
    _pendingUserMessageId = null;
    _chatController.add(List.unmodifiable(_chatMessages));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _chatController.close();
  }
}
