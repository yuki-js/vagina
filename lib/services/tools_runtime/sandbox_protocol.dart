/// Protocol definitions for platform-agnostic tool sandboxing.
///
/// This module defines the message protocol used for safe communication
/// between the host process and sandboxed tool workers. All communication
/// uses message passing to prevent direct access to live objects.
///
/// Supports both:
/// - **Native**: True Isolate-based sandboxing (dart:isolate)
/// - **Web**: Pseudo-isolate with single-thread message passing
///
/// # Message Flow
///
/// 1. **Handshake**: Host initiates with [handshakeMessage]
/// 2. **Tool Operations**: Host sends [executeToolMessage], worker responds with result
/// 3. **Dynamic Changes**: Host notifies worker of tool changes via [toolsChangedMessage]
/// 4. **Host Calls**: Worker requests host services via [hostCallMessage]
library sandbox_protocol;

// Conditional import for platform-specific port types
import 'sandbox_protocol_platform_native.dart'
    if (dart.library.html) 'sandbox_protocol_platform_web.dart'
    as platform;

// Re-export platform-specific ReplyToPort type for type safety
typedef ReplyToPort = platform.ReplyToPort;

/// Check if a value is a valid ReplyToPort
///
/// This is a helper for code that needs to validate port types at runtime.
bool isValidReplyToPort(Object? value) => platform.isValidReplyTo(value);

// ============================================================================
// MESSAGE TYPE CONSTANTS
// ============================================================================

/// Message type constants for protocol messages.
///
/// These strings identify the purpose and structure of each message type
/// transmitted between host and worker.
abstract final class MessageType {
  /// Initial handshake message from host to worker.
  ///
  /// Payload: `{port: ReplyToPort, toolDefinitions: List<Map>}`
  static const String handshake = 'handshake';

  /// Tool execution request from host to worker.
  ///
  /// Payload: `{toolKey: String, args: Map<String,dynamic>}`
  ///
  /// Example:
  /// ```dart
  /// executeToolMessage(
  ///   'calculator.add',
  ///   {'a': 5, 'b': 3}
  /// )
  /// // => {
  /// //   type: 'execute',
  /// //   id: 'req-12345',
  /// //   payload: {toolKey: 'calculator.add', args: {a: 5, b: 3}}
  /// // }
  /// ```
  static const String execute = 'execute';

  /// Request for current session tool definitions.
  ///
  /// Payload: `{}` (empty)
  ///
  /// Worker responds with list of available tool definitions.
  static const String listSessionDefinitions = 'listSessionDefinitions';

  /// Worker requests host to call a service API.
  ///
  /// Payload: `{api: String, method: String, args: Map<String,dynamic>}`
  ///
  /// Example:
  /// ```dart
  /// hostCallMessage(
  ///   'storage',
  ///   'get',
  ///   {'key': 'user_settings'}
  /// )
  /// // => {
  /// //   type: 'hostCall',
  /// //   id: 'req-67890',
  /// //   replyTo: <ReplyToPort>,
  /// //   payload: {api: 'storage', method: 'get', args: {key: 'user_settings'}}
  /// // }
  /// ```
  static const String hostCall = 'hostCall';

  /// Register a new tool dynamically.
  ///
  /// Payload: `{toolDefinition: Map}`
  ///
  /// Future: Used for MCP (Model Context Protocol) integration.
  static const String registerTool = 'registerTool';

  /// Unregister an existing tool.
  ///
  /// Payload: `{toolKey: String}`
  ///
  /// Future: Used for MCP (Model Context Protocol) integration.
  static const String unregisterTool = 'unregisterTool';

  /// Push notification: tool set has changed.
  ///
  /// Payload: `{tools: List<Map>, reason: String}`
  ///
  /// Reasons: 'initial', 'added', 'removed', 'updated', 'mcp_sync'
  ///
  /// Example:
  /// ```dart
  /// toolsChangedMessage(
  ///   [
  ///     {'key': 'calculator.add', 'name': 'Add Numbers'},
  ///     {'key': 'calculator.multiply', 'name': 'Multiply Numbers'},
  ///   ],
  ///   'initial'
  /// )
  /// ```
  static const String toolsChanged = 'toolsChanged';
}

// ============================================================================
// MESSAGE ENVELOPE STRUCTURE
// ============================================================================

