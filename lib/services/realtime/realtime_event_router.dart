import 'package:vagina/services/log_service.dart';
import 'realtime_types.dart';
import 'session_handlers.dart';
import 'response_handlers.dart';

/// Routes incoming events to appropriate handlers
class RealtimeEventRouter {
  static const _tag = 'RealtimeAPI.Router';

  final SessionHandlers _sessionHandlers;
  final ResponseHandlers _responseHandlers;
  final LogService _log;

  RealtimeEventRouter({
    required SessionHandlers sessionHandlers,
    required ResponseHandlers responseHandlers,
    required LogService log,
  })  : _sessionHandlers = sessionHandlers,
        _responseHandlers = responseHandlers,
        _log = log;

  void routeEvent(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final eventId = message['event_id'] as String? ?? '';

    // Use ServerEventType enum to ensure we handle all events
    final eventType = ServerEventType.fromString(type ?? '');

    switch (eventType) {
      // ===== Session Events =====
      case ServerEventType.sessionCreated:
        _sessionHandlers.handleSessionCreated(message, eventId);

      case ServerEventType.sessionUpdated:
        _sessionHandlers.handleSessionUpdated(message, eventId);

      case ServerEventType.transcriptionSessionUpdated:
        _sessionHandlers.handleTranscriptionSessionUpdated(message, eventId);

      // ===== Conversation Events =====
      case ServerEventType.conversationCreated:
        _sessionHandlers.handleConversationCreated(message, eventId);

      case ServerEventType.conversationItemCreated:
        _sessionHandlers.handleConversationItemCreated(message, eventId);

      case ServerEventType.conversationItemDeleted:
        _sessionHandlers.handleConversationItemDeleted(message, eventId);

      case ServerEventType.conversationItemTruncated:
        _sessionHandlers.handleConversationItemTruncated(message, eventId);

      case ServerEventType.conversationItemRetrieved:
        _sessionHandlers.handleConversationItemRetrieved(message, eventId);

      // ===== Input Audio Transcription Events =====
      case ServerEventType.conversationItemInputAudioTranscriptionCompleted:
        _sessionHandlers.handleInputAudioTranscriptionCompleted(
            message, eventId);

      case ServerEventType.conversationItemInputAudioTranscriptionDelta:
        _sessionHandlers.handleInputAudioTranscriptionDelta(message, eventId);

      case ServerEventType.conversationItemInputAudioTranscriptionFailed:
        _sessionHandlers.handleInputAudioTranscriptionFailed(message, eventId);

      // ===== Input Audio Buffer Events =====
      case ServerEventType.inputAudioBufferCommitted:
        _sessionHandlers.handleInputAudioBufferCommitted(message, eventId);

      case ServerEventType.inputAudioBufferCleared:
        _sessionHandlers.handleInputAudioBufferCleared(message, eventId);

      case ServerEventType.inputAudioBufferSpeechStarted:
        _sessionHandlers.handleInputAudioBufferSpeechStarted(message, eventId);

      case ServerEventType.inputAudioBufferSpeechStopped:
        _sessionHandlers.handleInputAudioBufferSpeechStopped(message, eventId);

      // ===== Output Audio Buffer Events (WebRTC only) =====
      case ServerEventType.outputAudioBufferStarted:
        _responseHandlers.handleOutputAudioBufferStarted(message, eventId);

      case ServerEventType.outputAudioBufferStopped:
        _responseHandlers.handleOutputAudioBufferStopped(message, eventId);

      case ServerEventType.outputAudioBufferCleared:
        _responseHandlers.handleOutputAudioBufferCleared(message, eventId);

      // ===== Response Events =====
      case ServerEventType.responseCreated:
        _responseHandlers.handleResponseCreated(message, eventId);

      case ServerEventType.responseDone:
        _responseHandlers.handleResponseDone(message, eventId);

      // ===== Response Output Item Events =====
      case ServerEventType.responseOutputItemAdded:
        _responseHandlers.handleResponseOutputItemAdded(message, eventId);

      case ServerEventType.responseOutputItemDone:
        _responseHandlers.handleResponseOutputItemDone(message, eventId);

      // ===== Response Content Part Events =====
      case ServerEventType.responseContentPartAdded:
        _responseHandlers.handleResponseContentPartAdded(message, eventId);

      case ServerEventType.responseContentPartDone:
        _responseHandlers.handleResponseContentPartDone(message, eventId);

      // ===== Response Text Events =====
      case ServerEventType.responseTextDelta:
        _responseHandlers.handleResponseTextDelta(message, eventId);

      case ServerEventType.responseTextDone:
        _responseHandlers.handleResponseTextDone(message, eventId);

      // ===== Response Audio Transcript Events =====
      case ServerEventType.responseAudioTranscriptDelta:
        _responseHandlers.handleResponseAudioTranscriptDelta(message, eventId);

      case ServerEventType.responseAudioTranscriptDone:
        _responseHandlers.handleResponseAudioTranscriptDone(message, eventId);

      // ===== Response Audio Events =====
      case ServerEventType.responseAudioDelta:
        _responseHandlers.handleResponseAudioDelta(message, eventId);

      case ServerEventType.responseAudioDone:
        _responseHandlers.handleResponseAudioDone(message, eventId);

      // ===== Response Function Call Events =====
      case ServerEventType.responseFunctionCallArgumentsDelta:
        _responseHandlers.handleFunctionCallArgumentsDelta(message, eventId);

      case ServerEventType.responseFunctionCallArgumentsDone:
        _responseHandlers.handleFunctionCallArgumentsDone(message, eventId);

      // ===== Rate Limits Events =====
      case ServerEventType.rateLimitsUpdated:
        _responseHandlers.handleRateLimitsUpdated(message, eventId);

      // ===== Error Events =====
      case ServerEventType.error:
        _responseHandlers.handleError(message, eventId);

      case null:
        // Unknown event type - could be a new event type added by OpenAI
        // or a malformed message. Log for debugging but don't error.
        if (type == null || type.isEmpty) {
          _log.warn(_tag, 'Received message without event type');
        } else {
          _log.warn(_tag, 'Unknown/unhandled event type received: $type');
        }
    }
  }
}
