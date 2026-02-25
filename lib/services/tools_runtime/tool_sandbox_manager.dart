import 'dart:async';
import 'dart:convert';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/interfaces/tool_storage.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/tools_runtime/sandbox_platform_web.dart';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/host/notepad_host_api.dart';
import 'package:vagina/services/tools_runtime/host/call_host_api.dart';
import 'package:vagina/services/tools_runtime/host/tool_storage_host_api.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/tools/tools.dart';

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
  final ToolStorage _toolStorage;
  final ConfigRepository _configRepository;
  final CallService _callService;

  late NotepadHostApi _notepadHostApi;
  late CallHostApi _callHostApi;

  // Tool storage API with context callback for dynamic tool key resolution
  late ToolStorageHostApi _toolStorageHostApi;

  // Track currently executing tool for hostCall routing
  String? _currentExecutingToolKey;

  // Worker management (platform-agnostic)
  platform.PlatformIsolate? _worker;
  late platform.PlatformReceivePort _receivePort;
  late platform.PlatformSendPort _workerSendPort;

  // Message routing
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  // Latest tool registry from worker (SSoT for tool metadata on host side)
  List<Tool> _latestTools = const [];

  // Tools changed stream
  late StreamController<ToolsChangedEvent> _toolsChangedController;

  // Lifecycle state
  bool _isStarted = false;
  bool _isDisposed = false;

  ToolSandboxManager({
    required NotepadService notepadService,
    required ToolStorage toolStorage,
    required CallService callService,
    required ConfigRepository configRepository,
  })  : _notepadService = notepadService,
        _toolStorage = toolStorage,
        _configRepository = configRepository,
        _callService = callService {
    _notepadHostApi = NotepadHostApi(_notepadService);
    _callHostApi = CallHostApi(_callService);

    // Tool storage API with context callback to get current tool key
    // The callback will throw if called outside of tool execution context
    _toolStorageHostApi = ToolStorageHostApi(
      _toolStorage,
      () {
        if (_currentExecutingToolKey == null) {
          throw StateError(
            'toolStorage API called outside of tool execution context. '
            'This is a programming error - toolStorage should only be called from within a tool.',
          );
        }
        return _currentExecutingToolKey!;
      },
      resolveStorageNamespace: (toolKey) {
        // SSoT: resolve from the latest tool list, avoiding a separate cache.
        for (final tool in _latestTools) {
          if (tool.definition.toolKey == toolKey) {
            return tool.definition.publishedBy;
          }
        }
        return toolKey;
      },
    );

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

      // Load tool-specific initialization data
      final toolsData = await _loadToolsData();

      // Send handshake message with tools data
      final handshake = {
        'type': 'handshake',
        'id': generateMessageId(),
        'payload': {
          'port': _receivePort.sendPort,
          'toolsData': toolsData,
        },
      };
      (_workerSendPort as dynamic).send(handshake);

      // Start listening for incoming messages from worker
      _startMessageListener();

      _isStarted = true;
    } catch (e) {
      await _cleanup();
      rethrow;
    }
  }

  /// Load tool-specific initialization data
  ///
  /// This collects data needed by various tools for initialization by
  /// delegating to each tool's loadInitializationData method
  Future<Map<String, dynamic>> _loadToolsData() async {
    final toolsData = <String, dynamic>{};

    try {
      // Get all available tools from the catalog
      final tools = toolbox.tools;
      
      // Ask each tool if it needs initialization data
      for (final tool in tools) {
        try {
          final data = await tool.loadInitializationData(_configRepository);
          if (data != null && data.isNotEmpty) {
            // Merge tool's data into toolsData
            toolsData.addAll(data);
            print('$_tag: Loaded initialization data for ${tool.definition.toolKey}');
          }
        } catch (e) {
          print('$_tag: Error loading data for ${tool.definition.toolKey}: $e');
        }
      }
      
      print('$_tag: Loaded initialization data for ${toolsData.keys.length} tool categories');
      
    } catch (e) {
      print('$_tag: Error loading tools data: $e');
    }

    return toolsData;
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

  /// Execute a tool in the sandbox.
  Future<String> execute(String toolKey, Map<String, dynamic> args) async {
    if (!_isStarted) {
      throw StateError('ToolSandboxManager not started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    // Track current executing tool for hostCall routing.
    _currentExecutingToolKey = toolKey;

    try {
      final messageId = generateMessageId();
      final response = await _request(
        executeToolMessage(toolKey, args, id: messageId),
        timeoutTag: 'execute:$toolKey',
      );

      if (response['status'] != 'success') {
        final error = response['error'] as String?;
        throw Exception('Tool execution error: $error');
      }

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('No data in response');
      }

      final result = data['result'];
      return result is String ? result : jsonEncode(result);
    } finally {
      _currentExecutingToolKey = null;
    }
  }

  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> message, {
    required String timeoutTag,
  }) async {
    if (!_isStarted) {
      throw StateError('ToolSandboxManager not started');
    }
    if (_isDisposed) {
      throw StateError('ToolSandboxManager has been disposed');
    }

    final messageId = message['id'] as String?;
    if (messageId == null || messageId.isEmpty) {
      throw StateError('Invalid message: missing id');
    }

    final (valid, error) = validateMessageEnvelope(message);
    if (!valid) {
      throw StateError('Invalid message: $error');
    }

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[messageId] = completer;

    try {
      (_workerSendPort as dynamic).send(message);

      return await completer.future.timeout(
        _defaultTimeout,
        onTimeout: () {
          _pendingRequests.remove(messageId);
          throw TimeoutException(
            '$timeoutTag timeout: request did not respond within $_defaultTimeout',
          );
        },
      );
    } finally {
      _pendingRequests.remove(messageId);
    }
  }

  List<Tool> _parseToolsFromResponse(Map<String, dynamic> response) {
    if (response['status'] != 'success') {
      final error = response['error'] as String?;
      throw Exception('ToolSandbox response error: $error');
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final tools = data['tools'] as List?;
    if (tools == null) return [];

    return List<Tool>.from(
      tools.cast<Map<String, dynamic>>().map((json) => Tool.fromWireJson(json)),
    );
  }

  /// List all available tool definitions from the worker.
  Future<List<Tool>> getToolsFromWorker() async {
    final messageId = generateMessageId();
    final response = await _request(
      listSessionDefinitionsMessage(id: messageId),
      timeoutTag: 'listSessionDefinitions',
    );

    final toolsList = _parseToolsFromResponse(response);
    _setToolRegistry(toolsList);
    return toolsList;
  }

  /// Update a tool's enabled state in the sandbox worker.
  ///
  /// This changes the worker-side tool registry, and emits a toolsChanged event.
  Future<void> setToolEnabled(String toolKey, bool enabled) async {
    final messageId = generateMessageId();
    final response = await _request(
      setToolEnabledMessage(toolKey, enabled, id: messageId),
      timeoutTag: 'setToolEnabled',
    );

    if (response['status'] != 'success') {
      final error = response['error'] as String?;
      final code = response['code'];
      throw Exception('setToolEnabled error: $error (code=$code)');
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
  /// Routes to appropriate host adapter (NotepadHostApi, MemoryHostApi, ToolStorageHostApi, etc.)
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
        case 'call':
          result = await _callHostApi.handleCall(method, args);
          break;
        case 'toolStorage':
          // Tool storage API uses the injected callback to get current tool key
          result = await _toolStorageHostApi.handleCall(method, args);
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

  void _setToolRegistry(List<Tool> tools) {
    _latestTools = tools;
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

      final toolsList = List<Tool>.from(
        tools
            .cast<Map<String, dynamic>>()
            .map((json) => Tool.fromWireJson(json)),
      );

      _setToolRegistry(toolsList);

      final event = ToolsChangedEvent(
        tools: toolsList,
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
