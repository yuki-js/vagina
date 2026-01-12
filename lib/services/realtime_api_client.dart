import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../config/app_config.dart';
import '../models/realtime_events.dart';
import '../models/realtime_session_config.dart';
import 'websocket_service.dart';
import 'log_service.dart';

/// Client for the Azure OpenAI Realtime API
/// 
/// This client handles all 36 server events defined in the OpenAI Realtime API:
/// 
/// **Session Events:**
/// - session.created - Emitted when connection is established
/// - session.updated - Returned after session.update
/// - transcription_session.updated - Returned after transcription_session.update
/// 
/// **Conversation Events:**
/// - conversation.created - Emitted right after session creation
/// - conversation.item.created - Returned when a conversation item is created
/// - conversation.item.deleted - Returned when an item is deleted
/// - conversation.item.truncated - Returned when an item is truncated
/// - conversation.item.retrieved - Returned when an item is retrieved
/// 
/// **Input Audio Transcription Events:**
/// - conversation.item.input_audio_transcription.completed - User's speech transcription done
/// - conversation.item.input_audio_transcription.delta - Streaming transcription updates
/// - conversation.item.input_audio_transcription.failed - Transcription failed
/// 
/// **Input Audio Buffer Events:**
/// - input_audio_buffer.committed - Audio buffer was committed
/// - input_audio_buffer.cleared - Audio buffer was cleared
/// - input_audio_buffer.speech_started - VAD detected speech
/// - input_audio_buffer.speech_stopped - VAD detected end of speech
/// 
/// **Output Audio Buffer Events (WebRTC only):**
/// - output_audio_buffer.started - Server began streaming audio
/// - output_audio_buffer.stopped - Audio buffer drained
/// - output_audio_buffer.cleared - Audio buffer was cleared
/// 
/// **Response Events:**
/// - response.created - New response being generated
/// - response.done - Response generation complete
/// - response.output_item.added - New item added during response
/// - response.output_item.done - Item streaming complete
/// - response.content_part.added - New content part added
/// - response.content_part.done - Content part streaming complete
/// - response.text.delta - Streaming text update
/// - response.text.done - Text streaming complete
/// - response.audio_transcript.delta - Streaming audio transcription
/// - response.audio_transcript.done - Audio transcription complete
/// - response.audio.delta - Streaming audio data
/// - response.audio.done - Audio streaming complete
/// - response.function_call_arguments.delta - Streaming function call arguments
/// - response.function_call_arguments.done - Function call arguments complete
/// 
/// **Rate Limits Events:**
/// - rate_limits.updated - Emitted at beginning of response
/// 
/// **Error Events:**
/// - error - Returned when an error occurs
class RealtimeApiClient {
  static const _tag = 'RealtimeAPI';
  
  final WebSocketService _webSocket;
  final LogService _logService;
  
  // Stream controllers for various event types
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _userTranscriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _userTranscriptDeltaController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<void> _audioDoneController =
      StreamController<void>.broadcast();
  final StreamController<FunctionCall> _functionCallController =
      StreamController<FunctionCall>.broadcast();
  final StreamController<void> _responseStartedController =
      StreamController<void>.broadcast();
  final StreamController<void> _speechStartedController =
      StreamController<void>.broadcast();
  final StreamController<void> _responseAudioStartedController =
      StreamController<void>.broadcast();
  final StreamController<RealtimeSession> _sessionCreatedController =
      StreamController<RealtimeSession>.broadcast();
  final StreamController<RealtimeSession> _sessionUpdatedController =
      StreamController<RealtimeSession>.broadcast();
  final StreamController<RealtimeConversation> _conversationCreatedController =
      StreamController<RealtimeConversation>.broadcast();
  final StreamController<ConversationItem> _conversationItemCreatedController =
      StreamController<ConversationItem>.broadcast();
  final StreamController<String> _conversationItemDeletedController =
      StreamController<String>.broadcast();
  final StreamController<RealtimeResponse> _responseDoneController =
      StreamController<RealtimeResponse>.broadcast();
  final StreamController<List<RateLimit>> _rateLimitsUpdatedController =
      StreamController<List<RateLimit>>.broadcast();
  final StreamController<String> _textDeltaController =
      StreamController<String>.broadcast();
  final StreamController<String> _textDoneController =
      StreamController<String>.broadcast();

