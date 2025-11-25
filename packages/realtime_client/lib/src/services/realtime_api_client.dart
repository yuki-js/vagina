import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:vagina_core/vagina_core.dart';
import 'websocket_service.dart';

/// Events sent by the client to the OpenAI Realtime API
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

/// Events received from the OpenAI Realtime API
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

/// Client for the OpenAI Realtime API
class RealtimeApiClient {
  final WebSocketService _webSocket = WebSocketService();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  StreamSubscription? _messageSubscription;

  bool get isConnected => _webSocket.isConnected;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Connect to the OpenAI Realtime API
  Future<void> connect(String apiKey) async {
    const url = AppConfig.realtimeApiUrl;
    
    // Note: WebSocket headers are handled differently in web vs native
    // For now, we'll use the URL with the API key
    await _webSocket.connect(url);

    _messageSubscription = _webSocket.messages.listen(_handleMessage);

    // Configure session after connection
    await _configureSession(apiKey);
  }

  Future<void> _configureSession(String apiKey) async {
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
      case 'response.audio.delta':
        final delta = message['delta'] as String?;
        if (delta != null) {
          final audioData = base64Decode(delta);
          _audioController.add(Uint8List.fromList(audioData));
        }
        break;

      case 'response.audio_transcript.delta':
        final delta = message['delta'] as String?;
        if (delta != null) {
          _transcriptController.add(delta);
        }
        break;

      case 'error':
        final error = message['error'] as Map<String, dynamic>?;
        final errorMessage = error?['message'] as String? ?? 'Unknown error';
        _errorController.add(errorMessage);
        break;
    }
  }

  /// Send audio data to the API
  void sendAudio(Uint8List audioData) {
    if (!isConnected) return;

    final base64Audio = base64Encode(audioData);
    _webSocket.send({
      'type': ClientEventType.inputAudioBufferAppend.value,
      'audio': base64Audio,
    });
  }

  /// Commit the current audio buffer
  void commitAudioBuffer() {
    if (!isConnected) return;

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
    if (!isConnected) return;

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
    await _webSocket.dispose();
  }
}
