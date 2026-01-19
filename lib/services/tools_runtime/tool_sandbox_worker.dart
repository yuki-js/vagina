import 'dart:async';
import 'dart:convert';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';
import 'package:vagina/services/tools_runtime/apis/memory_api.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/tools/builtin/builtin_tool_catalog.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/models/notepad_tab.dart';

// Platform-specific imports (conditional)
import 'sandbox_platform_native.dart'
    if (dart.library.html) 'sandbox_platform_web.dart' as platform;

const String _tag = 'ToolSandboxWorker';

/// Worker isolate entrypoint for tool sandbox execution.
///
/// This function runs inside the spawned isolate and:
/// 1. Establishes bi-directional communication with the host
/// 2. Initializes the tool registry
/// 3. Handles tool execution requests
/// 4. Manages hostCall requests for side effects
/// 5. Emits toolsChanged events
void toolSandboxWorker(platform.PlatformSendPort hostSendPort) {
  try {
    _log('Worker starting');

    // Create worker ReceivePort for bi-directional communication
    final workerReceivePort = platform.PlatformReceivePort();

    // Send worker's SendPort back to host for them to use
    (hostSendPort as dynamic).send(workerReceivePort.sendPort);
    _log('Sent worker SendPort to host');

    // Perform handshake and establish communication
    final controller = _WorkerController(
      hostSendPort: hostSendPort,
      workerReceivePort: workerReceivePort,
    );

    // Start listening for messages
    controller.start();
  } catch (e, stackTrace) {
    _log('FATAL ERROR in worker entrypoint: $e');
    _log('Stack trace: $stackTrace');
    // Isolate will be killed by host if it crashes
  }
}

/// Manages the worker's lifecycle and message handling.
class _WorkerController {
  static const Duration _hostCallTimeout = Duration(seconds: 30);

  final platform.PlatformSendPort hostSendPort;
  final platform.PlatformReceivePort workerReceivePort;
  late ReplyToPort? _hostReceivePort;

  // Tool registry
  final Map<String, Map<String, dynamic>> _toolDefinitions = {};

  // Pending hostCall requests
  final Map<String, Completer<Map<String, dynamic>>> _pendingHostCalls = {};

  // Per-session ToolContext (created during initialization)
  late ToolContext _toolContext;

  // Late API clients (created during handshake)
  late NotepadApiClient _notepadApiClient;
  late MemoryApiClient _memoryApiClient;
  late CallApiClient _callApiClient;
  late TextAgentApiClient _textAgentApiClient;

  _WorkerController({
    required this.hostSendPort,
    required this.workerReceivePort,
  });

  /// Start the worker main loop
  void start() {
    _log('Starting message loop');

    workerReceivePort.listen(
      (dynamic message) {
        if (message is Map<String, dynamic>) {
          _handleMessage(message);
        } else {
          _log('WARNING: Received non-map message: ${message.runtimeType}');
        }
      },
      onError: (error) {
        _log('ERROR in message listener: $error');
      },
      onDone: () {
        _log('Worker ReceivePort closed');
      },
    );

    _log('Message loop started');
  }

