import 'realtime_connection_state.dart';
import 'realtime_event.dart';

final class OaiRealtimeProtocolException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> payload;

  const OaiRealtimeProtocolException({
    required this.code,
    required this.message,
    required this.payload,
  });

  OaiRealtimeConnectionError toConnectionError() {
    return OaiRealtimeConnectionError(
      code: code,
      message: message,
      cause: payload,
    );
  }

  @override
  String toString() => 'OaiRealtimeProtocolException($code): $message';
}

final class OaiRealtimeEventParser {
  const OaiRealtimeEventParser();

  OaiRealtimeInboundEvent parse(Map<String, dynamic> payload) {
    final type = payload['type'];
    if (type is! String || type.isEmpty) {
      throw OaiRealtimeProtocolException(
        code: 'missing_type',
        message: 'Inbound realtime payload is missing a valid "type" field.',
        payload: payload,
      );
    }

    final eventId = payload['event_id'] as String?;
    final receivedAt = DateTime.now();
    final rawPayload = Map<String, dynamic>.unmodifiable(payload);

    switch (type) {
      case 'session.created':
        return OaiRealtimeSessionCreatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          session: OaiRealtimeSession.fromJson(_requireMap(payload, 'session')),
        );
      case 'session.updated':
        return OaiRealtimeSessionUpdatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          session: OaiRealtimeSession.fromJson(_requireMap(payload, 'session')),
        );
      case 'transcription_session.updated':
        return OaiRealtimeTranscriptionSessionUpdatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          session: Map<String, dynamic>.unmodifiable(
            _requireMap(payload, 'session'),
          ),
        );
      case 'conversation.created':
        return OaiRealtimeConversationCreatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          conversation: OaiRealtimeConversation.fromJson(
            _requireMap(payload, 'conversation'),
          ),
        );
      case 'conversation.item.created':
        return OaiRealtimeConversationItemCreatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          previousItemId: payload['previous_item_id'] as String?,
          item: OaiRealtimeConversationItem.fromJson(_requireMap(payload, 'item')),
        );
      case 'conversation.item.deleted':
        return OaiRealtimeConversationItemDeletedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
        );
      case 'conversation.item.input_audio_transcription.completed':
        return OaiRealtimeConversationItemInputAudioTranscriptionCompletedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          contentIndex: _asInt(payload['content_index']),
          transcript: payload['transcript'] as String?,
        );
      case 'conversation.item.input_audio_transcription.delta':
        return OaiRealtimeConversationItemInputAudioTranscriptionDeltaEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          contentIndex: _asInt(payload['content_index']),
          delta: payload['delta'] as String?,
        );
      case 'conversation.item.input_audio_transcription.failed':
        return OaiRealtimeConversationItemInputAudioTranscriptionFailedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          contentIndex: _asInt(payload['content_index']),
          error: payload['error'] is Map<String, dynamic>
              ? OaiRealtimeErrorDetail.fromJson(
                  payload['error'] as Map<String, dynamic>,
                )
              : null,
        );
      case 'conversation.item.truncated':
        return OaiRealtimeConversationItemTruncatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          contentIndex: _asInt(payload['content_index']),
          audioEndMs: _asInt(payload['audio_end_ms']),
        );
      case 'input_audio_buffer.committed':
        return OaiRealtimeInputAudioBufferCommittedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          previousItemId: payload['previous_item_id'] as String?,
        );
      case 'input_audio_buffer.cleared':
        return OaiRealtimeInputAudioBufferClearedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
        );
      case 'input_audio_buffer.dtmf_event_received':
        return OaiRealtimeInputAudioBufferDtmfEventReceivedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          digit: payload['digit'] as String?,
        );
      case 'input_audio_buffer.speech_started':
        return OaiRealtimeInputAudioBufferSpeechStartedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          audioStartMs: _asInt(payload['audio_start_ms']),
        );
      case 'input_audio_buffer.speech_stopped':
        return OaiRealtimeInputAudioBufferSpeechStoppedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          itemId: payload['item_id'] as String?,
          audioEndMs: _asInt(payload['audio_end_ms']),
        );
      case 'response.created':
        return OaiRealtimeResponseCreatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          response: OaiRealtimeResponse.fromJson(_requireMap(payload, 'response')),
        );
      case 'response.done':
        return OaiRealtimeResponseDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          response: OaiRealtimeResponse.fromJson(_requireMap(payload, 'response')),
        );
      case 'response.output_item.added':
        return OaiRealtimeResponseOutputItemAddedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          item: OaiRealtimeConversationItem.fromJson(_requireMap(payload, 'item')),
        );
      case 'response.output_item.done':
        return OaiRealtimeResponseOutputItemDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          item: OaiRealtimeConversationItem.fromJson(_requireMap(payload, 'item')),
        );
      case 'response.content_part.added':
        return OaiRealtimeResponseContentPartAddedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          part: OaiRealtimeContentPart.fromJson(_requireMap(payload, 'part')),
        );
      case 'response.content_part.done':
        return OaiRealtimeResponseContentPartDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          part: OaiRealtimeContentPart.fromJson(_requireMap(payload, 'part')),
        );
      case 'response.text.delta':
      case 'response.output_text.delta':
        return OaiRealtimeResponseOutputTextDeltaEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          delta: payload['delta'] as String?,
        );
      case 'response.text.done':
      case 'response.output_text.done':
        return OaiRealtimeResponseOutputTextDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          text: payload['text'] as String?,
        );
      case 'response.audio.delta':
      case 'response.output_audio.delta':
        return OaiRealtimeResponseOutputAudioDeltaEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          delta: payload['delta'] as String?,
        );
      case 'response.audio.done':
      case 'response.output_audio.done':
        return OaiRealtimeResponseOutputAudioDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
        );
      case 'response.audio_transcript.delta':
      case 'response.output_audio_transcript.delta':
        return OaiRealtimeResponseOutputAudioTranscriptDeltaEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          delta: payload['delta'] as String?,
        );
      case 'response.audio_transcript.done':
      case 'response.output_audio_transcript.done':
        return OaiRealtimeResponseOutputAudioTranscriptDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          contentIndex: _asInt(payload['content_index']),
          transcript: payload['transcript'] as String?,
        );
      case 'response.function_call_arguments.delta':
        return OaiRealtimeResponseFunctionCallArgumentsDeltaEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          callId: payload['call_id'] as String?,
          delta: payload['delta'] as String?,
        );
      case 'response.function_call_arguments.done':
        return OaiRealtimeResponseFunctionCallArgumentsDoneEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          responseId: payload['response_id'] as String?,
          itemId: payload['item_id'] as String?,
          outputIndex: _asInt(payload['output_index']),
          callId: payload['call_id'] as String?,
          name: payload['name'] as String?,
          arguments: payload['arguments'] as String?,
        );
      case 'rate_limits.updated':
        return OaiRealtimeRateLimitsUpdatedEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          rateLimits: _parseRateLimits(payload['rate_limits']),
        );
      case 'error':
        return OaiRealtimeErrorEvent(
          eventId: eventId,
          receivedAt: receivedAt,
          rawPayload: rawPayload,
          error: OaiRealtimeErrorDetail.fromJson(_requireMap(payload, 'error')),
        );
    }

    throw OaiRealtimeProtocolException(
      code: 'unsupported_event_type',
      message: 'Unsupported or disallowed realtime event type: $type',
      payload: payload,
    );
  }

  Map<String, dynamic> _requireMap(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw OaiRealtimeProtocolException(
      code: 'invalid_payload_shape',
      message: 'Expected "$key" to be an object for event ${payload['type']}.',
      payload: payload,
    );
  }

  int? _asInt(Object? value) {
    return switch (value) {
      int v => v,
      num v => v.toInt(),
      _ => null,
    };
  }

  List<OaiRealtimeRateLimit> _parseRateLimits(Object? value) {
    if (value is! List) {
      return const <OaiRealtimeRateLimit>[];
    }
    return value
        .whereType<Map>()
        .map((entry) => OaiRealtimeRateLimit.fromJson(
              Map<String, dynamic>.from(entry),
            ))
        .toList(growable: false);
  }
}
