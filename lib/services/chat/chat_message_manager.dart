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

  /// Start a new tool call in the generating state
  /// Called when response.output_item.added (type: function_call) is received
  void startToolCall(String callId, String name) {
    final toolCallInfo = ToolCallInfo.generating(
      callId: callId,
      name: name,
    );
    final toolPart = ToolCallPart(toolCallInfo);

    // End current text part
    _currentTextPart = null;
    _currentContentParts.add(toolPart);

    // Update or create assistant message
    if (_currentAssistantMessageId != null) {
      final index =
          _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          contentParts: _copyContentParts(),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
    } else {
      // Create new assistant message
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

  /// Update tool call arguments as they stream in
  /// Called on response.function_call_arguments.delta events
  void updateToolCallArguments(String callId, String delta) {
    if (_currentAssistantMessageId == null) return;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;

    // Cancel protection: don't update if cancelled or terminal
    if (toolPart.toolCall.status.isTerminal) return;

    // Append delta to existing arguments
    final currentArgs = toolPart.toolCall.arguments ?? '';
    final updatedToolCall = toolPart.toolCall.copyWith(
      arguments: currentArgs + delta,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    // Update message
    final index =
        _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }

  /// Transition tool call to executing state
  /// Called when response.function_call_arguments.done is received
  void transitionToolCallToExecuting(String callId, String finalArguments) {
    if (_currentAssistantMessageId == null) return;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;

    // Cancel protection: don't update if terminal
    if (toolPart.toolCall.status.isTerminal) return;

    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.executing,
      arguments: finalArguments,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index =
        _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }

  /// Complete a tool call successfully
  /// Called when tool execution completes without error
  void completeToolCall(String callId, String result) {
    if (_currentAssistantMessageId == null) return;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;

    // Cancel protection: don't update if terminal
    if (toolPart.toolCall.status.isTerminal) return;

    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.completed,
      result: result,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index =
        _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }

  /// Fail a tool call with an error
  /// Called when tool execution throws an exception
  void failToolCall(String callId, String errorMessage) {
    if (_currentAssistantMessageId == null) return;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;

    // Cancel protection: don't update if terminal
    if (toolPart.toolCall.status.isTerminal) return;

    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.error,
      errorMessage: errorMessage,
      result: errorMessage,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index =
        _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }

  /// Cancel a specific tool call
  /// Called when response is cancelled or interrupted
  void cancelToolCall(String callId) {
    if (_currentAssistantMessageId == null) return;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;

    // Don't update if already terminal
    if (toolPart.toolCall.status.isTerminal) return;

    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.cancelled,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index =
        _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }

  /// Cancel all pending tool calls
  /// Called when session is interrupted or reset
  void cancelAllPendingToolCalls() {
    if (_currentAssistantMessageId == null) return;

    bool hasChanges = false;
    for (int i = 0; i < _currentContentParts.length; i++) {
      final part = _currentContentParts[i];
      if (part is ToolCallPart) {
        final toolCall = part.toolCall;
        // Cancel if not in terminal state
        if (!toolCall.status.isTerminal) {
          _currentContentParts[i] = ToolCallPart(
            toolCall.copyWith(status: ToolCallStatus.cancelled),
          );
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      final index =
          _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
      if (index >= 0) {
        _chatMessages[index] = _chatMessages[index].copyWith(
          contentParts: _copyContentParts(),
        );
        _chatController.add(List.unmodifiable(_chatMessages));
      }
    }
  }

  /// Check if a tool call is cancelled
  /// Returns true if the tool call exists and is in cancelled state
  bool isToolCallCancelled(String callId) {
    if (_currentAssistantMessageId == null) return false;

    final toolPartIndex = _findToolCallPartIndex(callId);
    if (toolPartIndex < 0) return false;

    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;
    return toolPart.toolCall.status == ToolCallStatus.cancelled;
  }

  /// Find the index of a tool call part by callId
  /// Returns -1 if not found
  int _findToolCallPartIndex(String callId) {
    return _currentContentParts.indexWhere(
      (part) => part is ToolCallPart && part.toolCall.callId == callId,
    );
  }

  /// Add a tool call to the current assistant turn (legacy method)
  /// This is deprecated in favor of the new lifecycle methods.
  /// Kept for backward compatibility if needed.
  @deprecated
  void addToolCall(String toolName, String arguments, String result) {
    // For backward compatibility, create a completed tool call directly
    // Generate a pseudo call_id since we don't have one
    final callId = 'legacy_${DateTime.now().millisecondsSinceEpoch}';
    
    final toolCallInfo = ToolCallInfo(
      callId: callId,
      name: toolName,
      status: ToolCallStatus.completed,
      arguments: arguments,
      result: result,
    );
    final toolPart = ToolCallPart(toolCallInfo);

    // End the current text part - next text will be a new part
    _currentTextPart = null;
    _currentContentParts.add(toolPart);

    // If there's a current assistant message, update it
    if (_currentAssistantMessageId != null) {
      final index =
          _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
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
      final index =
          _chatMessages.indexWhere((m) => m.id == _pendingUserMessageId);
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

      final index =
          _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
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
      final index =
          _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
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

  /// Dispose resources
  Future<void> dispose() async {
    await _chatController.close();
  }
}