  StreamSubscription? _messageSubscription;
  String? _lastError;
  int _audioChunksReceived = 0;
  int _audioChunksSent = 0;
  
  /// Tools to be registered with the session
  List<Map<String, dynamic>> _tools = [];
  
  /// Accumulated function call arguments (function calls come in deltas)
  final Map<String, StringBuffer> _pendingFunctionCalls = {};
  final Map<String, String> _pendingFunctionNames = {};

  /// Session configuration
  RealtimeSessionConfig _sessionConfig = const RealtimeSessionConfig();
  
  /// Noise reduction type ('near', 'far', or null for disabled)
  String? _noiseReduction;

  RealtimeApiClient({
    WebSocketService? webSocket,
    LogService? logService,
  })  : _webSocket = webSocket ?? WebSocketService(),
        _logService = logService ?? LogService();

  // Getters for connection state and streams
  bool get isConnected => _webSocket.isConnected;
  
  /// Stream of audio data received from the API
  Stream<Uint8List> get audioStream => _audioController.stream;
  
  /// Stream of assistant audio transcription deltas
  Stream<String> get transcriptStream => _transcriptController.stream;
  
  /// Stream of completed user speech transcriptions
  Stream<String> get userTranscriptStream => _userTranscriptController.stream;
  
  /// Stream of user speech transcription deltas (streaming)
  Stream<String> get userTranscriptDeltaStream => _userTranscriptDeltaController.stream;
  
  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;
  
  /// Stream indicating audio response is complete
  Stream<void> get audioDoneStream => _audioDoneController.stream;
  
  /// Stream of function calls from the AI
  Stream<FunctionCall> get functionCallStream => _functionCallController.stream;
  
  /// Stream indicating user started speaking (interrupt)
  Stream<void> get responseStartedStream => _responseStartedController.stream;
  
  /// Stream indicating speech was detected (VAD)
  Stream<void> get speechStartedStream => _speechStartedController.stream;
  
  /// Stream indicating AI audio response started (first audio chunk received)
  Stream<void> get responseAudioStartedStream => _responseAudioStartedController.stream;
  
  /// Stream of session created events
  Stream<RealtimeSession> get sessionCreatedStream => _sessionCreatedController.stream;
  
  /// Stream of session updated events
  Stream<RealtimeSession> get sessionUpdatedStream => _sessionUpdatedController.stream;
  
  /// Stream of conversation created events
  Stream<RealtimeConversation> get conversationCreatedStream => _conversationCreatedController.stream;
  
  /// Stream of conversation item created events
  Stream<ConversationItem> get conversationItemCreatedStream => _conversationItemCreatedController.stream;
  
  /// Stream of conversation item deleted events (item_id)
  Stream<String> get conversationItemDeletedStream => _conversationItemDeletedController.stream;
  
  /// Stream of response done events
  Stream<RealtimeResponse> get responseDoneStream => _responseDoneController.stream;
  
  /// Stream of rate limits updated events
  Stream<List<RateLimit>> get rateLimitsUpdatedStream => _rateLimitsUpdatedController.stream;
  
  /// Stream of text deltas (for text-only responses)
  Stream<String> get textDeltaStream => _textDeltaController.stream;
  
  /// Stream of completed text (for text-only responses)
  Stream<String> get textDoneStream => _textDoneController.stream;
  
  String? get lastError => _lastError;

  /// Set tools to be registered with the session
  void setTools(List<Map<String, dynamic>> tools) {
    _tools = tools;
  }

  /// Set voice and instructions for the session
  void setVoiceAndInstructions(String voice, String instructions) {
    _sessionConfig = _sessionConfig.copyWith(
      voice: voice,
      instructions: instructions,
    );
  }