/// Standard envelope for all protocol messages.
///
/// All messages passed between host and worker follow this structure:
///
/// ```dart
/// {
///   'type': String,           // Message type from [MessageType]
///   'id': String,             // Unique request ID for correlation
///   'payload': Map<String,dynamic>, // Message-specific data
///   'replyTo': ReplyToPort?,   // Optional: response recipient (SendPort or WebSendPort)
/// }
/// ```
///
/// # Requirements
///
/// - `type` is required and must be a valid [MessageType] constant
/// - `id` is required for tracing and correlation
/// - `payload` is required (may be empty map)
/// - `replyTo` is only included in messages that expect responses
abstract final class MessageEnvelope {
  /// All valid message type keys.
  static const Set<String> validTypes = {
    MessageType.handshake,
    MessageType.execute,
    MessageType.listSessionDefinitions,
    MessageType.hostCall,
    MessageType.registerTool,
    MessageType.unregisterTool,
    MessageType.toolsChanged,
  };

  /// Required envelope keys.
  static const Set<String> requiredKeys = {'type', 'id', 'payload'};

  /// Optional envelope keys.
  static const Set<String> optionalKeys = {'replyTo'};

  /// All valid envelope keys.
  static const Set<String> validKeys = {...requiredKeys, ...optionalKeys};
}

// ============================================================================
// MESSAGE BUILDERS
// ============================================================================

