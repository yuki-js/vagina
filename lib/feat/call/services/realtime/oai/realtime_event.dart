final class OaiRealtimeConversation {
  final String id;
  final String object;
  final Map<String, dynamic> rawJson;

  OaiRealtimeConversation({
    required this.id,
    required this.object,
    required this.rawJson,
  });

  factory OaiRealtimeConversation.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeConversation(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.conversation',
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeSession {
  final String id;
  final String object;
  final String? model;
  final String? voice;
  final String? instructions;
  final Map<String, dynamic> rawJson;

  OaiRealtimeSession({
    required this.id,
    required this.object,
    required this.model,
    required this.voice,
    required this.instructions,
    required this.rawJson,
  });

  factory OaiRealtimeSession.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeSession(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.session',
      model: json['model'] as String?,
      voice: json['voice'] as String?,
      instructions: json['instructions'] as String?,
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeRateLimit {
  final String name;
  final int? limit;
  final int? remaining;
  final double? resetSeconds;
  final Map<String, dynamic> rawJson;

  OaiRealtimeRateLimit({
    required this.name,
    required this.limit,
    required this.remaining,
    required this.resetSeconds,
    required this.rawJson,
  });

  factory OaiRealtimeRateLimit.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeRateLimit(
      name: json['name'] as String? ?? '',
      limit: (json['limit'] as num?)?.toInt(),
      remaining: (json['remaining'] as num?)?.toInt(),
      resetSeconds: (json['reset_seconds'] as num?)?.toDouble(),
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeErrorDetail {
  final String type;
  final String? code;
  final String message;
  final String? param;
  final String? eventId;
  final Map<String, dynamic> rawJson;

  OaiRealtimeErrorDetail({
    required this.type,
    required this.code,
    required this.message,
    required this.param,
    required this.eventId,
    required this.rawJson,
  });

  factory OaiRealtimeErrorDetail.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeErrorDetail(
      type: json['type'] as String? ?? 'unknown',
      code: json['code'] as String?,
      message: json['message'] as String? ?? 'Unknown error',
      param: json['param'] as String?,
      eventId: json['event_id'] as String?,
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeContentPart {
  final String type;
  final String? text;
  final String? audio;
  final String? transcript;
  final String? detail;
  final String? imageUrl;
  final Map<String, dynamic> rawJson;

  OaiRealtimeContentPart({
    required this.type,
    required this.text,
    required this.audio,
    required this.transcript,
    required this.detail,
    required this.imageUrl,
    required this.rawJson,
  });

  factory OaiRealtimeContentPart.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeContentPart(
      type: json['type'] as String? ?? '',
      text: json['text'] as String?,
      audio: json['audio'] as String?,
      transcript: json['transcript'] as String?,
      detail: json['detail'] as String?,
      imageUrl: json['image_url'] as String?,
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeConversationItem {
  final String id;
  final String object;
  final String type;
  final String? status;
  final String? role;
  final List<OaiRealtimeContentPart> content;
  final String? callId;
  final String? name;
  final String? arguments;
  final String? output;
  final Map<String, dynamic> rawJson;

  OaiRealtimeConversationItem({
    required this.id,
    required this.object,
    required this.type,
    required this.status,
    required this.role,
    required this.content,
    required this.callId,
    required this.name,
    required this.arguments,
    required this.output,
    required this.rawJson,
  });

  factory OaiRealtimeConversationItem.fromJson(Map<String, dynamic> json) {
    final contentJson = json['content'];
    final content = contentJson is List
        ? contentJson
            .whereType<Map>()
            .map((entry) =>
                OaiRealtimeContentPart.fromJson(Map<String, dynamic>.from(entry)))
            .toList(growable: false)
        : const <OaiRealtimeContentPart>[];

    return OaiRealtimeConversationItem(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.item',
      type: json['type'] as String? ?? '',
      status: json['status'] as String?,
      role: json['role'] as String?,
      content: content,
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
      output: json['output'] as String?,
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

final class OaiRealtimeResponse {
  final String id;
  final String object;
  final String? status;
  final String? conversationId;
  final List<dynamic> output;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic> rawJson;

  OaiRealtimeResponse({
    required this.id,
    required this.object,
    required this.status,
    required this.conversationId,
    required this.output,
    required this.usage,
    required this.rawJson,
  });

  factory OaiRealtimeResponse.fromJson(Map<String, dynamic> json) {
    return OaiRealtimeResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.response',
      status: json['status'] as String?,
      conversationId: json['conversation_id'] as String?,
      output: List.unmodifiable((json['output'] as List?) ?? const []),
      usage: json['usage'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(
              json['usage'] as Map<String, dynamic>,
            )
          : null,
      rawJson: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

sealed class OaiRealtimeInboundEvent {
  final String type;
  final String? eventId;
  final DateTime receivedAt;
  final Map<String, dynamic> rawPayload;

  const OaiRealtimeInboundEvent({
    required this.type,
    required this.eventId,
    required this.receivedAt,
    required this.rawPayload,
  });
}

sealed class OaiRealtimeSessionEvent extends OaiRealtimeInboundEvent {
  final OaiRealtimeSession session;

  const OaiRealtimeSessionEvent({
    required super.type,
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.session,
  });
}

final class OaiRealtimeSessionCreatedEvent extends OaiRealtimeSessionEvent {
  const OaiRealtimeSessionCreatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.session,
  }) : super(type: 'session.created');
}

final class OaiRealtimeSessionUpdatedEvent extends OaiRealtimeSessionEvent {
  const OaiRealtimeSessionUpdatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.session,
  }) : super(type: 'session.updated');
}

final class OaiRealtimeTranscriptionSessionUpdatedEvent
    extends OaiRealtimeInboundEvent {
  final Map<String, dynamic> session;

  const OaiRealtimeTranscriptionSessionUpdatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.session,
  }) : super(type: 'transcription_session.updated');
}

final class OaiRealtimeConversationCreatedEvent
    extends OaiRealtimeInboundEvent {
  final OaiRealtimeConversation conversation;

  const OaiRealtimeConversationCreatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.conversation,
  }) : super(type: 'conversation.created');
}

final class OaiRealtimeConversationItemCreatedEvent
    extends OaiRealtimeInboundEvent {
  final String? previousItemId;
  final OaiRealtimeConversationItem item;

  const OaiRealtimeConversationItemCreatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.previousItemId,
    required this.item,
  }) : super(type: 'conversation.item.created');
}

final class OaiRealtimeConversationItemDeletedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;

  const OaiRealtimeConversationItemDeletedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
  }) : super(type: 'conversation.item.deleted');
}

final class OaiRealtimeConversationItemInputAudioTranscriptionCompletedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? contentIndex;
  final String? transcript;

  const OaiRealtimeConversationItemInputAudioTranscriptionCompletedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.contentIndex,
    required this.transcript,
  }) : super(type: 'conversation.item.input_audio_transcription.completed');
}