  /// Handle an incoming message from the host
  Future<void> _handleMessage(Map<String, dynamic> message) async {
    try {
      // Validate message envelope
      final (valid, error) = validateMessageEnvelope(message);
      if (!valid) {
        _log('ERROR: Invalid message envelope: $error');
        return;
      }

      final type = message['type'] as String;
      final id = message['id'] as String;

      _log('Received message: type=$type, id=$id');

      switch (type) {
        case MessageType.handshake:
          await _handleHandshake(message);
          break;

        case MessageType.execute:
          await _handleExecute(id, message);
          break;

        case MessageType.listSessionDefinitions:
          await _handleListSessionDefinitions(id, message);
          break;

        case MessageType.registerTool:
          await _handleRegisterTool(id, message);
          break;

        case MessageType.unregisterTool:
          await _handleUnregisterTool(id, message);
          break;

        default:
          _log('WARNING: Unknown message type: $type');
      }
    } catch (e, stackTrace) {
      _log('ERROR handling message: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  /// Handle handshake message from host
  ///
  /// This initializes the tool registry and creates the ToolContext with API clients.
  Future<void> _handleHandshake(Map<String, dynamic> message) async {
    try {
      _log('Handling handshake');

      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _log('ERROR: No payload in handshake');
        return;
      }

      final port = payload['port'];
      if (!isValidReplyToPort(port)) {
        _log('ERROR: Invalid or missing port in handshake payload');
        return;
      }

      _hostReceivePort = port as ReplyToPort;
      _log('Stored host port');

      // Initialize tool registry from BuiltinToolCatalog
      _initializeToolRegistry();

      // Create API clients with hostCall mechanism
      _createApiClients();

      // Create ToolContext with API clients
      _toolContext = ToolContext(
        notepadApi: _notepadApiClient,
        memoryApi: _memoryApiClient,
        callApi: _callApiClient,
        textAgentApi: _textAgentApiClient,
      );

      _log('Handshake complete: initialized ${_toolDefinitions.length} tools');
    } catch (e) {
      _log('ERROR in handshake: $e');
    }
  }

  /// Initialize tool registry from BuiltinToolCatalog
  void _initializeToolRegistry() {
    _log('Initializing tool registry');

    _toolDefinitions.clear();

    try {
      final definitions = BuiltinToolCatalog.listDefinitions();

      for (final definition in definitions) {
        _toolDefinitions[definition.toolKey] = definition.toRealtimeJson();
        _log('Registered tool: ${definition.toolKey}');
      }

      _log('Tool registry initialized with ${_toolDefinitions.length} tools');
    } catch (e) {
      _log('ERROR initializing tool registry: $e');
      rethrow;
    }
  }

  /// Create API clients with hostCall callback
  void _createApiClients() {
    _log('Creating API clients');

    // Create NotepadApiClient with hostCall callback
    _notepadApiClient = NotepadApiClient(hostCall: (method, args) async {
      final ret = await _makeHostCall('notepad', method, args);
      final decodedRet = JsonEncoder().convert(ret);
      _log('NotepadApiClient hostCall returned: $decodedRet');
      return ret;
    });
    _log('Created NotepadApiClient');

    // Create MemoryApiClient with hostCall callback
    _memoryApiClient = MemoryApiClient(
      hostCall: (method, args) => _makeHostCall('memory', method, args),
    );
    _log('Created MemoryApiClient');

    // Create CallApiClient with hostCall callback
    _callApiClient = CallApiClient(
      hostCall: (method, args) => _makeHostCall('call', method, args),
    );
    _log('Created CallApiClient');

    // Create TextAgentApiClient with hostCall callback
    _textAgentApiClient = TextAgentApiClient(
      hostCall: (method, args) => _makeHostCall('textAgent', method, args),
    );
    _log('Created TextAgentApiClient');
  }

  /// Make a hostCall request to the host
  ///
  /// Sends a hostCall message and waits for the response with timeout.
  Future<Map<String, dynamic>> _makeHostCall(
    String api,
    String method,
    Map<String, dynamic> args,
  ) async {
    if (_hostReceivePort == null) {
      throw StateError('Host ReceivePort not initialized');
    }

    try {
      final requestId = generateMessageId();

      // Create a ReceivePort for the response
      final replyReceivePort = platform.PlatformReceivePort();

      // Create and send hostCall message
      final message = hostCallMessage(
        api,
        method,
        args,
        id: requestId,
        replyTo: replyReceivePort.sendPort as ReplyToPort,
      );

      final (valid, error) = validateMessageEnvelope(message);
      if (!valid) {
        throw StateError('Invalid hostCall message: $error');
      }

      // Create a copy of message without replyTo for logging (replyTo is not JSON-serializable on Web)
      final messageForLog = Map<String, dynamic>.from(message)
        ..remove('replyTo');
      _log(
          'Sending hostCall: api=$api, method=$method, requestId=$requestId, message=${jsonEncode(messageForLog)}');

      // Register pending request
      final completer = Completer<Map<String, dynamic>>();
      _pendingHostCalls[requestId] = completer;

      try {
        // Send request to host
        (_hostReceivePort! as dynamic).send(message);

        // Wait for response with timeout
        final completer = Completer<Object?>();
        late StreamSubscription<Object?> subscription;

        subscription = replyReceivePort.listen((msg) {
          if (!completer.isCompleted) {
            completer.complete(msg);
            subscription.cancel();
          }
        });

        final response = await completer.future.timeout(
          _hostCallTimeout,
          onTimeout: () {
            subscription.cancel();
            _pendingHostCalls.remove(requestId);
            throw TimeoutException(
              'hostCall timeout: $api.$method did not respond within $_hostCallTimeout',
            );
          },
        );

        _log('Received hostCall response for $requestId, response: $response');

        if (response is Map<String, dynamic>) {
          return response;
        } else {
          throw StateError('Invalid response type: ${response.runtimeType}');
        }
      } finally {
        _pendingHostCalls.remove(requestId);
        replyReceivePort.close();
      }
    } catch (e) {
      _log(
          '[TOOL:GUEST] Failed to call $api.$method: Error: $e, payload: ${jsonEncode(args)}');
      rethrow;
    }
  }

  /// Handle execute message
  ///
  /// Executes the specified tool and returns the result.
  Future<void> _handleExecute(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing payload',
        );
        return;
      }

      final toolKey = payload['toolKey'] as String?;
      final args = payload['args'] as Map<String, dynamic>? ?? {};

      if (toolKey == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing toolKey',
        );
        return;
      }