  /// Connect to Azure OpenAI using a full Realtime URL and API key
  /// URL format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
  Future<void> connect(String realtimeUrl, String apiKey) async {
    _logService.info(_tag, 'Connecting to Azure OpenAI Realtime API');
    _audioChunksReceived = 0;
    _audioChunksSent = 0;
    _pendingFunctionCalls.clear();
    _pendingFunctionNames.clear();
    
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
          _logService.error(_tag, 'WebSocket error: $error');
          _lastError = error.toString();
          _errorController.add(_lastError!);
        },
      );

      // Session will be configured when session.created event is received
      _lastError = null;
      _logService.info(_tag, 'Connected, waiting for session.created event');
    } catch (e) {
      _logService.error(_tag, 'Connection failed: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
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
    // Update session config with current tools (voice and instructions already set via setVoiceAndInstructions)
    _sessionConfig = _sessionConfig.copyWith(
      tools: _tools,
    );
    
    _logService.info(_tag, 'Configuring session with voice: ${_sessionConfig.voice}, tools: ${_sessionConfig.tools.length}, noise_reduction: ${_sessionConfig.noiseReduction}');
    _logService.debug(_tag, 'Instructions: ${_sessionConfig.instructions}');
    
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

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final eventId = message['event_id'] as String? ?? '';

    // Use ServerEventType enum to ensure we handle all events
    final eventType = ServerEventType.fromString(type ?? '');
    
    switch (eventType) {
      // ===== Session Events =====
      case ServerEventType.sessionCreated:
        _handleSessionCreated(message, eventId);
        
      case ServerEventType.sessionUpdated:
        _handleSessionUpdated(message, eventId);
        
      case ServerEventType.transcriptionSessionUpdated:
        _handleTranscriptionSessionUpdated(message, eventId);
        
      // ===== Conversation Events =====
      case ServerEventType.conversationCreated:
        _handleConversationCreated(message, eventId);
        
      case ServerEventType.conversationItemCreated:
        _handleConversationItemCreated(message, eventId);
        
      case ServerEventType.conversationItemDeleted:
        _handleConversationItemDeleted(message, eventId);
        
      case ServerEventType.conversationItemTruncated:
        _handleConversationItemTruncated(message, eventId);
        
      case ServerEventType.conversationItemRetrieved:
        _handleConversationItemRetrieved(message, eventId);
        
      // ===== Input Audio Transcription Events =====
      case ServerEventType.conversationItemInputAudioTranscriptionCompleted:
        _handleInputAudioTranscriptionCompleted(message, eventId);
        
      case ServerEventType.conversationItemInputAudioTranscriptionDelta:
        _handleInputAudioTranscriptionDelta(message, eventId);
        
      case ServerEventType.conversationItemInputAudioTranscriptionFailed:
        _handleInputAudioTranscriptionFailed(message, eventId);
        
      // ===== Input Audio Buffer Events =====
      case ServerEventType.inputAudioBufferCommitted:
        _handleInputAudioBufferCommitted(message, eventId);
        
      case ServerEventType.inputAudioBufferCleared:
        _handleInputAudioBufferCleared(message, eventId);
        
      case ServerEventType.inputAudioBufferSpeechStarted:
        _handleInputAudioBufferSpeechStarted(message, eventId);
        
      case ServerEventType.inputAudioBufferSpeechStopped:
        _handleInputAudioBufferSpeechStopped(message, eventId);
        
      // ===== Output Audio Buffer Events (WebRTC only) =====
      case ServerEventType.outputAudioBufferStarted:
        _handleOutputAudioBufferStarted(message, eventId);
        
      case ServerEventType.outputAudioBufferStopped:
        _handleOutputAudioBufferStopped(message, eventId);
        
      case ServerEventType.outputAudioBufferCleared:
        _handleOutputAudioBufferCleared(message, eventId);
        
      // ===== Response Events =====
      case ServerEventType.responseCreated:
        _handleResponseCreated(message, eventId);
        
      case ServerEventType.responseDone:
        _handleResponseDone(message, eventId);
        
      // ===== Response Output Item Events =====
      case ServerEventType.responseOutputItemAdded:
        _handleResponseOutputItemAdded(message, eventId);
        
      case ServerEventType.responseOutputItemDone:
        _handleResponseOutputItemDone(message, eventId);
        
      // ===== Response Content Part Events =====
      case ServerEventType.responseContentPartAdded:
        _handleResponseContentPartAdded(message, eventId);
        
      case ServerEventType.responseContentPartDone:
        _handleResponseContentPartDone(message, eventId);
        
      // ===== Response Text Events =====
      case ServerEventType.responseTextDelta:
        _handleResponseTextDelta(message, eventId);
        
      case ServerEventType.responseTextDone:
        _handleResponseTextDone(message, eventId);
        
      // ===== Response Audio Transcript Events =====
      case ServerEventType.responseAudioTranscriptDelta:
        _handleResponseAudioTranscriptDelta(message, eventId);
        
      case ServerEventType.responseAudioTranscriptDone:
        _handleResponseAudioTranscriptDone(message, eventId);
        
      // ===== Response Audio Events =====
      case ServerEventType.responseAudioDelta:
        _handleResponseAudioDelta(message, eventId);
        
      case ServerEventType.responseAudioDone:
        _handleResponseAudioDone(message, eventId);
        
      // ===== Response Function Call Events =====
      case ServerEventType.responseFunctionCallArgumentsDelta:
        _handleResponseFunctionCallArgumentsDelta(message, eventId);
        
      case ServerEventType.responseFunctionCallArgumentsDone:
        _handleResponseFunctionCallArgumentsDone(message, eventId);
        
      // ===== Rate Limits Events =====
      case ServerEventType.rateLimitsUpdated:
        _handleRateLimitsUpdated(message, eventId);
        
      // ===== Error Events =====
      case ServerEventType.error:
        _handleError(message, eventId);
        
      case null:
        // Unknown event type - could be a new event type added by OpenAI
        // or a malformed message. Log for debugging but don't error.
        if (type == null || type.isEmpty) {
          _logService.warn(_tag, 'Received message without event type');
        } else {
          _logService.warn(_tag, 'Unknown/unhandled event type received: $type');
        }
    }
  }

  // =============================================================================
  // Session Event Handlers
  // =============================================================================
  
  /// Handle session.created event
  /// Emitted automatically when a new connection is established as the first server event.
  void _handleSessionCreated(Map<String, dynamic> message, String eventId) {
    _logService.info(_tag, 'Session created, sending session.update');
    
    final sessionJson = message['session'] as Map<String, dynamic>?;
    if (sessionJson != null) {
      final session = RealtimeSession.fromJson(sessionJson);
      _sessionCreatedController.add(session);
      _logService.debug(_tag, 'Session ID: ${session.id}, Model: ${session.model}');
    }
    
    // Send session.update after session is created
    _configureSession();
  }
  
  /// Handle session.updated event
  /// Returned when a session is updated with a session.update event.
  void _handleSessionUpdated(Map<String, dynamic> message, String eventId) {
    final sessionJson = message['session'] as Map<String, dynamic>?;
    if (sessionJson != null) {
      final session = RealtimeSession.fromJson(sessionJson);
      _sessionUpdatedController.add(session);
      
      final turnDetection = sessionJson['turn_detection'] as Map<String, dynamic>?;
      final transcription = sessionJson['input_audio_transcription'] as Map<String, dynamic>?;
      final tools = sessionJson['tools'] as List?;
      _logService.info(_tag, 'Session updated - turn_detection: ${turnDetection?['type']}, '
          'transcription: ${transcription?['model']}, tools: ${tools?.length ?? 0}');
    } else {
      _logService.info(_tag, 'Session updated');
    }
  }
  
  /// Handle transcription_session.updated event
  /// Returned when a transcription session is updated.
  void _handleTranscriptionSessionUpdated(Map<String, dynamic> message, String eventId) {
    _logService.info(_tag, 'Transcription session updated');
    // This is for transcription-only sessions, which we don't currently use
    // but we handle it for completeness
  }

  // =============================================================================
  // Conversation Event Handlers
  // =============================================================================
  
  /// Handle conversation.created event
  /// Returned when a conversation is created, emitted right after session creation.
  void _handleConversationCreated(Map<String, dynamic> message, String eventId) {
    final conversationJson = message['conversation'] as Map<String, dynamic>?;
    if (conversationJson != null) {
      final conversation = RealtimeConversation.fromJson(conversationJson);
      _conversationCreatedController.add(conversation);
      _logService.info(_tag, 'Conversation created: ${conversation.id}');
    } else {
      _logService.info(_tag, 'Conversation created');
    }
  }
  
  /// Handle conversation.item.created event
  /// Returned when a conversation item is created.
  void _handleConversationItemCreated(Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    final previousItemId = message['previous_item_id'] as String?;
    
    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _conversationItemCreatedController.add(item);
      _logService.debug(_tag, 'Conversation item created: ${item.id} (type: ${item.type}, '
          'role: ${item.role}, previous: $previousItemId)');
    }
  }
  
  /// Handle conversation.item.deleted event
  /// Returned when an item in the conversation is deleted.
  void _handleConversationItemDeleted(Map<String, dynamic> message, String eventId) {
    final itemId = message['item_id'] as String?;
    if (itemId != null) {
      _conversationItemDeletedController.add(itemId);
      _logService.info(_tag, 'Conversation item deleted: $itemId');
    }
  }
  
  /// Handle conversation.item.truncated event
  /// Returned when an earlier assistant audio message item is truncated.
  void _handleConversationItemTruncated(Map<String, dynamic> message, String eventId) {
    final itemId = message['item_id'] as String?;
    final contentIndex = message['content_index'] as int?;
    final audioEndMs = message['audio_end_ms'] as int?;
    _logService.info(_tag, 'Conversation item truncated: $itemId '
        '(content_index: $contentIndex, audio_end_ms: $audioEndMs)');
  }
  
  /// Handle conversation.item.retrieved event
  /// Returned when a conversation item is retrieved.
  void _handleConversationItemRetrieved(Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _logService.info(_tag, 'Conversation item retrieved: ${item.id}');
    }
  }

  // =============================================================================
  // Input Audio Transcription Event Handlers
  // =============================================================================
  
  /// Handle conversation.item.input_audio_transcription.completed event
  /// User's speech transcription is done.
  void _handleInputAudioTranscriptionCompleted(Map<String, dynamic> message, String eventId) {
    final transcript = message['transcript'] as String?;
    final itemId = message['item_id'] as String?;
    
    if (transcript != null && transcript.isNotEmpty) {
      _logService.info(_tag, 'User transcript completed: $transcript');
      _userTranscriptController.add(transcript);
    } else {
      _logService.warn(_tag, 'User transcript received but empty (item_id: $itemId)');
    }
  }
  
  /// Handle conversation.item.input_audio_transcription.delta event
  /// Streaming transcription updates for user audio.
  void _handleInputAudioTranscriptionDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;
    
    if (delta != null && delta.isNotEmpty) {
      _logService.debug(_tag, 'User transcript delta: $delta');
      _userTranscriptDeltaController.add(delta);
    }
  }
  
  /// Handle conversation.item.input_audio_transcription.failed event
  /// Transcription request failed.
  void _handleInputAudioTranscriptionFailed(Map<String, dynamic> message, String eventId) {
    final errorJson = message['error'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;
    
    if (errorJson != null) {
      final error = RealtimeError.fromJson(errorJson);
      _logService.error(_tag, 'User transcription failed (item_id: $itemId): '
          '[${error.code}] ${error.message}');
    } else {
      _logService.error(_tag, 'User transcription failed (item_id: $itemId): unknown error');
    }
  }

  // =============================================================================
  // Input Audio Buffer Event Handlers
  // =============================================================================
  
  /// Handle input_audio_buffer.committed event
  /// Audio buffer was committed.
  void _handleInputAudioBufferCommitted(Map<String, dynamic> message, String eventId) {
    final previousItemId = message['previous_item_id'] as String?;
    final itemId = message['item_id'] as String?;
    _logService.info(_tag, 'Audio buffer committed (item_id: $itemId, previous: $previousItemId)');
  }
  
  /// Handle input_audio_buffer.cleared event
  /// Audio buffer was cleared.
  void _handleInputAudioBufferCleared(Map<String, dynamic> message, String eventId) {
    _logService.info(_tag, 'Audio buffer cleared');
  }
  
  /// Handle input_audio_buffer.speech_started event
  /// VAD detected speech in the audio buffer.
  void _handleInputAudioBufferSpeechStarted(Map<String, dynamic> message, String eventId) {
    final audioStartMs = message['audio_start_ms'] as int?;
    final itemId = message['item_id'] as String?;
    
    _logService.info(_tag, 'Speech started (VAD detected) at ${audioStartMs}ms, item_id: $itemId');
    
    // Notify that user speech started (for creating placeholder message)
    _speechStartedController.add(null);
    // Stop current audio playback when user starts speaking (interrupt)
    _responseStartedController.add(null);
  }
  
  /// Handle input_audio_buffer.speech_stopped event
  /// VAD detected end of speech.
  void _handleInputAudioBufferSpeechStopped(Map<String, dynamic> message, String eventId) {
    final audioEndMs = message['audio_end_ms'] as int?;
    final itemId = message['item_id'] as String?;
    _logService.info(_tag, 'Speech stopped (VAD detected) at ${audioEndMs}ms, item_id: $itemId');
  }

  // =============================================================================
  // Output Audio Buffer Event Handlers (WebRTC only)
  // =============================================================================
  
  /// Handle output_audio_buffer.started event
  /// Server began streaming audio (WebRTC only).
  void _handleOutputAudioBufferStarted(Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _logService.debug(_tag, 'Output audio buffer started (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
    // We log it but take no action in our WebSocket-based implementation
  }
  
  /// Handle output_audio_buffer.stopped event
  /// Audio buffer drained (WebRTC only).
  void _handleOutputAudioBufferStopped(Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _logService.debug(_tag, 'Output audio buffer stopped (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
  }
  
  /// Handle output_audio_buffer.cleared event
  /// Audio buffer was cleared (WebRTC only).
  void _handleOutputAudioBufferCleared(Map<String, dynamic> message, String eventId) {
    final responseId = message['response_id'] as String?;
    _logService.debug(_tag, 'Output audio buffer cleared (response_id: $responseId) [WebRTC only]');
    // This event is for WebRTC connections, not WebSocket
  }

  // =============================================================================
  // Response Event Handlers
  // =============================================================================
  
  /// Handle response.created event
  /// New response is being generated.
  void _handleResponseCreated(Map<String, dynamic> message, String eventId) {
    final responseJson = message['response'] as Map<String, dynamic>?;
    
    _logService.info(_tag, 'Response created - AI is generating response');
    _audioChunksReceived = 0; // Reset audio chunk counter for new response
    
    if (responseJson != null) {
      final response = RealtimeResponse.fromJson(responseJson);
      _logService.debug(_tag, 'Response ID: ${response.id}, Status: ${response.status}');
    }
    // Don't stop audio here - let it play until speech_started interrupts
  }
  
  /// Handle response.done event
  /// Response generation is complete.
  void _handleResponseDone(Map<String, dynamic> message, String eventId) {
    final responseJson = message['response'] as Map<String, dynamic>?;
    
    if (responseJson != null) {
      final response = RealtimeResponse.fromJson(responseJson);
      _responseDoneController.add(response);
      
      final usage = response.usage;
      if (usage != null) {
        _logService.info(_tag, 'Response complete - Status: ${response.status}, '
            'Tokens: ${usage.totalTokens} (in: ${usage.inputTokens}, out: ${usage.outputTokens})');
      } else {
        _logService.info(_tag, 'Response complete - Status: ${response.status}');
      }
    } else {
      _logService.info(_tag, 'Response complete');
    }
  }

  // =============================================================================
  // Response Output Item Event Handlers
  // =============================================================================
  
  /// Handle response.output_item.added event
  /// New item added during response generation.
  void _handleResponseOutputItemAdded(Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    final responseId = message['response_id'] as String?;
    final outputIndex = message['output_index'] as int?;
    
    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      
      // Check if this is a function call
      if (item.type == 'function_call') {
        final callId = item.callId ?? '';
        final name = item.name ?? '';
        _pendingFunctionCalls[callId] = StringBuffer();
        _pendingFunctionNames[callId] = name;
        _logService.info(_tag, 'Function call started: $name (call_id: $callId)');
      } else {
        _logService.debug(_tag, 'Output item added: ${item.id} (type: ${item.type}, '
            'response_id: $responseId, index: $outputIndex)');
      }
    }
  }
  
  /// Handle response.output_item.done event
  /// Item streaming is complete.
  void _handleResponseOutputItemDone(Map<String, dynamic> message, String eventId) {
    final itemJson = message['item'] as Map<String, dynamic>?;
    
    if (itemJson != null) {
      final item = ConversationItem.fromJson(itemJson);
      _logService.debug(_tag, 'Output item done: ${item.id} (status: ${item.status})');
    }
  }

  // =============================================================================
  // Response Content Part Event Handlers
  // =============================================================================
  
  /// Handle response.content_part.added event
  /// New content part added to an item.
  void _handleResponseContentPartAdded(Map<String, dynamic> message, String eventId) {
    final partJson = message['part'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;
    final contentIndex = message['content_index'] as int?;
    
    if (partJson != null) {
      final partType = partJson['type'] as String?;
      _logService.debug(_tag, 'Content part added: $partType (item_id: $itemId, index: $contentIndex)');
    }
  }
  
  /// Handle response.content_part.done event
  /// Content part streaming is complete.
  void _handleResponseContentPartDone(Map<String, dynamic> message, String eventId) {
    final partJson = message['part'] as Map<String, dynamic>?;
    final itemId = message['item_id'] as String?;
    
    if (partJson != null) {
      final partType = partJson['type'] as String?;
      _logService.debug(_tag, 'Content part done: $partType (item_id: $itemId)');
    }
  }

  // =============================================================================
  // Response Text Event Handlers
  // =============================================================================
  
  /// Handle response.text.delta event
  /// Streaming text content update.
  void _handleResponseTextDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;
    
    if (delta != null) {
      _textDeltaController.add(delta);
      // Also add to transcript stream for text-only responses
      _transcriptController.add(delta);
    }
  }
  
  /// Handle response.text.done event
  /// Text content streaming is complete.
  void _handleResponseTextDone(Map<String, dynamic> message, String eventId) {
    final text = message['text'] as String?;
    final itemId = message['item_id'] as String?;
    
    if (text != null) {
      _textDoneController.add(text);
      _logService.debug(_tag, 'Text response complete (item_id: $itemId): ${text.length} chars');
    }
  }

  // =============================================================================
  // Response Audio Transcript Event Handlers
  // =============================================================================
  
  /// Handle response.audio_transcript.delta event
  /// Streaming audio transcription update.
  void _handleResponseAudioTranscriptDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;
    
    if (delta != null) {
      // Don't log transcript deltas to reduce noise; they will appear in chat UI
      _transcriptController.add(delta);
    }
  }
  
  /// Handle response.audio_transcript.done event
  /// Audio transcription is complete.
  void _handleResponseAudioTranscriptDone(Map<String, dynamic> message, String eventId) {
    final transcript = message['transcript'] as String?;
    final itemId = message['item_id'] as String?;
    
    _logService.debug(_tag, 'Audio transcript complete (item_id: $itemId): '
        '${transcript?.length ?? 0} chars');
  }

  // =============================================================================
  // Response Audio Event Handlers
  // =============================================================================
  
  /// Handle response.audio.delta event
  /// Streaming audio data.
  void _handleResponseAudioDelta(Map<String, dynamic> message, String eventId) {
    final delta = message['delta'] as String?;
    
    if (delta != null) {
      _audioChunksReceived++;
      final audioData = base64Decode(delta);
      
      // Emit event when first audio chunk of a response arrives
      if (_audioChunksReceived == 1) {
        _responseAudioStartedController.add(null);
        _logService.info(_tag, 'AI audio response started (first chunk received)');
      }
      
      // Only log periodically to reduce log noise
      if (_audioChunksReceived % AppConfig.logAudioChunkInterval == 0) {
        _logService.debug(_tag, 'Audio delta received (chunk #$_audioChunksReceived, '
            '${audioData.length} bytes)');
      }
      
      _audioController.add(Uint8List.fromList(audioData));
    }
  }
  
  /// Handle response.audio.done event
  /// Audio streaming is complete.
  void _handleResponseAudioDone(Map<String, dynamic> message, String eventId) {
    _logService.info(_tag, 'Audio response complete. Total chunks received: $_audioChunksReceived');
    _audioDoneController.add(null);
  }

  // =============================================================================
  // Response Function Call Event Handlers
  // =============================================================================
  
  /// Handle response.function_call_arguments.delta event
  /// Streaming function call arguments.
  void _handleResponseFunctionCallArgumentsDelta(Map<String, dynamic> message, String eventId) {
    final callId = message['call_id'] as String?;
    final delta = message['delta'] as String?;
    
    if (callId != null && delta != null) {
      _pendingFunctionCalls[callId]?.write(delta);
      _logService.debug(_tag, 'Function call arguments delta: $delta');
    }
  }
  
  /// Handle response.function_call_arguments.done event
  /// Function call arguments complete.
  void _handleResponseFunctionCallArgumentsDone(Map<String, dynamic> message, String eventId) {
    final callId = message['call_id'] as String?;
    
    if (callId != null && _pendingFunctionCalls.containsKey(callId)) {
      final arguments = _pendingFunctionCalls[callId]!.toString();
      final name = _pendingFunctionNames[callId] ?? 'unknown';
      
      _logService.info(_tag, 'Function call complete: $name with args: $arguments');
      
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

  // =============================================================================
  // Rate Limits Event Handlers
  // =============================================================================
  
  /// Handle rate_limits.updated event
  /// Emitted at the beginning of a response to indicate updated rate limits.
  void _handleRateLimitsUpdated(Map<String, dynamic> message, String eventId) {
    final rateLimitsJson = message['rate_limits'] as List<dynamic>?;
    
    if (rateLimitsJson != null) {
      final rateLimits = rateLimitsJson
          .map((r) => RateLimit.fromJson(r as Map<String, dynamic>))
          .toList();
      
      _rateLimitsUpdatedController.add(rateLimits);
      
      // Log rate limits for monitoring
      for (final limit in rateLimits) {
        _logService.debug(_tag, 'Rate limit ${limit.name}: ${limit.remaining}/${limit.limit} '
            '(resets in ${limit.resetSeconds.toStringAsFixed(1)}s)');
      }
    }
  }

  // =============================================================================
  // Error Event Handler
  // =============================================================================
  
  /// Handle error event
  /// Returned when an error occurs.
  void _handleError(Map<String, dynamic> message, String eventId) {
    final errorJson = message['error'] as Map<String, dynamic>?;
    
    if (errorJson != null) {
      final error = RealtimeError.fromJson(errorJson);
      final fullError = error.code != null 
          ? '[${error.code}] ${error.message}' 
          : error.message;
      
      _logService.error(_tag, 'API error: $fullError');
      _lastError = fullError;
      _errorController.add(fullError);
    } else {
      const unknownError = 'Unknown error';
      _logService.error(_tag, 'API error: $unknownError');
      _lastError = unknownError;
      _errorController.add(unknownError);
    }
  }

  /// Send audio data to the API
  void sendAudio(Uint8List audioData) {
    if (!isConnected) {
      _logService.warn(_tag, 'Cannot send audio: not connected');
      _errorController.add('Cannot send audio: not connected');
      return;
    }

    _audioChunksSent++;
    if (_audioChunksSent % AppConfig.logAudioChunkInterval == 0) {
      _logService.debug(_tag, 'Sent $_audioChunksSent audio chunks');
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
      _errorController.add('Cannot commit audio buffer: not connected');
      return;
    }

    _webSocket.send({
      'type': ClientEventType.inputAudioBufferCommit.value,
    });
  }

  /// Clear the audio buffer
  void clearAudioBuffer() {
    if (!isConnected) return;

    _webSocket.send({
      'type': ClientEventType.inputAudioBufferClear.value,
    });
  }

  /// Send a text message
  void sendTextMessage(String text) {
    if (!isConnected) {
      _errorController.add('Cannot send message: not connected');
      return;
    }

    _logService.info(_tag, 'Sending text message: $text');

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
      _errorController.add('Cannot send function result: not connected');
      return;
    }

    _logService.info(_tag, 'Sending function call result for $callId');

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

  /// Disconnect from the API
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _webSocket.disconnect();
  }

  /// Dispose the client
  Future<void> dispose() async {
    await disconnect();
    
    // Close all stream controllers
    await _audioController.close();
    await _transcriptController.close();
    await _userTranscriptController.close();
    await _userTranscriptDeltaController.close();
    await _errorController.close();
    await _audioDoneController.close();
    await _functionCallController.close();
    await _responseStartedController.close();
    await _speechStartedController.close();
    await _responseAudioStartedController.close();
    await _sessionCreatedController.close();
    await _sessionUpdatedController.close();
    await _conversationCreatedController.close();
    await _conversationItemCreatedController.close();
    await _conversationItemDeletedController.close();
    await _responseDoneController.close();
    await _rateLimitsUpdatedController.close();
    await _textDeltaController.close();
    await _textDoneController.close();
    
    await _webSocket.dispose();
  }
}
