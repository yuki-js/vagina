import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../config/app_config.dart';
import '../models/realtime_events.dart';
import '../models/realtime_session_config.dart';
import '../models/conversation_models.dart';
import 'websocket_service.dart';
import 'log_service.dart';

/// Client for the Azure OpenAI Realtime API
/// 
/// This client handles all 34 server events defined in the OpenAI Realtime API:
/// - Session events (2): session.created, session.updated
/// - Conversation events (8): conversation.created, conversation.item.*
/// - Input audio buffer events (4): input_audio_buffer.*
/// - Output audio buffer events (3): output_audio_buffer.*
/// - Response events (14): response.*
/// - Other events (3): error, rate_limits.updated, transcription_session.updated
class RealtimeApiClient {
  static const _tag = 'RealtimeAPI';
  
  /// Log audio chunks sent every N chunks to avoid log explosion
  static const int _logAudioChunkInterval = 50;
  
  final WebSocketService _webSocket = WebSocketService();
  
  // === Stream Controllers ===
  
  // Audio streams
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  
  // Transcript streams
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _userTranscriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _userTranscriptDeltaController =
      StreamController<String>.broadcast();
  
  // Error stream
  final StreamController<RealtimeError> _errorController =
      StreamController<RealtimeError>.broadcast();
  
  // Response lifecycle streams
  final StreamController<Response> _responseCreatedController =
      StreamController<Response>.broadcast();
  final StreamController<Response> _responseDoneController =
      StreamController<Response>.broadcast();
  final StreamController<void> _audioDoneController =
      StreamController<void>.broadcast();
  final StreamController<void> _transcriptDoneController =
      StreamController<void>.broadcast();
  
  // Function call stream
  final StreamController<FunctionCall> _functionCallController =
      StreamController<FunctionCall>.broadcast();
  
  // VAD (Voice Activity Detection) streams
  final StreamController<void> _speechStartedController =
      StreamController<void>.broadcast();
  final StreamController<void> _speechStoppedController =
      StreamController<void>.broadcast();
  
  // Conversation item streams
  final StreamController<ConversationItem> _itemCreatedController =
      StreamController<ConversationItem>.broadcast();
  final StreamController<ConversationItem> _itemDeletedController =
      StreamController<ConversationItem>.broadcast();
  
  // Output item streams (for tracking response structure)
  final StreamController<ResponseOutputItem> _outputItemAddedController =
      StreamController<ResponseOutputItem>.broadcast();
  final StreamController<ResponseOutputItem> _outputItemDoneController =
      StreamController<ResponseOutputItem>.broadcast();
  
  // Content part streams
  final StreamController<ContentPart> _contentPartAddedController =
      StreamController<ContentPart>.broadcast();
  final StreamController<ContentPart> _contentPartDoneController =
      StreamController<ContentPart>.broadcast();
  
  // Text streams (for text modality responses)
  final StreamController<String> _textDeltaController =
      StreamController<String>.broadcast();
  final StreamController<String> _textDoneController =
      StreamController<String>.broadcast();
  
  // Rate limits stream
  final StreamController<List<RateLimit>> _rateLimitsController =
      StreamController<List<RateLimit>>.broadcast();
  
  // Session streams
  final StreamController<void> _sessionCreatedController =
      StreamController<void>.broadcast();
  final StreamController<void> _sessionUpdatedController =
      StreamController<void>.broadcast();
  
  // Output audio buffer streams
  final StreamController<void> _outputAudioStartedController =
      StreamController<void>.broadcast();
  final StreamController<void> _outputAudioStoppedController =
      StreamController<void>.broadcast();

  StreamSubscription? _messageSubscription;
  String? _lastError;
  int _audioChunksReceived = 0;
  int _audioChunksSent = 0;
  
  /// Tools to be registered with the session
  List<Map<String, dynamic>> _tools = [];
  