      _log('Executing tool: $toolKey');

      try {
        // Create tool instance
        final tool = BuiltinToolCatalog.createTool(toolKey, _toolContext);

        // Initialize tool
        await tool.init();
        _log('Tool initialized: $toolKey');

        // Execute tool
        final result = await tool.execute(args, _toolContext);
        _log('Tool execution completed: $toolKey');

        // Send success response
        _sendResponse(
          requestId,
          status: 'success',
          data: {
            'result': result,
          },
        );
      } on UnknownToolException catch (e) {
        _log('[TOOL:GUEST] Unknown tool: $toolKey');
        _log('Error: $e');
        _log('Request Payload: ${jsonEncode(args)}');
        _sendResponse(
          requestId,
          status: 'error',
          error: e.toString(),
          code: 'UNKNOWN_TOOL',
        );
      } catch (e, stackTrace) {
        _log('[TOOL:GUEST] Failed to execute tool: $toolKey');
        _log('Error: $e');
        _log('Request Payload: ${jsonEncode(args)}');
        _log('Stack trace: $stackTrace');
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Tool execution error: $e',
        );
      }
    } catch (e, stackTrace) {
      _log('[TOOL:GUEST] ERROR in execute handler: $e');
      _log('Stack trace: $stackTrace');
      _sendResponse(
        requestId,
        status: 'error',
        error: 'Internal error: $e',
      );
    }
  }

  /// Handle listSessionDefinitions message
  ///
  /// Returns the current tool definitions.
  Future<void> _handleListSessionDefinitions(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      _log('Listing session definitions: ${_toolDefinitions.length} tools');

      final tools = _toolDefinitions.values.toList();

      _sendResponse(
        requestId,
        status: 'success',
        data: {
          'tools': tools,
        },
      );
    } catch (e, stackTrace) {
      _log('ERROR in listSessionDefinitions: $e');
      _log('Stack trace: $stackTrace');
      _sendResponse(
        requestId,
        status: 'error',
        error: 'Error listing definitions: $e',
      );
    }
  }

  /// Handle registerTool message (stub for future MCP integration)
  ///
  /// Adds a tool to the registry and emits toolsChanged event.
  Future<void> _handleRegisterTool(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      _log('Handling registerTool (stub)');

      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing payload',
        );
        return;
      }

      final toolDefinition = payload['toolDefinition'] as Map<String, dynamic>?;
      if (toolDefinition == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing toolDefinition',
        );
        return;
      }

      final toolKey = toolDefinition['toolKey'] as String?;
      if (toolKey == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'toolDefinition missing toolKey',
        );
        return;
      }

      // Register the tool
      _toolDefinitions[toolKey] = toolDefinition;
      _log('Registered tool: $toolKey');

      // Emit toolsChanged event
      _emitToolsChanged(
        _toolDefinitions.values.toList(),
        'added',
      );

      _sendResponse(
        requestId,
        status: 'success',
        data: {},
      );
    } catch (e, stackTrace) {
      _log('ERROR in registerTool: $e');
      _log('Stack trace: $stackTrace');
      _sendResponse(
        requestId,
        status: 'error',
        error: 'Error registering tool: $e',
      );
    }
  }

  /// Handle unregisterTool message (stub for future MCP integration)
  ///
  /// Removes a tool from the registry and emits toolsChanged event.
  Future<void> _handleUnregisterTool(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    try {
      _log('Handling unregisterTool (stub)');

      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing payload',
        );
        return;
      }

      final toolKey = payload['toolKey'] as String?;
      if (toolKey == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing toolKey',
        );
        return;
      }

      // Unregister the tool
      if (_toolDefinitions.containsKey(toolKey)) {
        _toolDefinitions.remove(toolKey);
        _log('Unregistered tool: $toolKey');

        // Emit toolsChanged event
        _emitToolsChanged(
          _toolDefinitions.values.toList(),
          'removed',
        );
      } else {
        _log('WARNING: Tool not found for removal: $toolKey');
      }

      _sendResponse(
        requestId,
        status: 'success',
        data: {},
      );
    } catch (e, stackTrace) {
      _log('ERROR in unregisterTool: $e');
      _log('Stack trace: $stackTrace');
      _sendResponse(
        requestId,
        status: 'error',
        error: 'Error unregistering tool: $e',
      );
    }
  }

  /// Send a response message to the host
  void _sendResponse(
    String requestId, {
    required String status,
    String? error,
    String? code,
    Map<String, dynamic>? data,
  }) {
    try {
      if (_hostReceivePort == null) {
        _log('ERROR: Cannot send response - host ReceivePort not initialized');
        return;
      }

      final response = status == 'success'
          ? successResponse(requestId, data ?? {})
          : errorResponse(requestId, error ?? 'Unknown error', code: code);

      // Note: Response messages have a different structure than request messages
      // (they have 'data'/'error' instead of 'payload'), so we don't validate them
      // with validateMessageEnvelope()

      (_hostReceivePort! as dynamic).send(response);
      _log('Sent response for request $requestId: status=$status');
    } catch (e) {
      _log('ERROR sending response: $e');
    }
  }

  /// Emit a toolsChanged event to the host
  void _emitToolsChanged(
    List<Map<String, dynamic>> tools,
    String reason,
  ) {
    try {
      if (_hostReceivePort == null) {
        _log(
            'ERROR: Cannot send toolsChanged - host ReceivePort not initialized');
        return;
      }

      final event = toolsChangedMessage(tools, reason);

      final (valid, error) = validateMessageEnvelope(event);
      if (!valid) {
        _log('ERROR: Invalid toolsChanged message: $error');
        return;
      }

      _hostReceivePort!.send(event);
      _log(
          'Sent toolsChanged event: reason=$reason, toolCount=${tools.length}');
    } catch (e) {
      _log('ERROR sending toolsChanged event: $e');
    }
  }
}

