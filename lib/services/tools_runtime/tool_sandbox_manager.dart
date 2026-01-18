import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/host/notepad_host_api.dart';
import 'package:vagina/services/tools_runtime/host/memory_host_api.dart';
import 'package:vagina/services/tools_runtime/tool_sandbox_worker.dart';

/// Event emitted when the set of available tools changes
class ToolsChangedEvent {
  /// List of updated tool definitions
  final List<Map<String, dynamic>> tools;
  
  /// Reason for the change ('initial', 'added', 'removed', 'updated', 'mcp_sync')
  final String reason;

  ToolsChangedEvent({
    required this.tools,
    required this.reason,
  });

  @override
  String toString() => 'ToolsChangedEvent(reason: $reason, toolCount: ${tools.length})';
}

/// Manages the lifecycle and message routing for an isolated tool sandbox
///
/// This coordinator:
/// - Spawns an isolate worker for tool execution
/// - Handles bi-directional communication via message passing
/// - Routes `hostCall` requests to appropriate host adapters
/// - Provides a clean API for tool execution
class ToolSandboxManager {
  static const String _tag = 'ToolSandboxManager';
  static const Duration _defaultTimeout = Duration(seconds: 30);

  final NotepadService _notepadService;
  final MemoryRepository _memoryRepository;
  
  late NotepadHostApi _notepadHostApi;
  late MemoryHostApi _memoryHostApi;

  // Isolate management
  Isolate? _isolate;
  late ReceivePort _receivePort;
  late SendPort _isolateSendPort;

  // Message routing
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  // Tools changed stream
  late StreamController<ToolsChangedEvent> _toolsChangedController;

  // Lifecycle state
  bool _isStarted = false;
  bool _isDisposed = false;

  ToolSandboxManager({
    required NotepadService notepadService,
    required MemoryRepository memoryRepository,
  })  : _notepadService = notepadService,
        _memoryRepository = memoryRepository {
    _notepadHostApi = NotepadHostApi(_notepadService);
    _memoryHostApi = MemoryHostApi(_memoryRepository);
    _toolsChangedController = StreamController<ToolsChangedEvent>.broadcast();
  }

  /// Stream of tool set change events from the isolate
  Stream<ToolsChangedEvent> get toolsChanged => _toolsChangedController.stream;

  /// Whether the sandbox manager is currently running
  bool get isStarted => _isStarted;

  /// Whether the sandbox manager has been disposed
  bool get isDisposed => _isDisposed;

