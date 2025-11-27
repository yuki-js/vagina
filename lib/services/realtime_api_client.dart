import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../config/app_config.dart';
import 'websocket_service.dart';
import 'log_service.dart';

/// Events sent by the client to the Azure OpenAI Realtime API
enum ClientEventType {
  sessionUpdate('session.update'),
  inputAudioBufferAppend('input_audio_buffer.append'),
  inputAudioBufferCommit('input_audio_buffer.commit'),
  inputAudioBufferClear('input_audio_buffer.clear'),
  conversationItemCreate('conversation.item.create'),
  conversationItemTruncate('conversation.item.truncate'),
  conversationItemDelete('conversation.item.delete'),
  responseCreate('response.create'),
  responseCancel('response.cancel');

  final String value;
  const ClientEventType(this.value);
}

/// Events received from the Azure OpenAI Realtime API
enum ServerEventType {
  error('error'),
  sessionCreated('session.created'),
  sessionUpdated('session.updated'),
  conversationCreated('conversation.created'),
  inputAudioBufferCommitted('input_audio_buffer.committed'),
  inputAudioBufferCleared('input_audio_buffer.cleared'),
  inputAudioBufferSpeechStarted('input_audio_buffer.speech_started'),
  inputAudioBufferSpeechStopped('input_audio_buffer.speech_stopped'),
  conversationItemCreated('conversation.item.created'),
  conversationItemInputAudioTranscriptionCompleted(
      'conversation.item.input_audio_transcription.completed'),
  conversationItemInputAudioTranscriptionFailed(
      'conversation.item.input_audio_transcription.failed'),
  conversationItemTruncated('conversation.item.truncated'),
  conversationItemDeleted('conversation.item.deleted'),
  responseCreated('response.created'),
  responseDone('response.done'),
  responseOutputItemAdded('response.output_item.added'),
  responseOutputItemDone('response.output_item.done'),
  responseContentPartAdded('response.content_part.added'),
  responseContentPartDone('response.content_part.done'),
  responseTextDelta('response.text.delta'),
  responseTextDone('response.text.done'),
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  responseAudioTranscriptDone('response.audio_transcript.done'),
  responseAudioDelta('response.audio.delta'),
  responseAudioDone('response.audio.done'),
  responseFunctionCallArgumentsDelta('response.function_call_arguments.delta'),
  responseFunctionCallArgumentsDone('response.function_call_arguments.done'),
  rateLimitsUpdated('rate_limits.updated');

  final String value;
  const ServerEventType(this.value);
}

/// Represents a function call from the AI
class FunctionCall {
  final String callId;
  final String name;
  final String arguments;

  FunctionCall({
    required this.callId,
    required this.name,
    required this.arguments,
  });
}

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

      // Configure session after connection
      await _configureSession();
      _lastError = null;
      logService.info(_tag, 'Connected and session configured');
    } catch (e) {
      logService.error(_tag, 'Connection failed: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  Future<void> _configureSession() async {
    logService.info(_tag, 'Configuring session with voice: ${AppConfig.defaultVoice}, tools: ${_tools.length}');
    
    final sessionConfig = {
      'modalities': ['text', 'audio'],
      'instructions': 'You are a helpful assistant. You have access to tools that can help you answer questions. Use them when appropriate.',
      'voice': AppConfig.defaultVoice,
      'input_audio_format': 'pcm16',
      'output_audio_format': 'pcm16',
      'input_audio_transcription': {
        'model': 'whisper-1',
      },
      'turn_detection': {
        'type': 'server_vad',
        'threshold': 0.5,
        'prefix_padding_ms': 300,
        'silence_duration_ms': 500,
      },
    };
    
    // Add tools if any are configured
    if (_tools.isNotEmpty) {
      sessionConfig['tools'] = _tools;
      sessionConfig['tool_choice'] = 'auto';
    }
    
    // Send session update with configuration
    _webSocket.send({
      'type': ClientEventType.sessionUpdate.value,
      'session': sessionConfig,
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'session.created':
        logService.info(_tag, 'Session created');
        break;
        
      case 'session.updated':
        logService.info(_tag, 'Session updated');
        break;
        
      case 'input_audio_buffer.speech_started':
        logService.info(_tag, 'Speech started (VAD detected)');
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
        }
        break;
        
      case 'response.created':
        logService.info(_tag, 'Response created - AI is generating response');
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
          logService.debug(_tag, 'Audio delta received (chunk #$_audioChunksReceived, ${audioData.length} bytes)');
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
          logService.debug(_tag, 'Transcript delta: $delta');
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
    await _webSocket.dispose();
  }
}
