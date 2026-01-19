import 'dart:async';
import 'dart:convert';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/text_agent_job_runner.dart';
import 'package:vagina/services/tools_runtime/sandbox_platform_web.dart';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/host/notepad_host_api.dart';
import 'package:vagina/services/tools_runtime/host/memory_host_api.dart';
import 'package:vagina/services/tools_runtime/host/call_host_api.dart';
import 'package:vagina/services/tools_runtime/host/text_agent_host_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';

// Platform-specific imports (conditional)
import 'sandbox_platform_native.dart'
    if (dart.library.html) 'sandbox_platform_web.dart' as platform;
import 'tool_sandbox_worker.dart' show toolSandboxWorker;

/// Event emitted when the set of available tools changes
class ToolsChangedEvent {
  /// List of updated tool definitions
  final List<Tool> tools;

  /// Reason for the change ('initial', 'added', 'removed', 'updated', 'mcp_sync')
  final String reason;

  ToolsChangedEvent({
    required this.tools,
    required this.reason,
  });

  @override
  String toString() =>
      'ToolsChangedEvent(reason: $reason, toolCount: ${tools.length})';
}

/// Manages the lifecycle and message routing for a sandboxed tool worker
///
/// This coordinator:
/// - Spawns a worker (Isolate on Native, pseudo-worker on Web)
/// - Handles bi-directional communication via message passing
/// - Routes `hostCall` requests to appropriate host adapters
/// - Provides a clean API for tool execution
class ToolSandboxManager {
  static const String _tag = 'ToolSandboxManager';
  static const Duration _defaultTimeout = Duration(seconds: 30);

  final NotepadService _notepadService;
  final MemoryRepository _memoryRepository;
  final CallService? _callService;
  final TextAgentService? _textAgentService;
  final TextAgentJobRunner? _jobRunner;
  final TextAgentRepository? _agentRepository;

  late NotepadHostApi _notepadHostApi;
  late MemoryHostApi _memoryHostApi;
  late CallHostApi? _callHostApi;
  late TextAgentHostApi? _textAgentHostApi;

