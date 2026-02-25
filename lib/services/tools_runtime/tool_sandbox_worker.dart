import 'dart:async';
import 'dart:convert';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/apis/tool_storage_api.dart';
import 'package:vagina/tools/tools.dart';

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
  final Map<String, Tool> _toolMap = {};

  // Per-session ToolContext (created during initialization)
  //
  // Note: tools are initialized with their own ToolContext instances in
  // _initializeToolRegistry(). We don't keep a separate session context here.

  // Late API clients (created during handshake)
  late NotepadApiClient _notepadApiClient;
  late CallApiClient _callApiClient;
  late TextAgentApiClient _textAgentApiClient;
  late ToolStorageApiClient _toolStorageApiClient;

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

        case MessageType.setToolEnabled:
          await _handleSetToolEnabled(id, message);
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

      // Extract toolsData for API client initialization
      final toolsData = payload['toolsData'] as Map<String, dynamic>?;
      
      // Create and initialize API clients
      _createApiClients(toolsData);

      _initializeToolRegistry();

      _log('Handshake complete: initialized ${_toolMap.length} tools');
    } catch (e) {
      _log('ERROR in handshake: $e');
    }
  }

  /// Initialize tool registry from BuiltinToolCatalog
  ///
  /// Each tool gets its own ToolContext with its toolKey for isolated storage
  void _initializeToolRegistry() {
    for (var tool in toolbox.tools) {
      _log('Registering tool: ${tool.definition.toolKey}');

      // Create a per-tool context with the tool's key for storage isolation
      final toolContext = ToolContext(
        toolKey: tool.definition.toolKey,
        notepadApi: _notepadApiClient,
        callApi: _callApiClient,
        textAgentApi: _textAgentApiClient,
        toolStorageApi: _toolStorageApiClient,
      );

      tool.init(toolContext); // boot up tool with its own context

      _toolMap[tool.definition.toolKey] = tool;
    }
    
    // Update TextAgentApiClient with tool calling support
    _updateTextAgentToolSupport();
  }

  /// Create and initialize API clients
  ///
  /// Each API client is responsible for its own initialization from toolsData
  void _createApiClients(Map<String, dynamic>? toolsData) {
    _log('Creating API clients');

    // Create NotepadApiClient with hostCall callback
    _notepadApiClient = NotepadApiClient(
      hostCall: (method, args) async =>
          await _makeHostCall('notepad', method, args),
    );
    _log('Created NotepadApiClient');

    // Create CallApiClient with hostCall callback
    _callApiClient = CallApiClient(
      hostCall: (method, args) async =>
          await _makeHostCall('call', method, args),
    );
    _log('Created CallApiClient');

    // Create TextAgentApiClient with tool calling support
    // Note: Tools list will be updated after tool registry initialization
    _textAgentApiClient = TextAgentApiClient(
      initialData: toolsData?['text_agents'],
      executeToolCallback: _executeToolInternal,
      availableTools: [], // Will be populated after _initializeToolRegistry
    );
    _log('Created TextAgentApiClient');

    // Create ToolStorageApiClient with hostCall callback
    _toolStorageApiClient = ToolStorageApiClient(
      hostCall: (method, args) async =>
          await _makeHostCall('toolStorage', method, args),
    );
    _log('Created ToolStorageApiClient');
    
    // Future: Other API clients can initialize themselves here
    // if (toolsData?['database'] != null) {
    //   _databaseApiClient.initialize(toolsData['database']);
    // }
  }

  /// Make a hostCall request to the host
  ///
  /// Sends a hostCall message and waits for the response with timeout.
  ///
  /// This method also unwraps the hostCall response envelope:
  /// - On success: returns the raw `data` payload
  /// - On error: throws a [HostCallException]
  Future<dynamic> _makeHostCall(
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
        replyTo: replyReceivePort.sendPort,
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

      try {
        // Send request to host
        _hostReceivePort!.send(message);

        // Wait for response with timeout
        final responseCompleter = Completer<Object?>();
        late StreamSubscription<Object?> subscription;

        subscription = replyReceivePort.listen((msg) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(msg);
            subscription.cancel();
          }
        });

        final response = await responseCompleter.future.timeout(
          _hostCallTimeout,
          onTimeout: () {
            subscription.cancel();
            throw TimeoutException(
              'hostCall timeout: $api.$method did not respond within $_hostCallTimeout',
            );
          },
        );

        _log('Received hostCall response for $requestId, response: $response');

        if (response is! Map) {
          throw StateError('Invalid response type: ${response.runtimeType}');
        }

        final responseMap = Map<String, dynamic>.from(response);

        final type = responseMap['type'];
        final respRequestId = responseMap['requestId'];
        final status = responseMap['status'];

        if (type != 'response' || respRequestId != requestId) {
          throw StateError(
            'Invalid response envelope: type=$type requestId=$respRequestId expectedRequestId=$requestId',
          );
        }

        if (status == 'success') {
          return responseMap['data'];
        }

        if (status == 'error') {
          final message = responseMap['error']?.toString() ?? 'Unknown error';
          final code = responseMap['code'];
          throw HostCallException(
            api: api,
            method: method,
            message: message,
            code: code is String ? code : null,
          );
        }

        throw StateError('Invalid response status: $status');
      } finally {
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
        // Execute tool using internal method
        final result = await _executeToolInternal(toolKey, args);
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
      _log('Listing session definitions: ${_toolMap.length} tools');

      final tools = _toolMap.values.map((t) => t.toWireJson()).toList();

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

  /// Handle setToolEnabled message.
  ///
  /// Enables/disables a tool by key and emits a toolsChanged event.
  Future<void> _handleSetToolEnabled(
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
      final enabled = payload['enabled'] as bool?;
      if (toolKey == null || enabled == null) {
        _sendResponse(
          requestId,
          status: 'error',
          error: 'Missing toolKey or enabled',
        );
        return;
      }

      if (enabled) {
        // Re-register tool instance from builtins.
        final tool = toolbox.tools
            .where((t) => t.definition.toolKey == toolKey)
            .cast<Tool?>()
            .firstWhere((t) => t != null, orElse: () => null);

        if (tool == null) {
          _sendResponse(
            requestId,
            status: 'error',
            error: 'Tool not found: $toolKey',
            code: 'TOOL_NOT_FOUND',
          );
          return;
        }

        // Ensure context is initialized.
        final toolContext = ToolContext(
          toolKey: tool.definition.toolKey,
          notepadApi: _notepadApiClient,
          callApi: _callApiClient,
          textAgentApi: _textAgentApiClient,
          toolStorageApi: _toolStorageApiClient,
        );
        await tool.init(toolContext);

        _toolMap[toolKey] = tool;
      } else {
        _toolMap.remove(toolKey);
      }

      _emitToolsChanged(
        _toolMap.values.map((t) => t.toWireJson()).toList(),
        'updated',
      );

      _sendResponse(
        requestId,
        status: 'success',
        data: {},
      );
    } catch (e, stackTrace) {
      _log('ERROR in setToolEnabled: $e');
      _log('Stack trace: $stackTrace');
      _sendResponse(
        requestId,
        status: 'error',
        error: 'Error setToolEnabled: $e',
      );
    }
  }

  /// Handle registerTool message (stub for future MCP integration)
  Future<void> _handleRegisterTool(
    String requestId,
    Map<String, dynamic> message,
  ) async {
    _log('registerTool is not supported yet (stub)');
    _sendResponse(
      requestId,
      status: 'error',
      error: 'registerTool is not supported yet',
      code: 'NOT_IMPLEMENTED',
    );
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
      if (_toolMap.containsKey(toolKey)) {
        _toolMap.remove(toolKey);
        _log('Unregistered tool: $toolKey');

        // Emit toolsChanged event
        _emitToolsChanged(
          _toolMap.values.map((t) => t.toWireJson()).toList(),
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

  /// Execute a tool internally within the Worker Isolate
  ///
  /// This method allows tools to call other tools directly without
  /// crossing Isolate boundaries. Used by TextAgentApiClient for tool calling.
  Future<String> _executeToolInternal(
    String toolKey,
    Map<String, dynamic> args,
  ) async {
    _log('Internal tool execution: $toolKey');
    
    final tool = _toolMap[toolKey];
    if (tool == null) {
      throw UnknownToolException('Tool not found: $toolKey');
    }
    
    // Execute tool and return result
    return await tool.execute(args);
  }
  
  /// Update TextAgentApiClient with available tools after registry initialization
  void _updateTextAgentToolSupport() {
    _log('Updating TextAgentApiClient with tool definitions');
    
    // Build Chat Completions API compatible tool list
    final availableTools = _toolMap.values.map((tool) {
      return {
        'type': 'function',
        'function': {
          'name': tool.definition.toolKey,
          'description': tool.definition.description,
          'parameters': tool.definition.parametersSchema,
        },
      };
    }).toList();
    
    // Update client with tools
    _textAgentApiClient.updateTools(availableTools);
    
    _log('Updated ${availableTools.length} tools for TextAgentApiClient');
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

class HostCallException implements Exception {
  final String api;
  final String method;
  final String message;
  final String? code;

  HostCallException({
    required this.api,
    required this.method,
    required this.message,
    this.code,
  });

  @override
  String toString() {
    final codePart = code == null ? '' : ' (code=$code)';
    return 'HostCallException: $api.$method: $message$codePart';
  }
}

class UnknownToolException implements Exception {
  final String message;

  UnknownToolException(this.message);

  @override
  String toString() => 'UnknownToolException: $message';
}
