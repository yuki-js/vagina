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

/// Client for the Azure OpenAI Realtime API
class RealtimeApiClient {
  static const _tag = 'RealtimeAPI';
  
  final WebSocketService _webSocket = WebSocketService();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<void> _audioDoneController =
      StreamController<void>.broadcast();

  StreamSubscription? _messageSubscription;
  String? _lastError;
  int _audioChunksReceived = 0;
  int _audioChunksSent = 0;

  bool get isConnected => _webSocket.isConnected;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<void> get audioDoneStream => _audioDoneController.stream;
  String? get lastError => _lastError;

  /// Connect to Azure OpenAI using a full Realtime URL and API key
  /// URL format: https://{resource}.openai.azure.com/openai/realtime?api-version=YYYY-MM-DD&deployment=...
  Future<void> connect(String realtimeUrl, String apiKey) async {
    logService.info(_tag, 'Connecting to Azure OpenAI Realtime API');
    _audioChunksReceived = 0;
    _audioChunksSent = 0;
    
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
    logService.info(_tag, 'Configuring session with voice: ${AppConfig.defaultVoice}');
    // Send session update with configuration
    _webSocket.send({
      'type': ClientEventType.sessionUpdate.value,
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': 'You are a helpful assistant.',
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
      },
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
        
      case 'response.created':
        logService.info(_tag, 'Response created - AI is generating response');
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
    if (_audioChunksSent % 50 == 0) {
      // Log every 50 chunks to avoid log explosion
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
    await _errorController.close();
    await _audioDoneController.close();
    await _webSocket.dispose();
  }
}