  /// Accumulated function call arguments (function calls come in deltas)
  final Map<String, StringBuffer> _pendingFunctionCalls = {};
  final Map<String, String> _pendingFunctionNames = {};
  
  /// Current response being built
  String? _currentResponseId;
  
  /// Current output item being built
  String? _currentOutputItemId;

  // === Public Getters ===
  
  bool get isConnected => _webSocket.isConnected;
  
  // Audio streams
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<void> get audioDoneStream => _audioDoneController.stream;
  
  // Transcript streams
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<void> get transcriptDoneStream => _transcriptDoneController.stream;
  Stream<String> get userTranscriptStream => _userTranscriptController.stream;
  Stream<String> get userTranscriptDeltaStream => _userTranscriptDeltaController.stream;
  
  // Error stream
  Stream<RealtimeError> get errorStream => _errorController.stream;
  
  // Response lifecycle streams
  Stream<Response> get responseCreatedStream => _responseCreatedController.stream;
  Stream<Response> get responseDoneStream => _responseDoneController.stream;
  
  // Function call stream
  Stream<FunctionCall> get functionCallStream => _functionCallController.stream;
  
  // VAD streams
  Stream<void> get speechStartedStream => _speechStartedController.stream;
  Stream<void> get speechStoppedStream => _speechStoppedController.stream;
  
  // Conversation item streams
  Stream<ConversationItem> get itemCreatedStream => _itemCreatedController.stream;
  Stream<ConversationItem> get itemDeletedStream => _itemDeletedController.stream;
  
  // Output item streams
  Stream<ResponseOutputItem> get outputItemAddedStream => _outputItemAddedController.stream;
  Stream<ResponseOutputItem> get outputItemDoneStream => _outputItemDoneController.stream;
  
  // Content part streams
  Stream<ContentPart> get contentPartAddedStream => _contentPartAddedController.stream;
  Stream<ContentPart> get contentPartDoneStream => _contentPartDoneController.stream;
  
  // Text streams
  Stream<String> get textDeltaStream => _textDeltaController.stream;
  Stream<String> get textDoneStream => _textDoneController.stream;
  
  // Rate limits stream
  Stream<List<RateLimit>> get rateLimitsStream => _rateLimitsController.stream;
  
  // Session streams
  Stream<void> get sessionCreatedStream => _sessionCreatedController.stream;
  Stream<void> get sessionUpdatedStream => _sessionUpdatedController.stream;
  
  // Output audio buffer streams
  Stream<void> get outputAudioStartedStream => _outputAudioStartedController.stream;
  Stream<void> get outputAudioStoppedStream => _outputAudioStoppedController.stream;
  
  String? get lastError => _lastError;

  /// Set tools to be registered with the session
  void setTools(List<Map<String, dynamic>> tools) {
    _tools = tools;
  }

  /// Connect to Azure OpenAI using a full Realtime URL and API key
  /// URL format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
  Future<void> connect(String realtimeUrl, String apiKey) async {
    logService.info(_tag, 'Connecting to Azure OpenAI Realtime API');
    _audioChunksReceived = 0;
    _audioChunksSent = 0;
    _pendingFunctionCalls.clear();
    _pendingFunctionNames.clear();
    _currentResponseId = null;
    _currentOutputItemId = null;
    
    try {
      if (realtimeUrl.isEmpty) {
        throw Exception('Realtime URL is required');
      }
      if (apiKey.isEmpty) {
        throw Exception('API key is required');
      }

      // Convert https:// to wss:// for WebSocket connection
      var wsUrl = realtimeUrl;
      if (wsUrl.startsWith('https://')) {
        wsUrl = wsUrl.replaceFirst('https://', 'wss://');
      }

      // Add api-key to query parameters
      final uri = Uri.parse(wsUrl);
      final authenticatedUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'api-key': apiKey,
        },
      );
      
      await _webSocket.connect(authenticatedUri.toString());