  // Worker management (platform-agnostic)
  platform.PlatformIsolate? _worker;
  late platform.PlatformReceivePort _receivePort;
  late platform.PlatformSendPort _workerSendPort;

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
    CallService? callService,
    TextAgentService? textAgentService,
    TextAgentJobRunner? jobRunner,
    TextAgentRepository? agentRepository,
  })  : _notepadService = notepadService,
        _memoryRepository = memoryRepository,
        _callService = callService,
        _textAgentService = textAgentService,
        _jobRunner = jobRunner,
        _agentRepository = agentRepository {
    _notepadHostApi = NotepadHostApi(_notepadService);
    _memoryHostApi = MemoryHostApi(_memoryRepository);

    // Initialize call API if call service is provided
    _callHostApi = callService != null ? CallHostApi(callService) : null;

    // Initialize text agent API if all required services are provided
    _textAgentHostApi = (textAgentService != null &&
            jobRunner != null &&
            agentRepository != null)
        ? TextAgentHostApi(
            textAgentService: textAgentService,
            jobRunner: jobRunner,
            agentRepository: agentRepository,
          )
        : null;

    _toolsChangedController = StreamController<ToolsChangedEvent>.broadcast();
  }

  /// Stream of tool set change events from the worker
  Stream<ToolsChangedEvent> get toolsChanged => _toolsChangedController.stream;

  /// Whether the sandbox manager is currently running
  bool get isStarted => _isStarted;

  /// Whether the sandbox manager has been disposed
  bool get isDisposed => _isDisposed;

  /// Start the sandbox: spawn worker and establish communication
  ///
  /// This method:
  /// 1. Creates a ReceivePort for host-side listening
  /// 2. Spawns the worker (Isolate on Native, pseudo-worker on Web)
  /// 3. Performs handshake to get the worker's SendPort
  /// 4. Sets up message routing
  ///
  /// Throws if:
  /// - Already started or disposed
  /// - Worker spawn fails
  /// - Handshake timeout
  Future<void> start() async {
    if (_isStarted) {
      throw StateError('ToolSandboxManager already started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    try {
      // Spawn worker and get ports
      final (worker, receivePort, workerSendPort) =
          await platform.spawnPlatformWorker(
        toolSandboxWorker,
        _defaultTimeout,
      );

      _worker = worker;
      _receivePort = receivePort;
      _workerSendPort = workerSendPort;

      // Send handshake message to worker to initialize it
      final handshake = handshakeMessage(
        _receivePort.sendPort,
        [], // Empty tool definitions list (worker uses BuiltinToolCatalog)
      );
      (_workerSendPort as dynamic).send(handshake);

      // Start listening for incoming messages from worker
      _startMessageListener();

      _isStarted = true;
    } catch (e) {
      await _cleanup();
      rethrow;
    }
  }

  /// Dispose the sandbox: kill worker and cleanup resources
  ///
  /// This method:
  /// 1. Closes message listeners
  /// 2. Kills the worker
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
        // Send message to worker
        (_workerSendPort as dynamic).send(message);

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
      print('[$_tag:HOST] Failed to execute tool: $toolKey');
      print('Error: $e');
      print('Request Payload: ${jsonEncode(args)}');
      rethrow;
    }
  }

  /// List all available tool definitions from the worker
  ///
  /// Returns: List of tool definitions in realtime format
  /// (output of ToolDefinition.toRealtimeJson())
  ///
  /// Throws if:
  /// - Not started or already disposed
  /// - Request timeout
  /// - Message send fails
  Future<List<Tool>> getToolsFromWorker() async {
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
        // Send message to worker
        (_workerSendPort as dynamic).send(message);

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

        return List<Tool>.from(
          tools
              .cast<Map<String, dynamic>>()
              .map((json) => Tool.fromWorker(json)),
        );
      } finally {
        _pendingRequests.remove(messageId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Start listening for messages from the worker
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
        print('$_tag: Error in message listener: $error');
      },
      onDone: () {
        // Worker terminated
        _handleWorkerDone();
      },
    );
  }

  /// Handle an incoming message from the worker
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

      print('$_tag: Unknown message type: $type');
    } catch (e) {
      print('$_tag: Error handling message: $e');
    }
  }

  /// Handle a response message from the worker
  ///
  /// Completes the corresponding pending request
  void _handleResponseMessage(String requestId, Map<String, dynamic> message) {
    final completer = _pendingRequests[requestId];
    if (completer == null) {
      print('$_tag: Received response for unknown request: $requestId');
      return;
    }

    try {
      completer.complete(message);
    } catch (e) {
      print('$_tag: Error completing request $requestId: $e');
    }
  }

  /// Handle a hostCall request from the worker
  ///
  /// Routes to appropriate host adapter (NotepadHostApi or MemoryHostApi)
  /// and sends response back to worker via the replyTo port
  void _handleHostCall(String requestId, Map<String, dynamic> message) async {
    try {
      // Extract replyTo port from message
      if (message['replyTo'] == null) {
        print('[$_tag:HOST] hostCall missing replyTo port');
        return;
      }

      final replyTo = message['replyTo'] as PlatformSendPort;

      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _sendHostCallError(requestId, 'Missing payload', replyTo);
        return;
      }

      final api = payload['api'] as String?;
      final method = payload['method'] as String?;
      final args = payload['args'] as Map<String, dynamic>? ?? {};

      if (api == null || method == null) {
        _sendHostCallError(requestId, 'Missing api or method', replyTo);
        return;
      }

      // Route to appropriate host API
      dynamic result;

      switch (api) {
        case 'notepad':
          result = await _notepadHostApi.handleCall(method, args);
          break;
        case 'memory':
          result = await _memoryHostApi.handleCall(method, args);
          break;
        case 'call':
          result = await _callHostApi!.handleCall(method, args);
          break;
        case 'textAgent':
          result = await _textAgentHostApi!.handleCall(method, args);
          break;
        default:
          _sendHostCallError(requestId, 'Unknown API: $api', replyTo);
          return;
      }

      // Send result back to worker via replyTo port
      _sendHostCallResponse(requestId, result, replyTo);
    } catch (e) {
      // If we have replyTo, send error there; otherwise log only
      final replyTo = message['replyTo'];
      if (replyTo != null) {
        final payload = message['payload'] as Map<String, dynamic>?;
        final api = payload?['api'] as String? ?? 'unknown';
        final method = payload?['method'] as String? ?? 'unknown';
        final args = payload?['args'] as Map<String, dynamic>? ?? {};
        print(
            '[$_tag:HOST] Failed to handle hostCall for $api.$method\nError: $e\nRequest Payload: ${jsonEncode(args)}');
        _sendHostCallError(requestId, 'Error: $e', replyTo);
      } else {
        print('[$_tag:HOST] Error in hostCall (no replyTo): $e');
      }
    }
  }

  /// Send a hostCall response to the worker via the replyTo port
  void _sendHostCallResponse(
      String requestId, dynamic result, PlatformSendPort replyTo) {
    try {
      final response = successResponse(requestId, result);
      replyTo.send(response);
    } catch (e) {
      print('$_tag: Error sending hostCall response: $e');
    }
  }

  /// Send a hostCall error response to the worker via the replyTo port
  void _sendHostCallError(
      String requestId, String error, PlatformSendPort replyTo) {
    try {
      final response = errorResponse(requestId, error);
      replyTo.send(response);
    } catch (e) {
      print('$_tag: Error sending hostCall error: $e');
    }
  }

  /// Handle toolsChanged push event from the worker
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
        tools: List<Tool>.from(
          tools
              .cast<Map<String, dynamic>>()
              .map((json) => Tool.fromWorker(json)),
        ),
        reason: reason,
      );

      _toolsChangedController.add(event);
    } catch (e) {
      print('$_tag: Error handling toolsChanged: $e');
    }
  }

  /// Handle worker termination
  void _handleWorkerDone() {
    print('$_tag: Worker terminated');
    _isStarted = false;

    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Worker terminated');
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

      // Kill worker if running
      if (_worker != null) {
        platform.killPlatformWorker(_worker!);
        _worker = null;
      }

      // Close receive port
      _receivePort.close();

      // Close stream controller
      await _toolsChangedController.close();

      _isStarted = false;
    } catch (e) {
      print('$_tag: Error during cleanup: $e');
    }
  }
}