final class OaiRealtimeConversationItemInputAudioTranscriptionDeltaEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? contentIndex;
  final String? delta;

  const OaiRealtimeConversationItemInputAudioTranscriptionDeltaEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  }) : super(type: 'conversation.item.input_audio_transcription.delta');
}

final class OaiRealtimeConversationItemInputAudioTranscriptionFailedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? contentIndex;
  final OaiRealtimeErrorDetail? error;

  const OaiRealtimeConversationItemInputAudioTranscriptionFailedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.contentIndex,
    required this.error,
  }) : super(type: 'conversation.item.input_audio_transcription.failed');
}

final class OaiRealtimeConversationItemTruncatedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? contentIndex;
  final int? audioEndMs;

  const OaiRealtimeConversationItemTruncatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.contentIndex,
    required this.audioEndMs,
  }) : super(type: 'conversation.item.truncated');
}

final class OaiRealtimeInputAudioBufferCommittedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final String? previousItemId;

  const OaiRealtimeInputAudioBufferCommittedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.previousItemId,
  }) : super(type: 'input_audio_buffer.committed');
}

final class OaiRealtimeInputAudioBufferClearedEvent
    extends OaiRealtimeInboundEvent {
  const OaiRealtimeInputAudioBufferClearedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
  }) : super(type: 'input_audio_buffer.cleared');
}

final class OaiRealtimeInputAudioBufferDtmfEventReceivedEvent
    extends OaiRealtimeInboundEvent {
  final String? digit;

  const OaiRealtimeInputAudioBufferDtmfEventReceivedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.digit,
  }) : super(type: 'input_audio_buffer.dtmf_event_received');
}

final class OaiRealtimeInputAudioBufferSpeechStartedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? audioStartMs;

  const OaiRealtimeInputAudioBufferSpeechStartedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.audioStartMs,
  }) : super(type: 'input_audio_buffer.speech_started');
}

final class OaiRealtimeInputAudioBufferSpeechStoppedEvent
    extends OaiRealtimeInboundEvent {
  final String? itemId;
  final int? audioEndMs;

  const OaiRealtimeInputAudioBufferSpeechStoppedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.itemId,
    required this.audioEndMs,
  }) : super(type: 'input_audio_buffer.speech_stopped');
}

sealed class OaiRealtimeResponseEvent extends OaiRealtimeInboundEvent {
  final OaiRealtimeResponse response;

  const OaiRealtimeResponseEvent({
    required super.type,
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.response,
  });
}