      _messageSubscription = _webSocket.messages.listen(
        _handleMessage,
        onError: (error) {
          logService.error(_tag, 'WebSocket error: $error');
          _lastError = error.toString();
          _errorController.add(RealtimeError(
            type: 'websocket_error',
            message: error.toString(),
          ));
        },
      );

      // Session will be configured when session.created event is received
      _lastError = null;
      logService.info(_tag, 'Connected, waiting for session.created event');
    } catch (e) {
      logService.error(_tag, 'Connection failed: $e');
      _lastError = e.toString();
      _errorController.add(RealtimeError(
        type: 'connection_error',
        message: e.toString(),
      ));
      rethrow;
    }
  }

  /// Session configuration
  RealtimeSessionConfig _sessionConfig = const RealtimeSessionConfig();
  
  /// Set noise reduction type ('far' or 'near')
  void setNoiseReduction(String type) {
    if (type == 'far' || type == 'near') {
      _sessionConfig = _sessionConfig.copyWith(noiseReduction: type);
    }
  }
  
  /// Get current noise reduction type
  String get noiseReduction => _sessionConfig.noiseReduction;

  Future<void> _configureSession() async {
    // Update session config with current tools
    _sessionConfig = _sessionConfig.copyWith(
      voice: AppConfig.defaultVoice,
      tools: _tools,
    );
    
    logService.info(_tag, 'Configuring session with voice: ${_sessionConfig.voice}, tools: ${_sessionConfig.tools.length}, noise_reduction: ${_sessionConfig.noiseReduction}');
    
    // Send session update with configuration
    _webSocket.send({
      'type': ClientEventType.sessionUpdate.value,
      'session': _sessionConfig.toSessionPayload(),
    });
  }
  
  /// Update session configuration (can be called after connection)
  void updateSessionConfig() {
    if (!isConnected) return;
    _configureSession();
  }

  /// Handle incoming WebSocket messages
  /// 
  /// This method processes all 34 server event types defined in the OpenAI Realtime API.
  void _handleMessage(Map<String, dynamic> message) {
    final typeStr = message['type'] as String?;
    if (typeStr == null) {
      logService.warn(_tag, 'Received message without type: $message');
      return;
    }
    
    final eventType = ServerEventType.fromString(typeStr);
    final eventId = message['event_id'] as String?;

    switch (eventType) {
      // === Session Events ===
      
      case ServerEventType.sessionCreated:
        _handleSessionCreated(message);
        break;
        
      case ServerEventType.sessionUpdated:
        _handleSessionUpdated(message);
        break;
      
      // === Conversation Events ===
      
      case ServerEventType.conversationCreated:
        _handleConversationCreated(message);
        break;
        
      case ServerEventType.conversationItemCreated:
        _handleConversationItemCreated(message);
        break;
        
      case ServerEventType.conversationItemRetrieved:
        _handleConversationItemRetrieved(message);
        break;
        
      case ServerEventType.conversationItemTruncated:
        _handleConversationItemTruncated(message);
        break;
        
      case ServerEventType.conversationItemDeleted:
        _handleConversationItemDeleted(message);
        break;
        
      case ServerEventType.conversationItemInputAudioTranscriptionCompleted:
        _handleInputAudioTranscriptionCompleted(message);
        break;
        
      case ServerEventType.conversationItemInputAudioTranscriptionDelta:
        _handleInputAudioTranscriptionDelta(message);
        break;
        
      case ServerEventType.conversationItemInputAudioTranscriptionFailed:
        _handleInputAudioTranscriptionFailed(message);
        break;
      
      // === Input Audio Buffer Events ===
      
      case ServerEventType.inputAudioBufferCommitted:
        _handleInputAudioBufferCommitted(message);
        break;
        
      case ServerEventType.inputAudioBufferCleared:
        _handleInputAudioBufferCleared(message);
        break;
        
      case ServerEventType.inputAudioBufferSpeechStarted:
        _handleSpeechStarted(message);
        break;
        
      case ServerEventType.inputAudioBufferSpeechStopped:
        _handleSpeechStopped(message);
        break;
      
      // === Output Audio Buffer Events ===
      
      case ServerEventType.outputAudioBufferStarted:
        _handleOutputAudioBufferStarted(message);
        break;
        
      case ServerEventType.outputAudioBufferStopped:
        _handleOutputAudioBufferStopped(message);
        break;
        
      case ServerEventType.outputAudioBufferCleared:
        _handleOutputAudioBufferCleared(message);
        break;
      
      // === Response Events ===
      
      case ServerEventType.responseCreated:
        _handleResponseCreated(message);
        break;
        
      case ServerEventType.responseDone:
        _handleResponseDone(message);
        break;
        
      case ServerEventType.responseOutputItemAdded:
        _handleResponseOutputItemAdded(message);
        break;
        
      case ServerEventType.responseOutputItemDone:
        _handleResponseOutputItemDone(message);
        break;
        
      case ServerEventType.responseContentPartAdded:
        _handleResponseContentPartAdded(message);
        break;
        
      case ServerEventType.responseContentPartDone:
        _handleResponseContentPartDone(message);
        break;
        
      case ServerEventType.responseTextDelta:
        _handleResponseTextDelta(message);
        break;
        
      case ServerEventType.responseTextDone:
        _handleResponseTextDone(message);
        break;
        
      case ServerEventType.responseAudioDelta:
        _handleResponseAudioDelta(message);
        break;
        
      case ServerEventType.responseAudioDone:
        _handleResponseAudioDone(message);
        break;
        
      case ServerEventType.responseAudioTranscriptDelta:
        _handleResponseAudioTranscriptDelta(message);
        break;
        
      case ServerEventType.responseAudioTranscriptDone:
        _handleResponseAudioTranscriptDone(message);
        break;
        
      case ServerEventType.responseFunctionCallArgumentsDelta:
        _handleFunctionCallArgumentsDelta(message);
        break;
        
      case ServerEventType.responseFunctionCallArgumentsDone:
        _handleFunctionCallArgumentsDone(message);
        break;
      
      // === Other Events ===
      
      case ServerEventType.rateLimitsUpdated:
        _handleRateLimitsUpdated(message);
        break;
        
      case ServerEventType.transcriptionSessionUpdated:
        _handleTranscriptionSessionUpdated(message);
        break;
        
      case ServerEventType.error:
        _handleError(message);
        break;
        
      case null:
        logService.warn(_tag, 'Unknown event type: $typeStr (event_id: $eventId)');
        break;
    }
  }

  // === Session Event Handlers ===
  
  void _handleSessionCreated(Map<String, dynamic> message) {
    logService.info(_tag, 'Session created, sending session.update');
    _sessionCreatedController.add(null);
    _configureSession();
  }
  
  void _handleSessionUpdated(Map<String, dynamic> message) {
    final session = message['session'] as Map<String, dynamic>?;
    if (session != null) {
      final turnDetection = session['turn_detection'] as Map<String, dynamic>?;
      final transcription = session['input_audio_transcription'] as Map<String, dynamic>?;
      final tools = session['tools'] as List?;
      logService.info(_tag, 'Session updated - turn_detection: ${turnDetection?['type']}, transcription: ${transcription?['model']}, tools: ${tools?.length ?? 0}');
    } else {
      logService.info(_tag, 'Session updated');
    }
    _sessionUpdatedController.add(null);
  }

  // === Conversation Event Handlers ===
  
  void _handleConversationCreated(Map<String, dynamic> message) {
    final conversation = message['conversation'] as Map<String, dynamic>?;
    final conversationId = conversation?['id'] as String?;
    logService.info(_tag, 'Conversation created: $conversationId');
  }
  
  void _handleConversationItemCreated(Map<String, dynamic> message) {
    final itemData = message['item'] as Map<String, dynamic>?;
    if (itemData != null) {
      final item = ConversationItem.fromJson(itemData);
      logService.info(_tag, 'Conversation item created: ${item.id} (type: ${item.type.value}, role: ${item.role?.value})');
      _itemCreatedController.add(item);
    }
  }
  
  void _handleConversationItemRetrieved(Map<String, dynamic> message) {
    final itemData = message['item'] as Map<String, dynamic>?;
    if (itemData != null) {
      final item = ConversationItem.fromJson(itemData);
      logService.debug(_tag, 'Conversation item retrieved: ${item.id}');
    }
  }
  
  void _handleConversationItemTruncated(Map<String, dynamic> message) {
    final itemId = message['item_id'] as String?;
    final contentIndex = message['content_index'] as int?;
    final audioEndMs = message['audio_end_ms'] as int?;
    logService.info(_tag, 'Conversation item truncated: $itemId at content_index=$contentIndex, audio_end_ms=$audioEndMs');
  }
  
  void _handleConversationItemDeleted(Map<String, dynamic> message) {
    final itemId = message['item_id'] as String?;
    logService.info(_tag, 'Conversation item deleted: $itemId');
    if (itemId != null) {
      _itemDeletedController.add(ConversationItem(
        id: itemId,
        type: ItemType.message,
        status: ItemStatus.completed,
      ));
    }
  }
  
  void _handleInputAudioTranscriptionCompleted(Map<String, dynamic> message) {
    final transcript = message['transcript'] as String?;
    final itemId = message['item_id'] as String?;
    if (transcript != null && transcript.isNotEmpty) {
      logService.info(_tag, 'User transcript completed: $transcript (item: $itemId)');
      _userTranscriptController.add(transcript);
    } else {
      logService.warn(_tag, 'User transcript received but empty');
    }
  }
  
  void _handleInputAudioTranscriptionDelta(Map<String, dynamic> message) {
    final delta = message['delta'] as String?;
    final itemId = message['item_id'] as String?;
    if (delta != null) {
      logService.debug(_tag, 'User transcript delta: $delta (item: $itemId)');
      _userTranscriptDeltaController.add(delta);
    }
  }
  
  void _handleInputAudioTranscriptionFailed(Map<String, dynamic> message) {
    final error = message['error'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;
    logService.error(_tag, 'User transcription failed: ${error?['message'] ?? 'unknown error'} (item: $itemId)');
  }

  // === Input Audio Buffer Event Handlers ===
  
  void _handleInputAudioBufferCommitted(Map<String, dynamic> message) {
    final itemId = message['item_id'] as String?;
    logService.info(_tag, 'Audio buffer committed, item_id: $itemId');
  }
  
  void _handleInputAudioBufferCleared(Map<String, dynamic> message) {
    logService.info(_tag, 'Input audio buffer cleared');
  }
  
  void _handleSpeechStarted(Map<String, dynamic> message) {
    final audioStartMs = message['audio_start_ms'] as int?;
    final itemId = message['item_id'] as String?;
    logService.info(_tag, 'Speech started (VAD detected) at ${audioStartMs}ms, item: $itemId');
    _speechStartedController.add(null);
  }
  
  void _handleSpeechStopped(Map<String, dynamic> message) {
    final audioEndMs = message['audio_end_ms'] as int?;
    final itemId = message['item_id'] as String?;
    logService.info(_tag, 'Speech stopped (VAD detected) at ${audioEndMs}ms, item: $itemId');
    _speechStoppedController.add(null);
  }

  // === Output Audio Buffer Event Handlers ===
  
  void _handleOutputAudioBufferStarted(Map<String, dynamic> message) {
    final responseId = message['response_id'] as String?;
    logService.info(_tag, 'Output audio buffer started for response: $responseId');
    _outputAudioStartedController.add(null);
  }
  
  void _handleOutputAudioBufferStopped(Map<String, dynamic> message) {
    final responseId = message['response_id'] as String?;
    logService.info(_tag, 'Output audio buffer stopped for response: $responseId');
    _outputAudioStoppedController.add(null);
  }
  
  void _handleOutputAudioBufferCleared(Map<String, dynamic> message) {
    logService.info(_tag, 'Output audio buffer cleared');
  }

  // === Response Event Handlers ===
  
  void _handleResponseCreated(Map<String, dynamic> message) {
    final responseData = message['response'] as Map<String, dynamic>?;
    if (responseData != null) {
      final response = Response.fromJson(responseData);
      _currentResponseId = response.id;
      logService.info(_tag, 'Response created: ${response.id}');
      _audioChunksReceived = 0;
      _responseCreatedController.add(response);
    }
  }
  
  void _handleResponseDone(Map<String, dynamic> message) {
    final responseData = message['response'] as Map<String, dynamic>?;
    if (responseData != null) {
      final response = Response.fromJson(responseData);
      logService.info(_tag, 'Response done: ${response.id} (status: ${response.status.value})');
      _responseDoneController.add(response);
    }
    _currentResponseId = null;
    _currentOutputItemId = null;
  }
  
  void _handleResponseOutputItemAdded(Map<String, dynamic> message) {
    final itemData = message['item'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final outputIndex = message['output_index'] as int?;
    
    if (itemData != null) {
      final item = ResponseOutputItem.fromJson(itemData);
      _currentOutputItemId = item.id;
      
      // Check if this is a function call
      if (item.type == ItemType.functionCall) {
        final callId = item.callId ?? '';
        final name = item.name ?? '';
        _pendingFunctionCalls[callId] = StringBuffer();
        _pendingFunctionNames[callId] = name;
        logService.info(_tag, 'Function call started: $name (call_id: $callId) at output_index: $outputIndex');
      } else {
        logService.info(_tag, 'Output item added: ${item.id} (type: ${item.type.value}) at output_index: $outputIndex');
      }
      
      _outputItemAddedController.add(item);
    }
  }
  
  void _handleResponseOutputItemDone(Map<String, dynamic> message) {
    final itemData = message['item'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final outputIndex = message['output_index'] as int?;
    
    if (itemData != null) {
      final item = ResponseOutputItem.fromJson(itemData);
      logService.info(_tag, 'Output item done: ${item.id} (type: ${item.type.value}, status: ${item.status.value}) at output_index: $outputIndex');
      _outputItemDoneController.add(item);
    }
  }
  
  void _handleResponseContentPartAdded(Map<String, dynamic> message) {
    final partData = message['part'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final itemId = message['item_id'] as String?;
    final outputIndex = message['output_index'] as int?;
    final contentIndex = message['content_index'] as int?;
    
    if (partData != null) {
      final part = ContentPart.fromJson(partData);
      logService.debug(_tag, 'Content part added: ${part.type.value} at content_index: $contentIndex');
      _contentPartAddedController.add(part);
    }
  }
  
  void _handleResponseContentPartDone(Map<String, dynamic> message) {
    final partData = message['part'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final itemId = message['item_id'] as String?;
    final outputIndex = message['output_index'] as int?;
    final contentIndex = message['content_index'] as int?;
    
    if (partData != null) {
      final part = ContentPart.fromJson(partData);
      logService.debug(_tag, 'Content part done: ${part.type.value} at content_index: $contentIndex');
      _contentPartDoneController.add(part);
    }
  }
  
  void _handleResponseTextDelta(Map<String, dynamic> message) {
    final delta = message['delta'] as String?;
    if (delta != null) {
      _textDeltaController.add(delta);
      // Also emit to transcript stream for compatibility
      _transcriptController.add(delta);
    }
  }
  
  void _handleResponseTextDone(Map<String, dynamic> message) {
    final text = message['text'] as String?;
    logService.info(_tag, 'Response text done');
    if (text != null) {
      _textDoneController.add(text);
    }
  }
  
  void _handleResponseAudioDelta(Map<String, dynamic> message) {
    final delta = message['delta'] as String?;
    if (delta != null) {
      _audioChunksReceived++;
      final audioData = base64Decode(delta);
      if (_audioChunksReceived % _logAudioChunkInterval == 0) {
        logService.debug(_tag, 'Audio delta received (chunk #$_audioChunksReceived, ${audioData.length} bytes)');
      }
      _audioController.add(Uint8List.fromList(audioData));
    }
  }
  
  void _handleResponseAudioDone(Map<String, dynamic> message) {
    logService.info(_tag, 'Audio response complete. Total chunks received: $_audioChunksReceived');
    _audioDoneController.add(null);
  }
  
  void _handleResponseAudioTranscriptDelta(Map<String, dynamic> message) {
    final delta = message['delta'] as String?;
    if (delta != null) {
      _transcriptController.add(delta);
    }
  }
  
  void _handleResponseAudioTranscriptDone(Map<String, dynamic> message) {
    final transcript = message['transcript'] as String?;
    logService.info(_tag, 'Audio transcript done');
    _transcriptDoneController.add(null);
  }
  
  void _handleFunctionCallArgumentsDelta(Map<String, dynamic> message) {
    final callId = message['call_id'] as String?;
    final delta = message['delta'] as String?;
    if (callId != null && delta != null) {
      _pendingFunctionCalls[callId]?.write(delta);
      logService.debug(_tag, 'Function call arguments delta: $delta');
    }
  }
  
  void _handleFunctionCallArgumentsDone(Map<String, dynamic> message) {
    final callId = message['call_id'] as String?;
    if (callId != null && _pendingFunctionCalls.containsKey(callId)) {
      final arguments = _pendingFunctionCalls[callId]!.toString();
      final name = _pendingFunctionNames[callId] ?? 'unknown';
      logService.info(_tag, 'Function call complete: $name with args: $arguments');
      
      _functionCallController.add(FunctionCall(
        callId: callId,
        name: name,
        arguments: arguments,
      ));
      
      // Cleanup
      _pendingFunctionCalls.remove(callId);
      _pendingFunctionNames.remove(callId);
    }
  }

  // === Other Event Handlers ===
  
  void _handleRateLimitsUpdated(Map<String, dynamic> message) {
    final rateLimitsData = message['rate_limits'] as List?;
    if (rateLimitsData != null) {
      final rateLimits = rateLimitsData
          .map((e) => RateLimit.fromJson(e as Map<String, dynamic>))
          .toList();
      logService.debug(_tag, 'Rate limits updated: ${rateLimits.map((r) => '${r.name}: ${r.remaining}/${r.limit}').join(', ')}');
      _rateLimitsController.add(rateLimits);
    }
  }
  
  void _handleTranscriptionSessionUpdated(Map<String, dynamic> message) {
    logService.info(_tag, 'Transcription session updated');
  }
  
  void _handleError(Map<String, dynamic> message) {
    final errorData = message['error'] as Map<String, dynamic>?;
    if (errorData != null) {
      final error = RealtimeError.fromJson(errorData);
      logService.error(_tag, 'API error: $error');
      _lastError = error.toString();
      _errorController.add(error);
    }
  }

  // === Client Methods ===

  /// Send audio data to the API
  void sendAudio(Uint8List audioData) {
    if (!isConnected) {
      logService.warn(_tag, 'Cannot send audio: not connected');
      _errorController.add(RealtimeError(
        type: 'client_error',
        message: 'Cannot send audio: not connected',
      ));
      return;
    }

    _audioChunksSent++;
    if (_audioChunksSent % _logAudioChunkInterval == 0) {
      logService.debug(_tag, 'Sent $_audioChunksSent audio chunks');
    }

    final base64Audio = base64Encode(audioData);
    _webSocket.send({
      'type': ClientEventType.inputAudioBufferAppend.value,
      'audio': base64Audio,
    });
  }

  /// Commit the current audio buffer
  void commitAudioBuffer() {
    if (!isConnected) {
      _errorController.add(RealtimeError(
        type: 'client_error',
        message: 'Cannot commit audio buffer: not connected',
      ));
      return;
    }

    _webSocket.send({
      'type': ClientEventType.inputAudioBufferCommit.value,
    });
  }

  /// Clear the input audio buffer
  void clearInputAudioBuffer() {
    if (!isConnected) return;

    _webSocket.send({
      'type': ClientEventType.inputAudioBufferClear.value,
    });
  }
  
  /// Clear the output audio buffer
  void clearOutputAudioBuffer() {
    if (!isConnected) return;

    _webSocket.send({
      'type': ClientEventType.outputAudioBufferClear.value,
    });
  }

  /// Send a text message
  void sendTextMessage(String text) {
    if (!isConnected) {
      _errorController.add(RealtimeError(
        type: 'client_error',
        message: 'Cannot send message: not connected',
      ));
      return;
    }

    logService.info(_tag, 'Sending text message: $text');

    _webSocket.send({
      'type': ClientEventType.conversationItemCreate.value,
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': text,
          }
        ],
      },
    });

    _webSocket.send({
      'type': ClientEventType.responseCreate.value,
    });
  }

  /// Send a function call result
  void sendFunctionCallResult(String callId, String output) {
    if (!isConnected) {
      _errorController.add(RealtimeError(
        type: 'client_error',
        message: 'Cannot send function result: not connected',
      ));
      return;
    }

    logService.info(_tag, 'Sending function call result for $callId');

    _webSocket.send({
      'type': ClientEventType.conversationItemCreate.value,
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': output,
      },
    });

    // Trigger response generation after sending the function result
    _webSocket.send({
      'type': ClientEventType.responseCreate.value,
    });
  }

  /// Cancel the current response
  void cancelResponse() {
    if (!isConnected) return;

    _webSocket.send({
      'type': ClientEventType.responseCancel.value,
    });
  }
  
  /// Delete a conversation item
  void deleteConversationItem(String itemId) {
    if (!isConnected) return;
    
    _webSocket.send({
      'type': ClientEventType.conversationItemDelete.value,
      'item_id': itemId,
    });
  }
  
  /// Truncate a conversation item
  void truncateConversationItem(String itemId, int contentIndex, int audioEndMs) {
    if (!isConnected) return;
    
    _webSocket.send({
      'type': ClientEventType.conversationItemTruncate.value,
      'item_id': itemId,
      'content_index': contentIndex,
      'audio_end_ms': audioEndMs,
    });
  }

  /// Disconnect from the API
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _webSocket.disconnect();
  }

  /// Dispose the client
  Future<void> dispose() async {
    await disconnect();
    await _audioController.close();
    await _transcriptController.close();
    await _userTranscriptController.close();
    await _userTranscriptDeltaController.close();
    await _errorController.close();
    await _audioDoneController.close();
    await _transcriptDoneController.close();
    await _functionCallController.close();
    await _speechStartedController.close();
    await _speechStoppedController.close();
    await _responseCreatedController.close();
    await _responseDoneController.close();
    await _itemCreatedController.close();
    await _itemDeletedController.close();
    await _outputItemAddedController.close();
    await _outputItemDoneController.close();
    await _contentPartAddedController.close();
    await _contentPartDoneController.close();
    await _textDeltaController.close();
    await _textDoneController.close();
    await _rateLimitsController.close();
    await _sessionCreatedController.close();
    await _sessionUpdatedController.close();
    await _outputAudioStartedController.close();
    await _outputAudioStoppedController.close();
    await _webSocket.dispose();
  }
}
