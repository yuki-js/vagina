import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../config/app_config.dart';
import '../models/realtime_events.dart';
import '../models/realtime_session_config.dart';
import 'websocket_service.dart';
import 'log_service.dart';

/// Client for the Azure OpenAI Realtime API
class RealtimeApiClient {
  static const _tag = 'RealtimeAPI';
  
  /// Log audio chunks sent every N chunks to avoid log explosion
  static const int _logAudioChunkInterval = 50;
  
  final WebSocketService _webSocket = WebSocketService();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _userTranscriptController =
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

  StreamSubscription? _messageSubscription;
  String? _lastError;
  int _audioChunksReceived = 0;
  int _audioChunksSent = 0;
  
  /// Tools to be registered with the session
  List<Map<String, dynamic>> _tools = [];
  
  /// Accumulated function call arguments (function calls come in deltas)
  final Map<String, StringBuffer> _pendingFunctionCalls = {};
  final Map<String, String> _pendingFunctionNames = {};

  bool get isConnected => _webSocket.isConnected;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get userTranscriptStream => _userTranscriptController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<void> get audioDoneStream => _audioDoneController.stream;
  Stream<FunctionCall> get functionCallStream => _functionCallController.stream;
  Stream<void> get responseStartedStream => _responseStartedController.stream;
  Stream<void> get speechStartedStream => _speechStartedController.stream;
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
          _errorController.add(_lastError!);
        },
      );

      // Session will be configured when session.created event is received
      _lastError = null;
      logService.info(_tag, 'Connected, waiting for session.created event');
    } catch (e) {
      logService.error(_tag, 'Connection failed: $e');
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

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'session.created':
        logService.info(_tag, 'Session created, sending session.update');
        // Send session.update after session is created
        _configureSession();
        break;
        
      case 'session.updated':
        // Log session details to verify our configuration was applied
        final session = message['session'] as Map<String, dynamic>?;
        if (session != null) {
          final turnDetection = session['turn_detection'] as Map<String, dynamic>?;
          final transcription = session['input_audio_transcription'] as Map<String, dynamic>?;
          final tools = session['tools'] as List?;
          logService.info(_tag, 'Session updated - turn_detection: ${turnDetection?['type']}, transcription: ${transcription?['model']}, tools: ${tools?.length ?? 0}');
        } else {
          logService.info(_tag, 'Session updated');
        }
        break;
        
      case 'input_audio_buffer.speech_started':
        logService.info(_tag, 'Speech started (VAD detected)');
        // Notify that user speech started (for creating placeholder message)
        _speechStartedController.add(null);
        // Stop current audio playback when user starts speaking (interrupt)
        _responseStartedController.add(null);
        break;
        
      case 'input_audio_buffer.speech_stopped':
        logService.info(_tag, 'Speech stopped (VAD detected)');
        break;
        
      case 'input_audio_buffer.committed':
        logService.info(_tag, 'Audio buffer committed');
        break;
        
      case 'conversation.item.input_audio_transcription.completed':
        // User's speech transcription
        final transcript = message['transcript'] as String?;
        if (transcript != null && transcript.isNotEmpty) {
          logService.info(_tag, 'User transcript: $transcript');
          _userTranscriptController.add(transcript);
        } else {
          logService.warn(_tag, 'User transcript received but empty');
        }
        break;
        
      case 'conversation.item.input_audio_transcription.failed':
        // Transcription failed
        final error = message['error'] as Map<String, dynamic>?;
        logService.error(_tag, 'User transcription failed: ${error?['message'] ?? 'unknown error'}');
        break;
        
      case 'response.created':
        logService.info(_tag, 'Response created - AI is generating response');
        _audioChunksReceived = 0; // Reset audio chunk counter for new response
        // Don't stop audio here - let it play until speech_started interrupts
        break;
        
      case 'response.output_item.added':
        // Check if this is a function call
        final item = message['item'] as Map<String, dynamic>?;
        if (item != null && item['type'] == 'function_call') {
          final callId = item['call_id'] as String? ?? '';
          final name = item['name'] as String? ?? '';
          _pendingFunctionCalls[callId] = StringBuffer();
          _pendingFunctionNames[callId] = name;
          logService.info(_tag, 'Function call started: $name (call_id: $callId)');
        }
        break;
        
      case 'response.function_call_arguments.delta':
        final callId = message['call_id'] as String?;
        final delta = message['delta'] as String?;
        if (callId != null && delta != null) {
          _pendingFunctionCalls[callId]?.write(delta);
          logService.debug(_tag, 'Function call arguments delta: $delta');
        }
        break;
        
      case 'response.function_call_arguments.done':
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
        break;
        
      case 'response.audio.delta':
        final delta = message['delta'] as String?;
        if (delta != null) {
          _audioChunksReceived++;
          final audioData = base64Decode(delta);
          // Only log every 50th chunk to reduce log noise
          if (_audioChunksReceived % _logAudioChunkInterval == 0) {
            logService.debug(_tag, 'Audio delta received (chunk #$_audioChunksReceived, ${audioData.length} bytes)');
          }
          _audioController.add(Uint8List.fromList(audioData));
        }
        break;
        
      case 'response.audio.done':
        logService.info(_tag, 'Audio response complete. Total chunks received: $_audioChunksReceived');
        _audioDoneController.add(null);
        break;

      case 'response.audio_transcript.delta':
        final delta = message['delta'] as String?;
        if (delta != null) {
          // Don't log transcript deltas to reduce noise; they will appear in chat UI
          _transcriptController.add(delta);
        }
        break;
        
      case 'response.done':
        logService.info(_tag, 'Response complete');
        break;

      case 'error':
        final error = message['error'] as Map<String, dynamic>?;
        final errorMessage = error?['message'] as String? ?? 'Unknown error';
        final errorCode = error?['code'] as String?;
        final fullError = errorCode != null 
            ? '[$errorCode] $errorMessage' 
            : errorMessage;
        logService.error(_tag, 'API error: $fullError');
        _lastError = fullError;
        _errorController.add(fullError);
        break;
        
      default:
        logService.debug(_tag, 'Received event: $type');
    }
  }

  /// Send audio data to the API
  void sendAudio(Uint8List audioData) {
    if (!isConnected) {
      logService.warn(_tag, 'Cannot send audio: not connected');
      _errorController.add('Cannot send audio: not connected');
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
      _errorController.add('Cannot send function result: not connected');
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
    await _errorController.close();
    await _audioDoneController.close();
    await _functionCallController.close();
    await _responseStartedController.close();
    await _speechStartedController.close();
    await _webSocket.dispose();
  }
}
