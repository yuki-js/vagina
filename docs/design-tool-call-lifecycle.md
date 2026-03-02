# Tool Call Lifecycle State Model & UX Architecture Design

**Project**: VAGINA - Voice AGI Notepad Agent  
**Date**: 2026-03-02  
**Author**: System Architecture Team

## Executive Summary

This document defines a comprehensive architecture for improving tool call notification UX in the Flutter chat application. The current implementation only displays tool calls after complete execution, making the UI appear frozen during tool execution. This design introduces a state-based lifecycle model that provides real-time visibility into tool call progress.

## Table of Contents

1. [Current Architecture Analysis](#1-current-architecture-analysis)
2. [Updated Data Models](#2-updated-data-models)
3. [State Transition Diagram](#3-state-transition-diagram)
4. [Event-to-Action Mapping](#4-event-to-action-mapping)
5. [Cancel Protection Strategy](#5-cancel-protection-strategy)
6. [Reactive Sheet Design](#6-reactive-sheet-design)
7. [File Change Summary](#7-file-change-summary)
8. [Edge Cases & Race Conditions](#8-edge-cases--race-conditions)
9. [Implementation Considerations](#9-implementation-considerations)

---

## 1. Current Architecture Analysis

### 1.1 Current Data Flow

```
API Event Flow (Current):
┌─────────────────────────────────────────────────────────────┐
│ 1. response.output_item.added (type: function_call)         │
│    → handleResponseOutputItemAdded()                         │
│    → Tracks internally in _state.pendingFunctionCalls       │
│    → NO UI UPDATE                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. response.function_call_arguments.delta (multiple)        │
│    → handleFunctionCallArgumentsDelta()                      │
│    → Accumulates in StringBuffer                            │
│    → NO UI UPDATE                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. response.function_call_arguments.done                    │
│    → handleFunctionCallArgumentsDone()                       │
│    → Emits FunctionCall via stream                          │
│    → NO UI UPDATE YET                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. CallService receives FunctionCall                        │
│    → Executes tool via ToolSandboxManager                   │
│    → Gets result                                             │
│    → NO UI UPDATE DURING EXECUTION                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. ChatMessageManager.addToolCall(name, args, result)       │
│    → Creates ToolCallPart with complete data                │
│    → Adds to message contentParts                           │
│    → FIRST UI UPDATE (tool badge appears with result)       │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Problems Identified

1. **Delayed Visibility**: Tool calls invisible until fully complete
2. **No Progress Indication**: User doesn't know tool is being invoked
3. **Frozen UI Perception**: No feedback during argument streaming or execution
4. **No State Tracking**: Can't distinguish between generating/executing/complete
5. **No Cancel Handling**: No mechanism to handle interrupted tool calls
6. **Static Sheet**: Tool detail sheet shows static snapshot, not live updates

### 1.3 Key Files in Current Architecture

- **Data Models**: [`lib/models/chat_message.dart`](../lib/models/chat_message.dart)
  - `ChatMessage`, `ContentPart`, `ToolCallPart`, `ToolCallInfo`
- **UI Components**: 
  - [`lib/core/widgets/chat_bubble.dart`](../lib/core/widgets/chat_bubble.dart) - Chat bubble with `_ToolBadge`
  - [`lib/core/widgets/tool_details_sheet.dart`](../lib/core/widgets/tool_details_sheet.dart) - Tool details modal
- **State Management**: [`lib/services/chat/chat_message_manager.dart`](../lib/services/chat/chat_message_manager.dart)
- **Event Handling**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)
- **Orchestration**: [`lib/services/call_service.dart`](../lib/services/call_service.dart)
- **Streams**: [`lib/services/realtime/realtime_streams.dart`](../lib/services/realtime/realtime_streams.dart)
- **Types**: [`lib/services/realtime/realtime_types.dart`](../lib/services/realtime/realtime_types.dart)

---

## 2. Updated Data Models

### 2.1 ToolCallStatus Enum

```dart
/// Represents the lifecycle state of a tool call
enum ToolCallStatus {
  /// Arguments are being streamed from the API
  /// - Entered on: response.output_item.added (type: function_call)
  /// - Badge: Shows spinner, no result yet
  generating,
  
  /// Arguments complete, tool function is executing locally
  /// - Entered on: response.function_call_arguments.done + execution start
  /// - Badge: Shows spinner (same visual as generating)
  executing,
  
  /// Tool execution completed successfully
  /// - Entered on: tool execution completion
  /// - Badge: No spinner, shows result available
  completed,
  
  /// Tool execution failed with an error
  /// - Entered on: tool execution throws exception
  /// - Badge: Red tint, error indicator
  error,
  
  /// Session was interrupted before completion
  /// - Entered on: response.cancelled or session disconnect during tool call
  /// - Badge: Grey/muted colors
  /// - IMMUTABLE: Once set, cannot transition to other states
  cancelled,
}
```

### 2.2 Updated ToolCallInfo

```dart
/// Information about a tool call with lifecycle tracking
class ToolCallInfo {
  /// Unique identifier from the API (call_id)
  final String callId;
  
  /// Tool name
  final String name;
  
  /// Current lifecycle status
  final ToolCallStatus status;
  
  /// JSON arguments (accumulates during 'generating', complete after)
  final String arguments;
  
  /// Execution result (empty until 'completed' or 'error')
  final String result;
  
  /// Error message if status is 'error'
  final String? errorMessage;
  
  /// Timestamp when the tool call was created
  final DateTime timestamp;

  ToolCallInfo({
    required this.callId,
    required this.name,
    required this.status,
    this.arguments = '',
    this.result = '',
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
      arguments: '',
      result: '',
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

  /// Check if this tool call can be updated (not cancelled)
  bool get canUpdate => status != ToolCallStatus.cancelled;
  
  /// Check if arguments are complete
  bool get hasCompleteArguments => 
    status == ToolCallStatus.executing || 
    status == ToolCallStatus.completed || 
    status == ToolCallStatus.error;
  
  /// Check if result is available
  bool get hasResult => 
    status == ToolCallStatus.completed || 
    status == ToolCallStatus.error;
}
```

### 2.3 ContentPart (No Changes Required)

The existing `ContentPart` sealed class and `ToolCallPart` remain structurally the same, but `ToolCallPart` now contains an updated `ToolCallInfo` with status tracking.

```dart
/// Tool call content part (existing, uses new ToolCallInfo)
class ToolCallPart extends ContentPart {
  final ToolCallInfo toolCall;

  ToolCallPart(this.toolCall);

  @override
  ToolCallPart copy() => ToolCallPart(toolCall);
}
```

---

## 3. State Transition Diagram

### 3.1 Normal Flow State Transitions

```mermaid
stateDiagram-id1
    [*] --> generating: output_item.added<br/>type=function_call
    
    generating --> executing: function_call_arguments.done<br/>+ execution starts
    
    generating --> cancelled: response.cancel OR<br/>session interrupt
    
    executing --> completed: tool execution success
    
    executing --> error: tool execution throws<br/>exception
    
    executing --> cancelled: response.cancel OR<br/>session interrupt
    
    completed --> [*]
    
    error --> [*]
    
    cancelled --> [*]
    
    note right of cancelled
        IMMUTABLE STATE
        Cannot transition out
    end note
```

### 3.2 Detailed State Flow with Events

```
╔══════════════════════════════════════════════════════════════╗
║  GENERATING STATE                                            ║
║  ────────────────────────────────────────────────────────    ║
║  Entry: response.output_item.added (type: function_call)    ║
║                                                              ║
║  During:                                                     ║
║    • response.function_call_arguments.delta (multiple)       ║
║      → Accumulate arguments, update ToolCallInfo             ║
║      → Badge shows: 🔧 tool_name + spinner                   ║
║                                                              ║
║  Exit: response.function_call_arguments.done                 ║
║    → Transition to EXECUTING                                 ║
╚══════════════════════════════════════════════════════════════╝
                            ↓
╔══════════════════════════════════════════════════════════════╗
║  EXECUTING STATE                                             ║
║  ────────────────────────────────────────────────────────    ║
║  Entry: arguments complete + tool execution starts           ║
║                                                              ║
║  During:                                                     ║
║    • ToolSandboxManager.execute() running                    ║
║      → Badge shows: 🔧 tool_name + spinner (same as above)   ║
║                                                              ║
║  Exit: Tool execution completes                              ║
║    → Success: Transition to COMPLETED                        ║
║    → Error: Transition to ERROR                              ║
╚══════════════════════════════════════════════════════════════╝
                     ↓              ↓
          ┌──────────┴────┬─────────┴────────┐
          ↓               ↓                  ↓
   ╔════════════╗  ╔═══════════╗    ╔═══════════════╗
   ║ COMPLETED  ║  ║   ERROR   ║    ║   CANCELLED   ║
   ║ ──────────  ║  ║ ───────── ║    ║ ───────────── ║
   ║ Success    ║  ║ Exception ║    ║ Interrupt     ║
   ║ No spinner ║  ║ Red tint  ║    ║ Grey/muted    ║
   ║ Has result ║  ║ Has error ║    ║ Partial data  ║
   ╚════════════╝  ╚═══════════╝    ╚═══════════════╝
```

---

## 4. Event-to-Action Mapping

### 4.1 API Event: `response.output_item.added` (type: function_call)

**Current Behavior:**
- Logs function call started
- Stores in `_state.pendingFunctionCalls` and `_state.pendingFunctionNames`
- No UI update

**New Behavior:**

**File**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)

```dart
void handleResponseOutputItemAdded(
    Map<String, dynamic> message, String eventId) {
  final itemJson = message['item'] as Map<String, dynamic>?;
  
  if (itemJson != null) {
    final item = ConversationItem.fromJson(itemJson);

    // Check if this is a function call
    if (item.type == 'function_call') {
      final callId = item.callId ?? '';
      final name = item.name ?? '';
      
      // Initialize accumulator (existing logic)
      _state.pendingFunctionCalls[callId] = StringBuffer();
      _state.pendingFunctionNames[callId] = name;
      
      // NEW: Emit early tool call creation event
      _streams.emitToolCallStarted(ToolCallStarted(
        callId: callId,
        name: name,
      ));
      
      _log.info(_tag, 'Function call started: $name (call_id: $callId)');
    }
  }
}
```

**New Stream in RealtimeStreams:**

```dart
// In RealtimeStreams class
final _toolCallStartedController = StreamController<ToolCallStarted>.broadcast();

Stream<ToolCallStarted> get toolCallStartedStream => 
    _toolCallStartedController.stream;

void emitToolCallStarted(ToolCallStarted event) => 
    _toolCallStartedController.add(event);
```

**New Type in realtime_types.dart:**

```dart
class ToolCallStarted {
  final String callId;
  final String name;

  const ToolCallStarted({
    required this.callId,
    required this.name,
  });
}
```

**ChatMessageManager Action:**

```dart
// New method in ChatMessageManager
void startToolCall(String callId, String toolName) {
  final toolCallInfo = ToolCallInfo.generating(
    callId: callId,
    name: toolName,
  );
  final toolPart = ToolCallPart(toolCallInfo);

  // End current text part
  _currentTextPart = null;
  _currentContentParts.add(toolPart);

  // Update or create assistant message
  if (_currentAssistantMessageId != null) {
    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
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
```

**CallService Subscription:**

```dart
// In _setupApiSubscriptions()
_toolCallStartedSubscription = _apiClient.toolCallStartedStream.listen((event) {
  _chatManager.startToolCall(event.callId, event.name);
  _logService.debug(_tag, 'Tool call badge created: ${event.name}');
});
```

---

### 4.2 API Event: `response.function_call_arguments.delta`

**Current Behavior:**
- Accumulates arguments in StringBuffer
- No UI update

**New Behavior:**

**File**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)

```dart
void handleFunctionCallArgumentsDelta(
    Map<String, dynamic> message, String eventId) {
  final callId = message['call_id'] as String?;
  final delta = message['delta'] as String?;

  if (callId != null && delta != null) {
    // Accumulate arguments (existing)
    _state.pendingFunctionCalls[callId]?.write(delta);
    
    // NEW: Emit delta event for UI updates
    _streams.emitToolCallArgumentsDelta(ToolCallArgumentsDelta(
      callId: callId,
      delta: delta,
      accumulatedArgs: _state.pendingFunctionCalls[callId]?.toString() ?? '',
    ));
    
    _log.debug(_tag, 'Function call arguments delta: $delta');
  }
}
```

**ChatMessageManager Action:**

```dart
// New method in ChatMessageManager
void updateToolCallArguments(String callId, String accumulatedArgs) {
  if (_currentAssistantMessageId == null) return;

  // Find the tool call in current content parts
  final toolPartIndex = _currentContentParts.indexWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId
  );

  if (toolPartIndex >= 0) {
    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;
    
    // Only update if not cancelled
    if (!toolPart.toolCall.canUpdate) return;
    
    // Update with accumulated arguments
    final updatedToolCall = toolPart.toolCall.copyWith(
      arguments: accumulatedArgs,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    // Update message
    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }
}
```

---

### 4.3 API Event: `response.function_call_arguments.done`

**Current Behavior:**
- Emits `FunctionCall` via stream
- CallService receives and executes tool
- UI update only after execution completes

**New Behavior:**

**File**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)

```dart
void handleFunctionCallArgumentsDone(
    Map<String, dynamic> message, String eventId) {
  final callId = message['call_id'] as String?;

  if (callId != null && _state.pendingFunctionCalls.containsKey(callId)) {
    final arguments = _state.pendingFunctionCalls[callId]!.toString();
    final name = _state.pendingFunctionNames[callId] ?? 'unknown';

    _log.info(_tag, 'Function call complete: $name with args: $arguments');

    // Emit function call (existing)
    _streams.emitFunctionCall(FunctionCall(
      callId: callId,
      name: name,
      arguments: arguments,
    ));

    // Cleanup (existing)
    _state.pendingFunctionCalls.remove(callId);
    _state.pendingFunctionNames.remove(callId);
  }
}
```

**ChatMessageManager Action:**

```dart
// New method in ChatMessageManager
void transitionToolCallToExecuting(String callId) {
  if (_currentAssistantMessageId == null) return;

  final toolPartIndex = _currentContentParts.indexWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId
  );

  if (toolPartIndex >= 0) {
    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;
    
    // Only update if not cancelled
    if (!toolPart.toolCall.canUpdate) return;
    
    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.executing,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }
}
```

**CallService Updated Subscription:**

```dart
_functionCallSubscription = _apiClient.functionCallStream.listen((functionCall) async {
  _logService.info(_tag, 'Handling function call: ${functionCall.name}');

  // NEW: Transition to executing state
  _chatManager.transitionToolCallToExecuting(functionCall.callId);

  final sandbox = _sandboxManager;
  if (sandbox == null) {
    _logService.error(_tag, 'Tool sandbox not available');
    // NEW: Mark as error
    _chatManager.completeToolCall(
      callId: functionCall.callId,
      arguments: functionCall.arguments,
      result: '',
      status: ToolCallStatus.error,
      errorMessage: 'Tool sandbox not available',
    );
    return;
  }

  final argsMap = _parseFunctionCallArguments(functionCall.arguments);
  if (argsMap == null) {
    final output = jsonEncode({'error': 'Invalid or empty JSON arguments'});
    // NEW: Mark as error
    _chatManager.completeToolCall(
      callId: functionCall.callId,
      arguments: functionCall.arguments,
      result: output,
      status: ToolCallStatus.error,
      errorMessage: 'Invalid arguments',
    );
    _apiClient.sendFunctionCallResult(functionCall.callId, output);
    return;
  }

  try {
    // Execute tool
    final output = await sandbox.execute(
      functionCall.name,
      argsMap,
    );

    // NEW: Mark as completed
    _chatManager.completeToolCall(
      callId: functionCall.callId,
      arguments: functionCall.arguments,
      result: output,
      status: ToolCallStatus.completed,
    );
    
    _apiClient.sendFunctionCallResult(functionCall.callId, output);
  } catch (e) {
    // NEW: Handle execution error
    _logService.error(_tag, 'Tool execution failed: $e');
    final errorOutput = jsonEncode({'error': e.toString()});
    
    _chatManager.completeToolCall(
      callId: functionCall.callId,
      arguments: functionCall.arguments,
      result: errorOutput,
      status: ToolCallStatus.error,
      errorMessage: e.toString(),
    );
    
    _apiClient.sendFunctionCallResult(functionCall.callId, errorOutput);
  }
});
```

**ChatMessageManager New Method:**

```dart
// Replaces the old addToolCall method
void completeToolCall({
  required String callId,
  required String arguments,
  required String result,
  required ToolCallStatus status,
  String? errorMessage,
}) {
  if (_currentAssistantMessageId == null) return;

  final toolPartIndex = _currentContentParts.indexWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId
  );

  if (toolPartIndex >= 0) {
    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;
    
    // Only update if not cancelled
    if (!toolPart.toolCall.canUpdate) {
      _log.debug('ChatMessageManager', 
        'Skipping update for cancelled tool call: $callId');
      return;
    }
    
    final updatedToolCall = toolPart.toolCall.copyWith(
      status: status,
      arguments: arguments,
      result: result,
      errorMessage: errorMessage,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }
}
```

---

### 4.4 Session Interrupt / Cancel Events

**New Handling Required:**

When `response.cancel` is received or the session disconnects, all pending tool calls must be marked as cancelled.

**File**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)

```dart
// New handler for response interruption
void handleResponseCancelled(Map<String, dynamic> message, String eventId) {
  _log.info(_tag, 'Response cancelled - marking pending tool calls as cancelled');
  
  // Cancel all pending function calls
  for (final callId in _state.pendingFunctionCalls.keys) {
    _streams.emitToolCallCancelled(callId);
  }
  
  _state.pendingFunctionCalls.clear();
  _state.pendingFunctionNames.clear();
}
```

**ChatMessageManager:**

```dart
// New method to cancel tool calls
void cancelToolCall(String callId) {
  if (_currentAssistantMessageId == null) return;

  final toolPartIndex = _currentContentParts.indexWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId
  );

  if (toolPartIndex >= 0) {
    final toolPart = _currentContentParts[toolPartIndex] as ToolCallPart;
    
    // Transition to cancelled (immutable state)
    final updatedToolCall = toolPart.toolCall.copyWith(
      status: ToolCallStatus.cancelled,
    );
    _currentContentParts[toolPartIndex] = ToolCallPart(updatedToolCall);

    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }
}

// New method to cancel all pending tool calls
void cancelAllPendingToolCalls() {
  if (_currentAssistantMessageId == null) return;

  bool hasChanges = false;
  for (int i = 0; i < _currentContentParts.length; i++) {
    final part = _currentContentParts[i];
    if (part is ToolCallPart) {
      final toolCall = part.toolCall;
      // Cancel if not in terminal state
      if (toolCall.status == ToolCallStatus.generating || 
          toolCall.status == ToolCallStatus.executing) {
        _currentContentParts[i] = ToolCallPart(
          toolCall.copyWith(status: ToolCallStatus.cancelled)
        );
        hasChanges = true;
      }
    }
  }

  if (hasChanges) {
    final index = _chatMessages.indexWhere((m) => m.id == _currentAssistantMessageId);
    if (index >= 0) {
      _chatMessages[index] = _chatMessages[index].copyWith(
        contentParts: _copyContentParts(),
      );
      _chatController.add(List.unmodifiable(_chatMessages));
    }
  }
}
```

---

## 5. Cancel Protection Strategy

### 5.1 Cancellation Triggers

1. **User Interruption**: User starts speaking (VAD triggers `speech_started`)
2. **Explicit Cancel**: `response.cancel` event from API
3. **Session Disconnect**: WebSocket connection lost
4. **Error**: API error during function call

### 5.2 Cancel Protection Rules

**Rule 1: Immutable Cancelled State**
- Once `status = ToolCallStatus.cancelled`, it CANNOT be changed
- All subsequent updates (arguments.done, tool result) are discarded
- Implemented via `ToolCallInfo.canUpdate` check

**Rule 2: Prevent Tool Execution**
- If tool call is cancelled before execution starts, execution must be skipped
- If tool call is cancelled during execution, result must be discarded

**Rule 3: Cancel Propagation**
- Response interrupts must propagate to all pending tool calls
- Use `callId` tracking to match cancel events to specific tool calls

### 5.3 Implementation Strategy

**Step 1: Track Active Tool Executions**

```dart
// In CallService
final _activeToolExecutions = <String, Completer<String>>{};

// Modified function call handler
_functionCallSubscription = _apiClient.functionCallStream.listen((functionCall) async {
  // Check if already cancelled
  if (_chatManager.isToolCallCancelled(functionCall.callId)) {
    _logService.debug(_tag, 'Skipping execution for cancelled tool: ${functionCall.callId}');
    return;
  }

  // Create execution tracker
  final completer = Completer<String>();
  _activeToolExecutions[functionCall.callId] = completer;

  try {
    // Transition to executing
    _chatManager.transitionToolCallToExecuting(functionCall.callId);

    // Execute
    final result = await sandbox.execute(functionCall.name, argsMap);
    
    // Check again if cancelled during execution
    if (_chatManager.isToolCallCancelled(functionCall.callId)) {
      _logService.debug(_tag, 'Discarding result for cancelled tool: ${functionCall.callId}');
      return;
    }

    // Complete
    _chatManager.completeToolCall(
      callId: functionCall.callId,
      arguments: functionCall.arguments,
      result: result,
      status: ToolCallStatus.completed,
    );
    
    completer.complete(result);
  } catch (e) {
    // Handle error...
  } finally {
    _activeToolExecutions.remove(functionCall.callId);
  }
});
```

**Step 2: Cancel Handler**

```dart
// In CallService
_toolCallCancelledSubscription = _apiClient.toolCallCancelledStream.listen((callId) {
  _logService.info(_tag, 'Tool call cancelled: $callId');
  
  // Mark as cancelled in chat
  _chatManager.cancelToolCall(callId);
  
  // Cancel active execution (if any)
  final completer = _activeToolExecutions[callId];
  if (completer != null && !completer.isCompleted) {
    completer.completeError('Cancelled by user');
    _activeToolExecutions.remove(callId);
  }
});

// On response interruption (speech_started)
_responseStartedSubscription = _apiClient.responseStartedStream.listen((_) async {
  _logService.info(_tag, 'User speech detected, cancelling pending tool calls');
  
  // Cancel all pending tool calls
  _chatManager.cancelAllPendingToolCalls();
  
  // Stop audio
  await _audioService.stop();
  _chatManager.completeCurrentAssistantMessage();
});
```

**Step 3: ChatMessageManager Helper**

```dart
// New method in ChatMessageManager
bool isToolCallCancelled(String callId) {
  if (_currentAssistantMessageId == null) return false;

  final toolPart = _currentContentParts.firstWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId,
    orElse: () => null,
  );

  if (toolPart is ToolCallPart) {
    return toolPart.toolCall.status == ToolCallStatus.cancelled;
  }
  
  return false;
}
```

---

## 6. Reactive Sheet Design

### 6.1 Problem

Current `ToolDetailsSheet` is a stateless widget that receives a snapshot of `ToolCallInfo`. When the sheet is open, it doesn't update as the tool call progresses.

### 6.2 Solution: StreamBuilder-based Reactive Sheet

**File**: [`lib/core/widgets/tool_details_sheet.dart`](../lib/core/widgets/tool_details_sheet.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/models/chat_message.dart';

/// Shows tool details in a bottom sheet (reactive version)
void showToolDetailsSheet(
  BuildContext context, 
  String callId,  // Changed: now takes callId instead of ToolCallInfo
  WidgetRef ref,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ReactiveToolDetailsSheet(
      callId: callId,
      ref: ref,
    ),
  );
}

/// Reactive tool details sheet that updates in real-time
class ReactiveToolDetailsSheet extends StatelessWidget {
  final String callId;
  final WidgetRef ref;

  const ReactiveToolDetailsSheet({
    super.key, 
    required this.callId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // Watch the chat stream to get real-time updates
    final chatMessages = ref.watch(chatMessagesProvider);
    
    // Find the tool call by callId
    final toolCall = _findToolCallByCallId(chatMessages, callId);

    if (toolCall == null) {
      return _buildErrorState('Tool call not found');
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          _buildHeader(toolCall),
          const SizedBox(height: 16),

          // Status section
          _buildStatusSection(toolCall),
          const SizedBox(height: 12),

          // Arguments section
          _buildArgumentsSection(toolCall),
          const SizedBox(height: 12),

          // Result section (conditionally shown)
          if (toolCall.hasResult) ...[
            _buildResultSection(toolCall),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  ToolCallInfo? _findToolCallByCallId(List<ChatMessage> messages, String callId) {
    for (final message in messages.reversed) {
      for (final part in message.contentParts) {
        if (part is ToolCallPart && part.toolCall.callId == callId) {
          return part.toolCall;
        }
      }
    }
    return null;
  }

  Widget _buildHeader(ToolCallInfo toolCall) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(toolCall.status).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(toolCall.status),
            color: _getStatusColor(toolCall.status),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            toolCall.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        // Spinner for generating/executing states
        if (toolCall.status == ToolCallStatus.generating ||
            toolCall.status == ToolCallStatus.executing)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.secondaryColor,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection(ToolCallInfo toolCall) {
    final statusText = _getStatusText(toolCall.status);
    final statusColor = _getStatusColor(toolCall.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(toolCall.status),
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArgumentsSection(ToolCallInfo toolCall) {
    final hasArgs = toolCall.arguments.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '引数:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundStart,
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasArgs
              ? SelectableText(
                  toolCall.arguments,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: AppTheme.textPrimary,
                  ),
                )
              : Text(
                  toolCall.status == ToolCallStatus.generating
                      ? 'Streaming...'
                      : 'No arguments',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResultSection(ToolCallInfo toolCall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          toolCall.status == ToolCallStatus.error ? 'エラー:' : '結果:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: toolCall.status == ToolCallStatus.error
                ? Colors.red
                : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: toolCall.status == ToolCallStatus.error
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.backgroundStart,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            toolCall.result,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: toolCall.status == ToolCallStatus.error
                  ? Colors.red
                  : AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // Helper methods for status visualization
  Color _getStatusColor(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.generating:
      case ToolCallStatus.executing:
        return AppTheme.secondaryColor;
      case ToolCallStatus.completed:
        return Colors.green;
      case ToolCallStatus.error:
        return Colors.red;
      case ToolCallStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.generating:
        return Icons.download;
      case ToolCallStatus.executing:
        return Icons.play_arrow;
      case ToolCallStatus.completed:
        return Icons.check_circle;
      case ToolCallStatus.error:
        return Icons.error;
      case ToolCallStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusText(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.generating:
        return 'Generating arguments...';
      case ToolCallStatus.executing:
        return 'Executing...';
      case ToolCallStatus.completed:
        return 'Completed';
      case ToolCallStatus.error:
        return 'Error';
      case ToolCallStatus.cancelled:
        return 'Cancelled';
    }
  }
}
```

**Updated Badge Click Handler:**

```dart
// In chat_bubble.dart _ToolBadge
GestureDetector(
  onTap: () => showToolDetailsSheet(
    context, 
    toolCall.callId,  // Pass callId instead of toolCall
    ref,              // Pass WidgetRef for reactive updates
  ),
  child: Container(
    // ... existing badge UI
  ),
)
```

---

## 7. File Change Summary

### 7.1 Data Models

**File**: [`lib/models/chat_message.dart`](../lib/models/chat_message.dart)

**Changes**:
- Add `ToolCallStatus` enum
- Update `ToolCallInfo` class:
  - Add `callId` field
  - Add `status` field
  - Add `errorMessage` field
  - Add `timestamp` field
  - Add factory constructor `ToolCallInfo.generating()`
  - Add `copyWith()` method
  - Add computed properties: `canUpdate`, `hasCompleteArguments`, `hasResult`
- Remove old constructor signature

**Lines affected**: ~40-90 (significant expansion)

---

### 7.2 Realtime Types

**File**: [`lib/services/realtime/realtime_types.dart`](../lib/services/realtime/realtime_types.dart)

**Changes**:
- Add `ToolCallStarted` class
- Add `ToolCallArgumentsDelta` class

**Lines affected**: ~420-440 (additions at end)

---

### 7.3 Realtime Streams

**File**: [`lib/services/realtime/realtime_streams.dart`](../lib/services/realtime/realtime_streams.dart)

**Changes**:
- Add `_toolCallStartedController` StreamController
- Add `_toolCallArgumentsDeltaController` StreamController
- Add `_toolCallCancelledController` StreamController
- Add public stream getters
- Add emit methods
- Update `dispose()` to close new controllers

**Lines affected**: ~45-55, ~85-90, ~130-135 (additions)

---

### 7.4 Response Handlers

**File**: [`lib/services/realtime/response_handlers.dart`](../lib/services/realtime/response_handlers.dart)

**Changes**:
- Update `handleResponseOutputItemAdded()`: Emit `ToolCallStarted` event
- Update `handleFunctionCallArgumentsDelta()`: Emit delta events
- Keep `handleFunctionCallArgumentsDone()`: No changes (existing emit logic)
- Add `handleResponseCancelled()`: New method for cancel events

**Lines affected**: ~85-110, ~260-270, ~380-390 (new method)

---

### 7.5 Chat Message Manager

**File**: [`lib/services/chat/chat_message_manager.dart`](../lib/services/chat/chat_message_manager.dart)

**Changes**:
- Add `startToolCall(callId, name)` method
- Add `updateToolCallArguments(callId, args)` method
- Add `transitionToolCallToExecuting(callId)` method
- Replace `addToolCall()` with `completeToolCall()` method
- Add `cancelToolCall(callId)` method
- Add `cancelAllPendingToolCalls()` method
- Add `isToolCallCancelled(callId)` helper method

**Lines affected**: ~45-82 (replacement), ~180-250 (additions)

---

### 7.6 Call Service

**File**: [`lib/services/call_service.dart`](../lib/services/call_service.dart)

**Changes**:
- Add `_toolCallStartedSubscription` field
- Add `_toolCallCancelledSubscription` field
- Add `_activeToolExecutions` tracking map
- Update `_setupApiSubscriptions()`:
  - Add subscription to `toolCallStartedStream`
  - Update `_functionCallSubscription` with cancel checks and error handling
  - Add subscription to `toolCallCancelledStream`
  - Update `_responseStartedSubscription` to cancel tool calls
- Update `_cleanup()` to cancel subscriptions and active executions

**Lines affected**: ~60-70 (new fields), ~318-400 (subscription updates), cleanup section

---

### 7.7 Chat Bubble

**File**: [`lib/core/widgets/chat_bubble.dart`](../lib/core/widgets/chat_bubble.dart)

**Changes**:
- Update `_ToolBadge`:
  - Add spinner widget for generating/executing states
  - Change icon/color based on status
  - Pass `callId` and `ref` to `showToolDetailsSheet()`
- Make ChatBubble a `ConsumerWidget` to access `ref`

**Lines affected**: ~20-65 (badge visual updates)

---

### 7.8 Tool Details Sheet

**File**: [`lib/core/widgets/tool_details_sheet.dart`](../lib/core/widgets/tool_details_sheet.dart)

**Changes**:
- Change signature: `showToolDetailsSheet(context, callId, ref)`
- Create new `ReactiveToolDetailsSheet` widget
- Implement StreamBuilder-based reactivity
- Add status indicator section
- Add conditional result display
- Add helper methods for status visualization

**Lines affected**: Entire file (~120 lines → ~250 lines)

---

### 7.9 Providers (New or Updated)

**File**: [`lib/feat/call/state/call_stream_providers.dart`](../lib/feat/call/state/call_stream_providers.dart) or similar

**Changes**:
- Ensure `chatMessagesProvider` exposes chat stream properly
- May need to add providers for tool call specific streams if needed

**Lines affected**: TBD based on existing provider structure

---

## 8. Edge Cases & Race Conditions

### 8.1 Out-of-Order Events

**Scenario**: `arguments.done` arrives before `output_item.added`

**Mitigation**:
- In `handleFunctionCallArgumentsDone()`, check if tool call exists
- If not, create it retroactively with `executing` status
- Log warning about out-of-order events

```dart
void handleFunctionCallArgumentsDone(...) {
  // Check if tool call was already created
  if (!_chatManager.hasToolCall(callId)) {
    _log.warn(_tag, 'Received arguments.done before output_item.added, creating retroactively');
    _chatManager.startToolCall(callId, name);
  }
  
  // Continue normal flow...
}
```

---

### 8.2 Multiple Concurrent Tool Calls

**Scenario**: AI calls multiple tools in parallel within one response

**Mitigation**:
- Each tool call has unique `callId` from API
- `callId` is used as key for all lookups
- Multiple `ToolCallPart` objects can coexist in `contentParts`
- No shared state between tool calls

**Guaranteed by design**: `callId` uniqueness ensures isolation

---

### 8.3 Tool Execution Hangs

**Scenario**: Tool execution never completes (infinite loop, network timeout)

**Mitigation**:
- Add execution timeout at CallService level
- Use `Future.timeout()` on `sandbox.execute()`
- Transition to `error` status on timeout

```dart
try {
  final result = await sandbox.execute(functionCall.name, argsMap)
      .timeout(Duration(seconds: 30));
  // ... complete normally
} on TimeoutException {
  _chatManager.completeToolCall(
    callId: functionCall.callId,
    status: ToolCallStatus.error,
    errorMessage: 'Tool execution timeout',
    // ...
  );
}
```

---

### 8.4 Session Disconnect During Tool Execution

**Scenario**: WebSocket disconnects while tool is executing

**Mitigation**:
- In `_cleanup()` method, call `cancelAllPendingToolCalls()`
- Mark all non-terminal tool calls as `cancelled`
- Prevent result updates after cleanup

```dart
Future<void> _cleanup() async {
  if (_isCleanedUp) return;
  _isCleanedUp = true;

  // Cancel all pending tool calls
  _chatManager.cancelAllPendingToolCalls();
  
  // Cancel active executions
  for (final completer in _activeToolExecutions.values) {
    if (!completer.isCompleted) {
      completer.completeError('Session disconnected');
    }
  }
  _activeToolExecutions.clear();
  
  // ... rest of cleanup
}
```

---

### 8.5 Rapid User Interruptions

**Scenario**: User interrupts multiple times in quick succession

**Mitigation**:
- `speech_started` event triggers `cancelAllPendingToolCalls()`
- Subsequent interrupts are no-ops if no tool calls are pending
- Idempotent cancel logic: checking `canUpdate` prevents double-cancel

---

### 8.6 Tool Call Sheet Open During Status Change

**Scenario**: User has tool detail sheet open when status transitions

**Mitigation**:
- StreamBuilder/Provider watch automatically triggers rebuild
- Sheet UI updates reactively without user action
- Smooth transition from "Generating..." → "Executing..." → "Completed"

**Ensured by**: Reactive architecture using StreamBuilder on `chatMessagesProvider`

---

### 8.7 Stale Arguments After Cancel

**Scenario**: `arguments.done` arrives after tool call was cancelled

**Mitigation**:
- Check `isToolCallCancelled()` before executing tool
- Early return if already cancelled
- Log and discard stale events

```dart
if (_chatManager.isToolCallCancelled(functionCall.callId)) {
  _logService.debug(_tag, 'Ignoring arguments.done for cancelled tool: ${functionCall.callId}');
  return;
}
```

---

### 8.8 Tool Not Found in Sandbox

**Scenario**: AI requests a tool that doesn't exist or is disabled

**Mitigation**:
- `sandbox.execute()` throws exception
- Caught in try-catch, transitioned to `error` status
- Error message shown in result

**Already handled by**: Error handling in updated function call subscription

---

### 8.9 JSON Parse Error in Arguments

**Scenario**: Arguments are not valid JSON

**Mitigation**:
- `_parseFunctionCallArguments()` returns `null` on parse error
- Immediately transition to `error` status
- Don't attempt execution

**Already handled by**: Existing validation logic, now with status update

---

### 8.10 Message Deletion During Tool Execution

**Scenario**: User/system deletes message while tool is executing

**Mitigation**:
- Check if `_currentAssistantMessageId` exists before updating
- Early return if message not found
- Log warning about orphaned tool call

```dart
void completeToolCall(...) {
  if (_currentAssistantMessageId == null) {
    _log.warn('ChatMessageManager', 'No active assistant message for tool completion');
    return;
  }
  // ... continue
}
```

---

## 9. Implementation Considerations

### 9.1 Migration Strategy

**Phase 1: Data Models**
1. Update `ToolCallInfo` in [`chat_message.dart`](../lib/models/chat_message.dart)
2. Add migration logic for any existing tool calls (if persisted)
3. Update unit tests for data models

**Phase 2: Backend Streams**
1. Add new event types to [`realtime_types.dart`](../lib/services/realtime/realtime_types.dart)
2. Add new streams to [`realtime_streams.dart`](../lib/services/realtime/realtime_streams.dart)
3. Update [`response_handlers.dart`](../lib/services/realtime/response_handlers.dart) to emit events

**Phase 3: State Management**
1. Add new methods to [`chat_message_manager.dart`](../lib/services/chat/chat_message_manager.dart)
2. Update [`call_service.dart`](../lib/services/call_service.dart) subscriptions
3. Test state transitions independently

**Phase 4: UI Updates**
1. Update [`chat_bubble.dart`](../lib/core/widgets/chat_bubble.dart) badge visuals
2. Refactor [`tool_details_sheet.dart`](../lib/core/widgets/tool_details_sheet.dart) to reactive
3. Test UI responsiveness

**Phase 5: Cancel Protection**
1. Implement cancel logic in all layers
2. Add cancel event handling
3. Test interrupt scenarios

**Phase 6: Integration Testing**
1. Test full lifecycle: generating → executing → completed
2. Test error paths
3. Test cancel scenarios
4. Test concurrent tool calls
5. Test edge cases

---

### 9.2 Testing Strategy

**Unit Tests**:
- `ToolCallInfo` state transitions
- `ChatMessageManager` method logic
- Cancel protection rules (canUpdate checks)

**Integration Tests**:
- Full event flow simulation
- Mock API events, verify UI updates
- Test cancel propagation

**UI Tests**:
- Badge appearance in each state
- Sheet reactivity when open
- Spinner animations

**Manual Tests**:
- Real API calls with actual tools
- User interruptions
- Network disconnects
- Tool execution errors

---

### 9.3 Performance Considerations

**Concern 1: Frequent UI Updates During Delta Streaming**

- Arguments deltas can arrive rapidly (many per second)
- Each delta triggers `_chatController.add()` → UI rebuild
- **Mitigation**: Consider throttling delta updates (e.g., max 10 updates/sec)
- **Alternative**: Only update on sheet open, not in badge (badge doesn't show args)

**Recommendation**: 
- Don't emit delta updates if sheet is not open
- Add flag to ChatMessageManager to track if detailed updates are needed
- Badge shows status only, no need for argument granularity

**Concern 2: Finding Tool Calls by CallId**

- Linear search through messages and content parts
- Potentially slow with large message history
- **Mitigation**: Maintain a separate `Map<String, ToolCallInfo>` index in ChatMessageManager
- Update index on tool call creation/update

**Optimized Approach**:

```dart
// In ChatMessageManager
final Map<String, String> _toolCallIndex = {}; // callId -> messageId

void startToolCall(String callId, String toolName) {
  // ... existing logic
  _toolCallIndex[callId] = _currentAssistantMessageId!;
}

ToolCallInfo? getToolCallByCallId(String callId) {
  final messageId = _toolCallIndex[callId];
  if (messageId == null) return null;
  
  final message = _chatMessages.firstWhere(
    (m) => m.id == messageId,
    orElse: () => null,
  );
  
  if (message == null) return null;
  
  final toolPart = message.contentParts.firstWhere(
    (part) => part is ToolCallPart && part.toolCall.callId == callId,
    orElse: () => null,
  );
  
  return toolPart is ToolCallPart ? toolPart.toolCall : null;
}
```

---

### 9.4 Accessibility

- Ensure spinner has semantic label: "Tool executing"
- Status changes should announce to screen readers
- Error states need descriptive announcements
- Consider haptic feedback on status changes

---

### 9.5 Localization

Current sheet has Japanese labels ("引数:", "結果:"). Ensure all new status strings are localized:
- "Generating arguments..."
- "Executing..."
- "Completed"
- "Error"
- "Cancelled"

---

### 9.6 Visual Design Refinements

**Badge States**:

| Status | Icon | Color | Spinner | Text Example |
|--------|------|-------|---------|--------------|
| generating | 🔧 | secondary | ✅ | "get_weather..." |
| executing | 🔧 | secondary | ✅ | "get_weather" |
| completed | 🔧 | secondary | ❌ | "get_weather" |
| error | 🔧 | red | ❌ | "get_weather" |
| cancelled | 🔧 | grey | ❌ | "get_weather" |

**Spinner**: Small, 12px, positioned to the right of tool name

---

## 10. Conclusion

This design provides a comprehensive solution for real-time tool call visibility with:

✅ **Early Visibility**: Badges appear immediately on `output_item.added`  
✅ **Status Tracking**: Five-state lifecycle (generating → executing → completed/error/cancelled)  
✅ **Progress Indication**: Spinner shows activity during generating/executing  
✅ **Cancel Protection**: Immutable cancelled state prevents stale updates  
✅ **Reactive Sheet**: Real-time updates when detail sheet is open  
✅ **Error Handling**: Graceful handling of execution failures  
✅ **Race Condition Safety**: Handles out-of-order events and concurrent tool calls  

The architecture maintains clean separation of concerns:
- **Data Layer**: ToolCallInfo with status tracking
- **Event Layer**: Stream-based propagation of lifecycle events
- **State Layer**: ChatMessageManager manages tool call state
- **UI Layer**: Reactive widgets respond to state changes

Implementation can proceed in phases with minimal risk to existing functionality.

---

**End of Design Document**
