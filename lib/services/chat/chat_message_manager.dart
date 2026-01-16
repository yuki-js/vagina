import 'dart:async';
import 'package:vagina/models/chat_message.dart';

/// Service for managing chat message state
class ChatMessageManager {
  final StreamController<List<ChatMessage>> _chatController =
      StreamController<List<ChatMessage>>.broadcast();

  final List<ChatMessage> _chatMessages = [];
  int _messageIdCounter = 0;
  String? _currentAssistantMessageId;
  String? _pendingUserMessageId;
  
  /// Content parts for the current assistant message (in order)
  List<ContentPart> _currentContentParts = [];
  
  /// Current text part being streamed (last TextPart in _currentContentParts)
  TextPart? _currentTextPart;

  /// Stream of chat messages
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;
  
  /// Get current chat messages
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  
  /// Deep copy content parts to avoid aliasing issues with mutable TextPart
  List<ContentPart> _copyContentParts() {
    return _currentContentParts.map((p) => p.copy()).toList();
  }

  /// Add a chat message
  void addChatMessage(String role, String content) {
    final message = ChatMessage(
      id: 'msg_${_messageIdCounter++}',
      role: role,
      timestamp: DateTime.now(),
      contentParts: [TextPart(content)],
    );
    _chatMessages.add(message);
    _chatController.add(List.unmodifiable(_chatMessages));
  }
  
  /// Add a tool call to the current assistant turn
  /// Tool calls are inserted in order within the content parts
  void addToolCall(String toolName, String arguments, String result) {
    final toolCallInfo = ToolCallInfo(
      name: toolName,
      arguments: arguments,
      result: result,
    );
    final toolPart = ToolCallPart(toolCallInfo);
    
    // End the current text part - next text will be a new part
    _currentTextPart = null;
    _currentContentParts.add(toolPart);
    
    // If there's a current assistant message, update it
    if (_currentAssistantMessageId != null) {
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          contentParts: _copyContentParts(),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
    } else {
      // Create a new assistant message with the tool call
      _currentAssistantMessageId = 'msg_${_messageIdCounter++}';
      
      final message = ChatMessage(
        id: _currentAssistantMessageId!,
        role: 'assistant',
        timestamp: DateTime.now(),
        isComplete: false,
        contentParts: _copyContentParts(),
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
      timestamp: DateTime.now(),
      isComplete: false,
      contentParts: [TextPart('...')],
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
          contentParts: [TextPart(transcript)],
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
      // Create a new assistant message
      _currentAssistantMessageId = 'msg_${_messageIdCounter++}';
      _currentTextPart = TextPart(delta);
      _currentContentParts.add(_currentTextPart!);
      
      final message = ChatMessage(
        id: _currentAssistantMessageId!,
        role: 'assistant',
        timestamp: DateTime.now(),
        isComplete: false,
        contentParts: _copyContentParts(),
      );
      _chatMessages.add(message);
    } else {
      // Append to existing text part or create new one
      if (_currentTextPart != null) {
        _currentTextPart!.text += delta;
      } else {
        // After a tool call, start a new text part
        _currentTextPart = TextPart(delta);
        _currentContentParts.add(_currentTextPart!);
      }
      
      final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          contentParts: _copyContentParts(),
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
          contentParts: _copyContentParts(),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
      _currentAssistantMessageId = null;
      _currentContentParts = [];
      _currentTextPart = null;
    }
  }
  
  /// Clear chat history
  void clearChat() {
    _chatMessages.clear();
    _messageIdCounter = 0;
    _currentAssistantMessageId = null;
    _pendingUserMessageId = null;
    _currentContentParts = [];
    _currentTextPart = null;
    _chatController.add(List.unmodifiable(_chatMessages));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _chatController.close();
  }
}
