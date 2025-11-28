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
  List<ToolCallInfo> _currentToolCalls = [];

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
  
  /// Add a tool call to the current assistant turn
  /// Tool calls are merged into the assistant message and displayed as badges
  void addToolCall(String toolName, String arguments, String result) {
    final toolCallInfo = ToolCallInfo(
      name: toolName,
      arguments: arguments,
      result: result,
    );
    _currentToolCalls.add(toolCallInfo);
    
    // If there's a current assistant message, add the tool call to it
    if (_currentAssistantMessageId != null) {
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          toolCalls: List.from(_currentToolCalls),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
    } else {
      // Create a new assistant message with just the tool call
      _currentAssistantMessageId = 'msg_${_messageIdCounter++}';
      _currentAssistantTranscript = StringBuffer();
      
      final message = ChatMessage(
        id: _currentAssistantMessageId!,
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isComplete: false,
        toolCalls: List.from(_currentToolCalls),
      );
      _chatMessages.add(message);
      _chatController.add(List.unmodifiable(_chatMessages));
    }
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
        toolCalls: List.from(_currentToolCalls),
      );
      _chatMessages.add(message);
    } else {
      _currentAssistantTranscript.write(delta);
      
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          content: _currentAssistantTranscript.toString(),
          toolCalls: List.from(_currentToolCalls),
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
        _chatMessages[index] = _chatMessages[index].copyWith(
          isComplete: true,
          toolCalls: List.from(_currentToolCalls),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
      _currentAssistantMessageId = null;
      _currentAssistantTranscript = StringBuffer();
      _currentToolCalls = [];
    }
  }
  
  /// Clear chat history
  void clearChat() {
    _chatMessages.clear();
    _messageIdCounter = 0;
    _currentAssistantTranscript = StringBuffer();
    _currentAssistantMessageId = null;
    _pendingUserMessageId = null;
    _currentToolCalls = [];
    _chatController.add(List.unmodifiable(_chatMessages));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _chatController.close();
  }
}