/// Log a message from the worker isolate
void _log(String message) {
  print('[$_tag] $message');
}

/// Stub NotepadService implementation for use in isolate workers.
///
/// This provides a NotepadService interface that tools expect, while actual
/// operations are delegated to the host via hostCall in the NotepadApiClient.
/// This is temporary and will be replaced when ToolContext uses API clients directly.
class _StubNotepadService implements NotepadService {
  // ignore: unused_field - Will be used in next refactoring when ToolContext uses API clients
  final NotepadApiClient _apiClient;
  final StreamController<List<NotepadTab>> _tabsController =
      StreamController.broadcast();
  final StreamController<String?> _selectedTabController =
      StreamController.broadcast();

  _StubNotepadService(this._apiClient);

  @override
  Stream<List<NotepadTab>> get tabsStream => _tabsController.stream;

  @override
  Stream<String?> get selectedTabStream => _selectedTabController.stream;

  @override
  List<NotepadTab> get tabs => []; // Stub: no local state

  @override
  String? get selectedTabId => null; // Stub: no selection tracking

  @override
  List<Map<String, dynamic>> listTabs() {
    // Note: This is synchronous, but the API is async.
    // In practice, tools should call this inside async functions.
    // Return empty for now - actual data comes from API in async context.
    return [];
  }

  @override
  NotepadTab? getTab(String tabId) {
    // Stub: synchronous interface doesn't support async API calls
    return null;
  }

  @override
  String? getTabContent(String tabId) {
    return null;
  }

  @override
  Map<String, dynamic>? getTabMetadata(String tabId) {
    return null;
  }

  @override
  String createTab({
    required String content,
    required String mimeType,
    String? title,
  }) {
    // This would need to be async to work with hostCall
    throw UnimplementedError('createTab() requires async context. '
        'Call notepadApi.createTab() directly instead.');
  }

  @override
  bool updateTab(String tabId,
      {String? content, String? title, String? mimeType}) {
    throw UnimplementedError('updateTab() requires async context. '
        'Call notepadApi.updateTab() directly instead.');
  }

  @override
  bool closeTab(String tabId) {
    throw UnimplementedError('closeTab() requires async context. '
        'Call notepadApi.closeTab() directly instead.');
  }

  @override
  void selectTab(String? tabId) {
    // Stub: no-op
  }

  @override
  bool undo(String tabId) {
    return false;
  }

  @override
  bool redo(String tabId) {
    return false;
  }

  @override
  void clearTabs() {
    // Stub: no-op
  }

  @override
  void dispose() {
    _tabsController.close();
    _selectedTabController.close();
  }
}