  /// Start the sandbox: spawn isolate and establish communication
  ///
  /// This method:
  /// 1. Creates a ReceivePort for host-side listening
  /// 2. Spawns the worker isolate
  /// 3. Performs handshake to get the isolate's SendPort
  /// 4. Sets up message routing
  ///
  /// Throws if:
  /// - Already started or disposed
  /// - Isolate spawn fails
  /// - Handshake timeout
  Future<void> start() async {
    if (_isStarted) {
      throw StateError('ToolSandboxManager already started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    try {
      // Create receive port for host-side listening
      _receivePort = ReceivePort();

      // Spawn the isolate worker
      _isolate = await Isolate.spawn(
        toolSandboxWorker,
        _receivePort.sendPort,
      );

      // Wait for handshake response with isolate's SendPort
      final handshakeMessage = await _receivePort.first.timeout(
        _defaultTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Handshake timeout: isolate did not respond within $_defaultTimeout',
          );
        },
      );

      if (handshakeMessage is! SendPort) {
        throw StateError('Invalid handshake response: expected SendPort');
      }

      _isolateSendPort = handshakeMessage;

      // Start listening for incoming messages from isolate
      _startMessageListener();

      _isStarted = true;
    } catch (e) {
      await _cleanup();
      rethrow;
    }
  }

  /// Dispose the sandbox: kill isolate and cleanup resources
  ///
  /// This method:
  /// 1. Closes message listeners
  /// 2. Kills the isolate
  /// 3. Cleans up pending requests
  /// 4. Closes the stream controllers
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      await _cleanup();
    } finally {
      _isDisposed = true;
    }
  }

  /// Execute a tool in the sandbox
  ///
  /// Parameters:
  /// - `toolKey`: Unique identifier of the tool
  /// - `args`: Tool arguments as a map
  ///
  /// Returns: Tool output as a JSON string
  ///
  /// Throws if:
  /// - Not started or already disposed
  /// - Execution timeout
  /// - Tool execution error
  /// - Message send fails
  Future<String> execute(String toolKey, Map<String, dynamic> args) async {
    if (!_isStarted) {
      throw StateError('ToolSandboxManager not started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    try {
      final messageId = generateMessageId();
      
      // Create and validate the execute message
      final message = executeToolMessage(
        toolKey,
        args,
        id: messageId,
      );
      
      final (valid, error) = validateMessageEnvelope(message);
      if (!valid) {
        throw StateError('Invalid message: $error');
      }

      // Register pending request
      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[messageId] = completer;

      try {
        // Send message to isolate
        _isolateSendPort.send(message);

        // Wait for response with timeout
        final response = await completer.future.timeout(
          _defaultTimeout,
          onTimeout: () {
            _pendingRequests.remove(messageId);
            throw TimeoutException(
              'Tool execution timeout: $toolKey did not respond within $_defaultTimeout',
            );
          },
        );

        // Check response status
        if (response['status'] != 'success') {
          final error = response['error'] as String?;
          throw Exception('Tool execution error: $error');
        }

        // Get the result data
        final data = response['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('No data in response');
        }

        // Convert result to JSON string
        final result = data['result'];
        if (result is String) {
          return result;
        } else {
          return jsonEncode(result);
        }
      } finally {
        _pendingRequests.remove(messageId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// List all available tool definitions from the isolate
  ///
  /// Returns: List of tool definitions in realtime format
  /// (output of ToolDefinition.toRealtimeJson())
  ///
  /// Throws if:
  /// - Not started or already disposed
  /// - Request timeout
  /// - Message send fails
  Future<List<Map<String, dynamic>>> listSessionDefinitions() async {
    if (!_isStarted) {
      throw StateError('ToolSandboxManager not started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    try {
      final messageId = generateMessageId();
      
      // Create and validate the request message
      final message = listSessionDefinitionsMessage(id: messageId);
      
      final (valid, error) = validateMessageEnvelope(message);
      if (!valid) {
        throw StateError('Invalid message: $error');
      }

      // Register pending request
      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[messageId] = completer;

      try {
        // Send message to isolate
        _isolateSendPort.send(message);

        // Wait for response with timeout
        final response = await completer.future.timeout(
          _defaultTimeout,
          onTimeout: () {
            _pendingRequests.remove(messageId);
            throw TimeoutException(
              'listSessionDefinitions timeout: request did not respond within $_defaultTimeout',
            );
          },
        );

        // Check response status
        if (response['status'] != 'success') {
          final error = response['error'] as String?;
          throw Exception('listSessionDefinitions error: $error');
        }

        // Extract and return tools list
        final data = response['data'] as Map<String, dynamic>?;
        if (data == null) {
          return [];
        }

        final tools = data['tools'] as List?;
        if (tools == null) {
          return [];
        }

        return List<Map<String, dynamic>>.from(
          tools.cast<Map<String, dynamic>>(),
        );
      } finally {
        _pendingRequests.remove(messageId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Start listening for messages from the isolate
  ///
  /// Sets up the main message loop that handles:
  /// - Response messages (completing pending requests)
  /// - hostCall requests (routing to appropriate APIs)
  /// - Push events (toolsChanged notifications)
  void _startMessageListener() {
    _receivePort.listen(
      (dynamic message) {
        if (message is Map<String, dynamic>) {
          _handleMessage(message);
        }
      },
      onError: (error) {
        // Log error but don't crash
        print('ToolSandboxManager: Error in message listener: $error');
      },
      onDone: () {
        // Isolate terminated
        _handleIsolateDone();
      },
    );
  }

  /// Handle an incoming message from the isolate
  void _handleMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'] as String?;
      final requestId = message['requestId'] as String?;
      final id = message['id'] as String?;

      // Handle response messages (have requestId)
      if (requestId != null && type == 'response') {
        _handleResponseMessage(requestId, message);
        return;
      }

      // Handle hostCall requests (have id and type=hostCall)
      if (id != null && type == 'hostCall') {
        _handleHostCall(id, message);
        return;
      }

      // Handle toolsChanged push events
      if (type == 'toolsChanged') {
        _handleToolsChanged(message);
        return;
      }

      print('ToolSandboxManager: Unknown message type: $type');
    } catch (e) {
      print('ToolSandboxManager: Error handling message: $e');
    }
  }

  /// Handle a response message from the isolate
  ///
  /// Completes the corresponding pending request
  void _handleResponseMessage(String requestId, Map<String, dynamic> message) {
    final completer = _pendingRequests[requestId];
    if (completer == null) {
      print('ToolSandboxManager: Received response for unknown request: $requestId');
      return;
    }

    try {
      completer.complete(message);
    } catch (e) {
      print('ToolSandboxManager: Error completing request $requestId: $e');
    }
  }

  /// Handle a hostCall request from the isolate
  ///
  /// Routes to appropriate host adapter (NotepadHostApi or MemoryHostApi)
  /// and sends response back to isolate
  void _handleHostCall(String requestId, Map<String, dynamic> message) async {
    try {
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _sendHostCallError(requestId, 'Missing payload');
        return;
      }

      final api = payload['api'] as String?;
      final method = payload['method'] as String?;
      final args = payload['args'] as Map<String, dynamic>? ?? {};

      if (api == null || method == null) {
        _sendHostCallError(requestId, 'Missing api or method');
        return;
      }

      // Route to appropriate host API
      Map<String, dynamic> result;
      
      switch (api) {
        case 'notepad':
          result = await _notepadHostApi.handleCall(method, args);
          break;
        case 'memory':
          result = await _memoryHostApi.handleCall(method, args);
          break;
        default:
          _sendHostCallError(requestId, 'Unknown API: $api');
          return;
      }

      // Send result back to isolate
      _sendHostCallResponse(requestId, result);
    } catch (e) {
      _sendHostCallError(requestId, 'Error: $e');
    }
  }

  /// Send a hostCall response to the isolate
  void _sendHostCallResponse(String requestId, Map<String, dynamic> result) {
    try {
      final response = successResponse(requestId, result);
      final replyTo = _isolateSendPort;
      replyTo.send(response);
    } catch (e) {
      print('ToolSandboxManager: Error sending hostCall response: $e');
    }
  }

  /// Send a hostCall error response to the isolate
  void _sendHostCallError(String requestId, String error) {
    try {
      final response = errorResponse(requestId, error);
      final replyTo = _isolateSendPort;
      replyTo.send(response);
    } catch (e) {
      print('ToolSandboxManager: Error sending hostCall error: $e');
    }
  }

  /// Handle toolsChanged push event from the isolate
  void _handleToolsChanged(Map<String, dynamic> message) {
    try {
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        return;
      }

      final tools = payload['tools'] as List?;
      final reason = payload['reason'] as String?;

      if (tools == null || reason == null) {
        return;
      }

      final event = ToolsChangedEvent(
        tools: List<Map<String, dynamic>>.from(
          tools.cast<Map<String, dynamic>>(),
        ),
        reason: reason,
      );

      _toolsChangedController.add(event);
    } catch (e) {
      print('ToolSandboxManager: Error handling toolsChanged: $e');
    }
  }

  /// Handle isolate termination
  void _handleIsolateDone() {
    print('ToolSandboxManager: Isolate terminated');
    _isStarted = false;
    
    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Isolate terminated');
      }
    }
    _pendingRequests.clear();
  }

  /// Clean up all resources
  Future<void> _cleanup() async {
    try {
      // Complete all pending requests with error
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError('ToolSandboxManager disposed');
        }
      }
      _pendingRequests.clear();

      // Kill isolate if running
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }

      // Close receive port
      _receivePort.close();

      // Close stream controller
      await _toolsChangedController.close();

      _isStarted = false;
    } catch (e) {
      print('ToolSandboxManager: Error during cleanup: $e');
    }
  }
}