final class OaiRealtimeResponseCreatedEvent extends OaiRealtimeResponseEvent {
  const OaiRealtimeResponseCreatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.response,
  }) : super(type: 'response.created');
}

final class OaiRealtimeResponseDoneEvent extends OaiRealtimeResponseEvent {
  const OaiRealtimeResponseDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.response,
  }) : super(type: 'response.done');
}

sealed class OaiRealtimeResponseItemEvent extends OaiRealtimeInboundEvent {
  final String? responseId;
  final int? outputIndex;
  final OaiRealtimeConversationItem item;

  const OaiRealtimeResponseItemEvent({
    required super.type,
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.outputIndex,
    required this.item,
  });
}

final class OaiRealtimeResponseOutputItemAddedEvent
    extends OaiRealtimeResponseItemEvent {
  const OaiRealtimeResponseOutputItemAddedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.responseId,
    required super.outputIndex,
    required super.item,
  }) : super(type: 'response.output_item.added');
}

final class OaiRealtimeResponseOutputItemDoneEvent
    extends OaiRealtimeResponseItemEvent {
  const OaiRealtimeResponseOutputItemDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.responseId,
    required super.outputIndex,
    required super.item,
  }) : super(type: 'response.output_item.done');
}

sealed class OaiRealtimeResponseContentPartEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final OaiRealtimeContentPart part;

  const OaiRealtimeResponseContentPartEvent({
    required super.type,
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.part,
  });
}

final class OaiRealtimeResponseContentPartAddedEvent
    extends OaiRealtimeResponseContentPartEvent {
  const OaiRealtimeResponseContentPartAddedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.responseId,
    required super.itemId,
    required super.outputIndex,
    required super.contentIndex,
    required super.part,
  }) : super(type: 'response.content_part.added');
}

final class OaiRealtimeResponseContentPartDoneEvent
    extends OaiRealtimeResponseContentPartEvent {
  const OaiRealtimeResponseContentPartDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required super.responseId,
    required super.itemId,
    required super.outputIndex,
    required super.contentIndex,
    required super.part,
  }) : super(type: 'response.content_part.done');
}

final class OaiRealtimeResponseOutputTextDeltaEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final String? delta;

  const OaiRealtimeResponseOutputTextDeltaEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.delta,
  }) : super(type: 'response.output_text.delta');
}

final class OaiRealtimeResponseOutputTextDoneEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final String? text;

  const OaiRealtimeResponseOutputTextDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.text,
  }) : super(type: 'response.output_text.done');
}

final class OaiRealtimeResponseOutputAudioDeltaEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final String? delta;

  const OaiRealtimeResponseOutputAudioDeltaEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.delta,
  }) : super(type: 'response.output_audio.delta');
}

final class OaiRealtimeResponseOutputAudioDoneEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;

  const OaiRealtimeResponseOutputAudioDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
  }) : super(type: 'response.output_audio.done');
}

final class OaiRealtimeResponseOutputAudioTranscriptDeltaEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final String? delta;

  const OaiRealtimeResponseOutputAudioTranscriptDeltaEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.delta,
  }) : super(type: 'response.output_audio_transcript.delta');
}

final class OaiRealtimeResponseOutputAudioTranscriptDoneEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final int? contentIndex;
  final String? transcript;

  const OaiRealtimeResponseOutputAudioTranscriptDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.transcript,
  }) : super(type: 'response.output_audio_transcript.done');
}

final class OaiRealtimeResponseFunctionCallArgumentsDeltaEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final String? callId;
  final String? delta;

  const OaiRealtimeResponseFunctionCallArgumentsDeltaEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.callId,
    required this.delta,
  }) : super(type: 'response.function_call_arguments.delta');
}

final class OaiRealtimeResponseFunctionCallArgumentsDoneEvent
    extends OaiRealtimeInboundEvent {
  final String? responseId;
  final String? itemId;
  final int? outputIndex;
  final String? callId;
  final String? name;
  final String? arguments;

  const OaiRealtimeResponseFunctionCallArgumentsDoneEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.callId,
    required this.name,
    required this.arguments,
  }) : super(type: 'response.function_call_arguments.done');
}

final class OaiRealtimeRateLimitsUpdatedEvent extends OaiRealtimeInboundEvent {
  final List<OaiRealtimeRateLimit> rateLimits;

  const OaiRealtimeRateLimitsUpdatedEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.rateLimits,
  }) : super(type: 'rate_limits.updated');
}

final class OaiRealtimeErrorEvent extends OaiRealtimeInboundEvent {
  final OaiRealtimeErrorDetail error;

  const OaiRealtimeErrorEvent({
    required super.eventId,
    required super.receivedAt,
    required super.rawPayload,
    required this.error,
  }) : super(type: 'error');
}