/// Handshake message builder.
///
/// Initiates communication between host and worker. The host sends its
/// receive port and initial tool definitions.
///
/// Parameters:
/// - `port`: ReplyToPort from host's ReceivePort (SendPort on Native, WebSendPort on Web)
/// - `toolDefinitions`: List of tool definitions available to worker
/// - `id`: Optional request ID (auto-generated if omitted)
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final handshake = handshakeMessage(
///   hostPort,
///   [
///     {'key': 'math.add', 'name': 'Add'},
///     {'key': 'math.subtract', 'name': 'Subtract'},
///   ],
/// );
/// workerPort.send(handshake);
/// ```
Map<String, dynamic> handshakeMessage(
  ReplyToPort port,
  List<Map<String, dynamic>> toolDefinitions, {
  String? id,
}) {
  return {
    'type': MessageType.handshake,
    'id': id ?? generateMessageId(),
    'payload': {
      'port': port,
      'toolDefinitions': toolDefinitions,
    },
  };
}

/// Execute tool message builder.
///
/// Requests the worker to execute a specific tool with given arguments.
///
/// Parameters:
/// - `toolKey`: Unique identifier of the tool (e.g., 'calculator.add')
/// - `args`: Tool-specific arguments
/// - `id`: Optional request ID (auto-generated if omitted)
/// - `replyTo`: Optional ReplyToPort for response
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final request = executeToolMessage(
///   'calculator.add',
///   {'a': 5, 'b': 3},
///   replyTo: hostPort,
/// );
/// ```
Map<String, dynamic> executeToolMessage(
  String toolKey,
  Map<String, dynamic> args, {
  String? id,
  ReplyToPort? replyTo,
}) {
  final message = {
    'type': MessageType.execute,
    'id': id ?? generateMessageId(),
    'payload': {
      'toolKey': toolKey,
      'args': args,
    },
  };
  if (replyTo != null) {
    message['replyTo'] = replyTo;
  }
  return message;
}

/// List session definitions message builder.
///
/// Requests the worker to return all current tool definitions.
///
/// Parameters:
/// - `id`: Optional request ID (auto-generated if omitted)
/// - `replyTo`: ReplyToPort for receiving the definition list
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final request = listSessionDefinitionsMessage(
///   replyTo: hostPort,
/// );
/// ```
Map<String, dynamic> listSessionDefinitionsMessage({
  String? id,
  ReplyToPort? replyTo,
}) {
  final message = {
    'type': MessageType.listSessionDefinitions,
    'id': id ?? generateMessageId(),
    'payload': {},
  };
  if (replyTo != null) {
    message['replyTo'] = replyTo;
  }
  return message;
}

/// Host call message builder.
///
/// Sent from worker to host requesting a service operation. The worker
/// includes a replyTo port to receive the response.
///
/// Parameters:
/// - `api`: Service name (e.g., 'storage', 'network', 'logging')
/// - `method`: Operation to perform
/// - `args`: Operation-specific arguments
/// - `id`: Optional request ID (auto-generated if omitted)
/// - `replyTo`: ReplyToPort for response (required)
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final request = hostCallMessage(
///   'storage',
///   'getValue',
///   {'key': 'session_id'},
///   replyTo: workerPort,
/// );
/// ```
Map<String, dynamic> hostCallMessage(
  String api,
  String method,
  Map<String, dynamic> args, {
  String? id,
  ReplyToPort? replyTo,
}) {
  final message = {
    'type': MessageType.hostCall,
    'id': id ?? generateMessageId(),
    'payload': {
      'api': api,
      'method': method,
      'args': args,
    },
  };
  if (replyTo != null) {
    message['replyTo'] = replyTo;
  }
  return message;
}

/// Register tool message builder.
///
/// Registers a new tool dynamically. Used for MCP (Model Context Protocol)
/// integration where tools may be added at runtime.
///
/// Parameters:
/// - `toolDefinition`: Complete tool definition map
/// - `id`: Optional request ID (auto-generated if omitted)
/// - `replyTo`: Optional ReplyToPort for acknowledgment
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final request = registerToolMessage(
///   {
///     'key': 'mcp.new_tool',
///     'name': 'New Tool',
///     'description': 'Tool from MCP server',
///   },
///   replyTo: hostPort,
/// );
/// ```
Map<String, dynamic> registerToolMessage(
  Map<String, dynamic> toolDefinition, {
  String? id,
  ReplyToPort? replyTo,
}) {
  final message = {
    'type': MessageType.registerTool,
    'id': id ?? generateMessageId(),
    'payload': {
      'toolDefinition': toolDefinition,
    },
  };
  if (replyTo != null) {
    message['replyTo'] = replyTo;
  }
  return message;
}

/// Unregister tool message builder.
///
/// Unregisters an existing tool. Used for MCP (Model Context Protocol)
/// integration where tools may be removed at runtime.
///
/// Parameters:
/// - `toolKey`: Unique identifier of tool to unregister
/// - `id`: Optional request ID (auto-generated if omitted)
/// - `replyTo`: Optional ReplyToPort for acknowledgment
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final request = unregisterToolMessage(
///   'mcp.old_tool',
///   replyTo: hostPort,
/// );
/// ```
Map<String, dynamic> unregisterToolMessage(
  String toolKey, {
  String? id,
  ReplyToPort? replyTo,
}) {
  final message = {
    'type': MessageType.unregisterTool,
    'id': id ?? generateMessageId(),
    'payload': {
      'toolKey': toolKey,
    },
  };
  if (replyTo != null) {
    message['replyTo'] = replyTo;
  }
  return message;
}

/// Tools changed notification message builder.
///
/// Notifies worker that the set of available tools has changed. This is
/// a push event (no response expected).
///
/// Parameters:
/// - `tools`: Updated list of tool definitions
/// - `reason`: Why tools changed ('initial', 'added', 'removed', 'updated', 'mcp_sync')
/// - `id`: Optional request ID (auto-generated if omitted)
///
/// Returns: Complete message envelope ready to send
///
/// Example:
/// ```dart
/// final notification = toolsChangedMessage(
///   [
///     {'key': 'calc.add', 'name': 'Add'},
///     {'key': 'calc.multiply', 'name': 'Multiply'},
///   ],
///   'added',
/// );
/// ```
Map<String, dynamic> toolsChangedMessage(
  List<Map<String, dynamic>> tools,
  String reason, {
  String? id,
}) {
  return {
    'type': MessageType.toolsChanged,
    'id': id ?? generateMessageId(),
    'payload': {
      'tools': tools,
      'reason': reason,
    },
  };
}

// ============================================================================
// RESPONSE ENVELOPE BUILDERS
// ============================================================================

/// Success response builder.
///
/// Builds a response message indicating successful completion of a request.
///
/// Parameters:
/// - `requestId`: ID of the request being responded to
/// - `data`: Response payload data
/// - `id`: Optional response ID (auto-generated if omitted)
///
/// Returns: Response envelope as `Map<String,dynamic>`
///
/// Example:
/// ```dart
/// final response = successResponse(
///   'req-12345',
///   {'result': 8, 'executionTime': 0.5},
/// );
/// ```
Map<String, dynamic> successResponse(
  String requestId,
  Map<String, dynamic> data, {
  String? id,
}) {
  return {
    'type': 'response',
    'requestId': requestId,
    'id': id ?? generateMessageId(),
    'status': 'success',
    'data': data,
  };
}

/// Error response builder.
///
/// Builds a response message indicating request failure.
///
/// Parameters:
/// - `requestId`: ID of the request being responded to
/// - `error`: Error message
/// - `code`: Optional error code (e.g., 'TOOL_NOT_FOUND', 'EXECUTION_ERROR')
/// - `id`: Optional response ID (auto-generated if omitted)
///
/// Returns: Error response envelope as `Map<String,dynamic>`
///
/// Example:
/// ```dart
/// final response = errorResponse(
///   'req-12345',
///   'Tool not found',
///   code: 'TOOL_NOT_FOUND',
/// );
/// ```
Map<String, dynamic> errorResponse(
  String requestId,
  String error, {
  String? code,
  String? id,
}) {
  final response = {
    'type': 'response',
    'requestId': requestId,
    'id': id ?? generateMessageId(),
    'status': 'error',
    'error': error,
  };
  if (code != null) {
    response['code'] = code;
  }
  return response;
}

// ============================================================================
// ID GENERATION UTILITY
// ============================================================================

/// Unique message ID counter (thread-safe within Dart's single-threaded model).
int _messageIdCounter = 0;

/// Generates a unique message ID.
///
/// IDs have the format: `msg-<timestamp>-<counter>`
///
/// This ensures:
/// - Uniqueness across all messages
/// - Timestamp helps debugging
/// - Incrementing counter prevents collisions within same millisecond
///
/// Returns: A unique message ID string
///
/// Example:
/// ```dart
/// final id1 = generateMessageId(); // 'msg-1705595022480-1'
/// final id2 = generateMessageId(); // 'msg-1705595022480-2'
/// ```
String generateMessageId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  _messageIdCounter++;
  return 'msg-$timestamp-$_messageIdCounter';
}

// ============================================================================
// VALIDATION UTILITIES
// ============================================================================

/// Validates that a value is sendable across worker boundary.
///
/// Only the following types are safe to send:
/// - `null`
/// - `bool`
/// - `int`
/// - `double`
/// - `String`
/// - `List<dynamic>` (must contain only sendable values)
/// - `Map<String, dynamic>` (must contain only sendable values)
/// - `ReplyToPort` (SendPort on Native, WebSendPort on Web)
///
/// Parameters:
/// - `value`: Value to validate
/// - `path`: Current path in nested structure (for error messages)
///
/// Returns: `(true, '')` if sendable, `(false, errorMessage)` otherwise
///
/// Example:
/// ```dart
/// var (valid, error) = isValueSendable({'key': 'value', 'port': sendPort});
/// if (!valid) print('Invalid: $error');
/// ```
(bool, String) isValueSendable(
  dynamic value, [
  String path = 'root',
]) {
  // Null is sendable
  if (value == null) {
    return (true, '');
  }

  // Primitives are sendable
  if (value is bool || value is int || value is double || value is String) {
    return (true, '');
  }

  // ReplyToPort is sendable (platform-specific check)
  if (platform.isValidReplyTo(value)) {
    return (true, '');
  }

  // List: all elements must be sendable
  if (value is List) {
    for (int i = 0; i < value.length; i++) {
      final (valid, error) = isValueSendable(value[i], '$path[$i]');
      if (!valid) return (false, error);
    }
    return (true, '');
  }

  // Map: all values must be sendable (keys should be strings)
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String) {
        return (
          false,
          '$path: Map keys must be strings, found ${entry.key.runtimeType}'
        );
      }
      final (valid, error) =
          isValueSendable(entry.value, '$path[${entry.key}]');
      if (!valid) return (false, error);
    }
    return (true, '');
  }

  // Type not sendable
  return (
    false,
    '$path: Type ${value.runtimeType} is not sendable across worker boundary'
  );
}

/// Validates a complete message envelope.
///
/// Ensures the message structure is valid and all values are sendable.
///
/// Parameters:
/// - `message`: Message to validate
///
/// Returns: `(true, '')` if valid, `(false, errorMessage)` otherwise
///
/// Example:
/// ```dart
/// final message = executeToolMessage('calc.add', {'a': 5, 'b': 3});
/// var (valid, error) = validateMessageEnvelope(message);
/// ```
(bool, String) validateMessageEnvelope(Map<String, dynamic> message) {
  // Check required keys
  for (final key in MessageEnvelope.requiredKeys) {
    if (!message.containsKey(key)) {
      return (false, 'Missing required key: $key');
    }
  }

  // Check for unknown keys
  for (final key in message.keys) {
    if (!MessageEnvelope.validKeys.contains(key)) {
      return (false, 'Unknown key: $key');
    }
  }

  // Validate type
  final type = message['type'];
  if (type is! String) {
    return (false, 'type must be String, got ${type.runtimeType}');
  }
  if (!MessageEnvelope.validTypes.contains(type)) {
    return (false, 'Invalid message type: $type');
  }

  // Validate id
  final id = message['id'];
  if (id is! String) {
    return (false, 'id must be String, got ${id.runtimeType}');
  }

  // Validate payload
  final payload = message['payload'];
  if (payload is! Map) {
    return (false, 'payload must be Map, got ${payload.runtimeType}');
  }

  // Validate replyTo if present
  if (message.containsKey('replyTo')) {
    final replyTo = message['replyTo'];
    if (!platform.isValidReplyTo(replyTo)) {
      return (false, 'replyTo must be ${platform.replyToTypeName()}, got ${replyTo.runtimeType}');
    }
  }

  // Validate all payload values are sendable
  final (payloadValid, payloadError) = isValueSendable(payload);
  if (!payloadValid) {
    return (false, 'payload contains non-sendable value: $payloadError');
  }

  return (true, '');
}
