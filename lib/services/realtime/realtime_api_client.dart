import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/models/realtime_session_config.dart';
import '../websocket_service.dart';
import '../log_service.dart';
import 'realtime_types.dart';
import 'realtime_state.dart';
import 'realtime_streams.dart';
import 'realtime_event_router.dart';
import 'session_handlers.dart';
import 'response_handlers.dart';

/// Client for the Azure OpenAI Realtime API
///
/// This client handles all 36 server events defined in the OpenAI Realtime API.
class RealtimeApiClient {
  static const _tag = 'RealtimeAPI';

  final WebSocketService _webSocket;
  final LogService _logService;
  final RealtimeStreams _streams;
  final RealtimeState _state;

  late final RealtimeEventRouter _router;

  StreamSubscription? _messageSubscription;

  List<Map<String, dynamic>> _tools = [];
  RealtimeSessionConfig _sessionConfig = const RealtimeSessionConfig();

  RealtimeApiClient({
    WebSocketService? webSocket,
    LogService? logService,
    RealtimeStreams? streams,
    RealtimeState? state,
  })  : _webSocket = webSocket ?? WebSocketService(),
        _logService = logService ?? LogService(),
        _streams = streams ?? RealtimeStreams(),
        _state = state ?? RealtimeState() {
    _router = _buildRouter();
  }

  RealtimeEventRouter _buildRouter() {
    return RealtimeEventRouter(
      sessionHandlers: SessionHandlers(
        streams: _streams,
        log: _logService,
        onSessionCreated: _configureSession,
      ),
      responseHandlers: ResponseHandlers(
        streams: _streams,
        log: _logService,
        state: _state,
      ),
      log: _logService,
    );
  }

  // ========== Connection State Getters ==========

  bool get isConnected => _webSocket.isConnected;
  String? get lastError => _state.lastError;
  String get noiseReduction => _sessionConfig.noiseReduction;

  // ========== Stream Getters (delegate to _streams) ==========

  /// Stream of audio data received from the API
  Stream<Uint8List> get audioStream => _streams.audioStream;

  /// Stream of assistant audio transcription deltas
  Stream<String> get transcriptStream => _streams.transcriptStream;

  /// Stream of completed user speech transcriptions
  Stream<String> get userTranscriptStream => _streams.userTranscriptStream;

  /// Stream of user speech transcription deltas (streaming)
  Stream<String> get userTranscriptDeltaStream =>
      _streams.userTranscriptDeltaStream;

  /// Stream of error messages
  Stream<String> get errorStream => _streams.errorStream;

  /// Stream indicating audio response is complete
  Stream<void> get audioDoneStream => _streams.audioDoneStream;

  /// Stream of function calls from the AI
  Stream<FunctionCall> get functionCallStream => _streams.functionCallStream;

  /// Stream indicating user started speaking (interrupt)
  Stream<void> get responseStartedStream => _streams.responseStartedStream;

  /// Stream indicating speech was detected (VAD)
  Stream<void> get speechStartedStream => _streams.speechStartedStream;

  /// Stream indicating AI audio response started (first audio chunk received)
  Stream<void> get responseAudioStartedStream =>
      _streams.responseAudioStartedStream;

  /// Stream of session created events
  Stream<RealtimeSession> get sessionCreatedStream =>
      _streams.sessionCreatedStream;

  /// Stream of session updated events
  Stream<RealtimeSession> get sessionUpdatedStream =>
      _streams.sessionUpdatedStream;

  /// Stream of conversation created events
  Stream<RealtimeConversation> get conversationCreatedStream =>
      _streams.conversationCreatedStream;

  /// Stream of conversation item created events
  Stream<ConversationItem> get conversationItemCreatedStream =>
      _streams.conversationItemCreatedStream;

  /// Stream of conversation item deleted events (item_id)
  Stream<String> get conversationItemDeletedStream =>
      _streams.conversationItemDeletedStream;

  /// Stream of response done events
  Stream<RealtimeResponse> get responseDoneStream =>
      _streams.responseDoneStream;

  /// Stream of rate limits updated events
  Stream<List<RateLimit>> get rateLimitsUpdatedStream =>
      _streams.rateLimitsUpdatedStream;

  /// Stream of text deltas (for text-only responses)
  Stream<String> get textDeltaStream => _streams.textDeltaStream;

  /// Stream of completed text (for text-only responses)
  Stream<String> get textDoneStream => _streams.textDoneStream;

  // ========== Configuration Methods ==========

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

  /// Set noise reduction type ('far' or 'near')
  void setNoiseReduction(String type) {
    if (type == 'far' || type == 'near') {
      _sessionConfig = _sessionConfig.copyWith(noiseReduction: type);
    }
  }

  /// Update session configuration (can be called after connection)
  void updateSessionConfig() {
    if (!isConnected) return;
    _configureSession();
  }

  // ========== Connection Methods ==========

  /// Connect to Azure OpenAI using a full Realtime URL and API key
  /// URL format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
  Future<void> connect(String realtimeUrl, String apiKey) async {
    _logService.info(_tag, 'Connecting to Azure OpenAI Realtime API');
    _state.reset();

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
        _router.routeEvent,
        onError: (error) {
          _logService.error(_tag, 'WebSocket error: $error');
          _state.lastError = error.toString();
          _streams.emitError(_state.lastError!);
        },
      );

      // Session will be configured when session.created event is received
      _state.lastError = null;
      _logService.info(_tag, 'Connected, waiting for session.created event');
    } catch (e) {
      _logService.error(_tag, 'Connection failed: $e');
      _state.lastError = e.toString();
      _streams.emitError(_state.lastError!);
      rethrow;
    }
  }

  void _configureSession() {
    // Update session config with current tools (voice and instructions already set via setVoiceAndInstructions)
    _sessionConfig = _sessionConfig.copyWith(
      tools: _tools,
    );

    _logService.info(
      _tag,
      'Configuring session with voice: ${_sessionConfig.voice}, '
      'tools: ${_sessionConfig.tools.length}, '
      'noise_reduction: ${_sessionConfig.noiseReduction}',
    );
    _logService.debug(_tag, 'Instructions: ${_sessionConfig.instructions}');

    // Send session update with configuration
    _webSocket.send({
      'type': ClientEventType.sessionUpdate.value,
      'session': _sessionConfig.toSessionPayload(),
    });
  }

  // ========== Public API Methods ==========

  /// Send audio data to the API
  void sendAudio(Uint8List audioData) {
    if (!isConnected) {
      _logService.warn(_tag, 'Cannot send audio: not connected');
      _streams.emitError('Cannot send audio: not connected');
      return;
    }

    _state.audioChunksSent++;
    if (_state.audioChunksSent % AppConfig.logAudioChunkInterval == 0) {
      _logService.debug(_tag, 'Sent ${_state.audioChunksSent} audio chunks');
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
      _streams.emitError('Cannot commit audio buffer: not connected');
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
      _streams.emitError('Cannot send message: not connected');
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
      _streams.emitError('Cannot send function result: not connected');
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

  // ========== Lifecycle Methods ==========

  /// Disconnect from the API
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _webSocket.disconnect();
  }

  /// Dispose the client
  Future<void> dispose() async {
    await disconnect();
    await _streams.dispose();
    await _webSocket.dispose();
  }
}
