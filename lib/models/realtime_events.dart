/// Events sent by the client to the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-client-events
/// 
/// Total: 12 client events
enum ClientEventType {
  /// Update the session configuration
  sessionUpdate('session.update'),
  
  /// Append audio data to the input audio buffer
  inputAudioBufferAppend('input_audio_buffer.append'),
  
  /// Commit the input audio buffer (used when VAD is disabled)
  inputAudioBufferCommit('input_audio_buffer.commit'),
  
  /// Clear the input audio buffer
  inputAudioBufferClear('input_audio_buffer.clear'),
  
  /// Clear the output audio buffer (WebRTC only)
  outputAudioBufferClear('output_audio_buffer.clear'),
  
  /// Create a new conversation item
  conversationItemCreate('conversation.item.create'),
  
  /// Truncate a conversation item (audio)
  conversationItemTruncate('conversation.item.truncate'),
  
  /// Delete a conversation item
  conversationItemDelete('conversation.item.delete'),
  
  /// Retrieve a conversation item
  conversationItemRetrieve('conversation.item.retrieve'),
  
  /// Create a new response
  responseCreate('response.create'),
  
  /// Cancel the current response
  responseCancel('response.cancel'),
  
  /// Update transcription session configuration
  transcriptionSessionUpdate('transcription_session.update');

  final String value;
  const ClientEventType(this.value);
}

/// Events received from the Azure OpenAI Realtime API
/// Reference: https://platform.openai.com/docs/api-reference/realtime-server-events
/// 
/// Total: 36 server events
enum ServerEventType {
  // ===== Error Events =====
  /// Error event - returned when an error occurs
  error('error'),
  
  // ===== Session Events =====
  /// Session created - emitted when a new connection is established
  sessionCreated('session.created'),
  
  /// Session updated - returned after a session.update event
  sessionUpdated('session.updated'),
  
  /// Transcription session updated - returned after a transcription_session.update event
  transcriptionSessionUpdated('transcription_session.updated'),
  
  // ===== Conversation Events =====
  /// Conversation created - emitted right after session creation
  conversationCreated('conversation.created'),
  
  /// Conversation item created - returned when a conversation item is created
  conversationItemCreated('conversation.item.created'),
  
  /// Conversation item deleted - returned when an item is deleted
  conversationItemDeleted('conversation.item.deleted'),
  
  /// Conversation item truncated - returned when an item is truncated
  conversationItemTruncated('conversation.item.truncated'),
  
  /// Conversation item retrieved - returned when an item is retrieved
  conversationItemRetrieved('conversation.item.retrieved'),
  
  // ===== Input Audio Transcription Events =====
  /// Input audio transcription completed - user's speech transcription is done
  conversationItemInputAudioTranscriptionCompleted(
      'conversation.item.input_audio_transcription.completed'),
  
  /// Input audio transcription delta - streaming transcription updates
  conversationItemInputAudioTranscriptionDelta(
      'conversation.item.input_audio_transcription.delta'),
  
  /// Input audio transcription failed - transcription request failed
  conversationItemInputAudioTranscriptionFailed(
      'conversation.item.input_audio_transcription.failed'),
  
  // ===== Input Audio Buffer Events =====
  /// Input audio buffer committed - audio buffer was committed
  inputAudioBufferCommitted('input_audio_buffer.committed'),
  
  /// Input audio buffer cleared - audio buffer was cleared
  inputAudioBufferCleared('input_audio_buffer.cleared'),
  
  /// Speech started - VAD detected speech in the audio buffer
  inputAudioBufferSpeechStarted('input_audio_buffer.speech_started'),
  
  /// Speech stopped - VAD detected end of speech
  inputAudioBufferSpeechStopped('input_audio_buffer.speech_stopped'),
  
  // ===== Output Audio Buffer Events (WebRTC only) =====
  /// Output audio buffer started - server began streaming audio (WebRTC only)
  outputAudioBufferStarted('output_audio_buffer.started'),
  
  /// Output audio buffer stopped - audio buffer drained (WebRTC only)
  outputAudioBufferStopped('output_audio_buffer.stopped'),
  
  /// Output audio buffer cleared - audio buffer was cleared (WebRTC only)
  outputAudioBufferCleared('output_audio_buffer.cleared'),
  
  // ===== Response Events =====
  /// Response created - a new response is being generated
  responseCreated('response.created'),
  
  /// Response done - response generation is complete
  responseDone('response.done'),
  
  // ===== Response Output Item Events =====
  /// Output item added - a new item is added during response generation
  responseOutputItemAdded('response.output_item.added'),
  
  /// Output item done - item streaming is complete
  responseOutputItemDone('response.output_item.done'),
  
  // ===== Response Content Part Events =====
  /// Content part added - a new content part is added to an item
  responseContentPartAdded('response.content_part.added'),
  
  /// Content part done - content part streaming is complete
  responseContentPartDone('response.content_part.done'),
  
  // ===== Response Text Events =====
  /// Text delta - streaming text content update
  responseTextDelta('response.text.delta'),
  
  /// Text done - text content streaming is complete
  responseTextDone('response.text.done'),
  
  // ===== Response Audio Transcript Events =====
  /// Audio transcript delta - streaming audio transcription update
  responseAudioTranscriptDelta('response.audio_transcript.delta'),
  
  /// Audio transcript done - audio transcription is complete
  responseAudioTranscriptDone('response.audio_transcript.done'),
  
  // ===== Response Audio Events =====
  /// Audio delta - streaming audio data
  responseAudioDelta('response.audio.delta'),
  
  /// Audio done - audio streaming is complete
  responseAudioDone('response.audio.done'),
  
  // ===== Response Function Call Events =====
  /// Function call arguments delta - streaming function call arguments
  responseFunctionCallArgumentsDelta('response.function_call_arguments.delta'),
  
  /// Function call arguments done - function call arguments complete
  responseFunctionCallArgumentsDone('response.function_call_arguments.done'),
  
  // ===== Rate Limits Events =====
  /// Rate limits updated - emitted at the beginning of a response
  rateLimitsUpdated('rate_limits.updated');

  final String value;
  const ServerEventType(this.value);
  
  /// Static map for O(1) lookup of event types by string value
  static final Map<String, ServerEventType> _valueMap = {
    for (final type in ServerEventType.values) type.value: type
  };
  
  /// Get ServerEventType from string value (O(1) lookup)
  static ServerEventType? fromString(String value) {
    return _valueMap[value];
  }
}

// =============================================================================
// Server Event Data Classes
// =============================================================================

/// Base class for all server events
abstract class ServerEvent {
  final String eventId;
  final String type;
  
  const ServerEvent({
    required this.eventId,
    required this.type,
  });
}

/// Error details from the API
class RealtimeError {
  final String type;
  final String? code;
  final String message;
  final String? param;
  final String? eventId;

  const RealtimeError({
    required this.type,
    this.code,
    required this.message,
    this.param,
    this.eventId,
  });

  factory RealtimeError.fromJson(Map<String, dynamic> json) {
    return RealtimeError(
      type: json['type'] as String? ?? 'unknown',
      code: json['code'] as String?,
      message: json['message'] as String? ?? 'Unknown error',
      param: json['param'] as String?,
      eventId: json['event_id'] as String?,
    );
  }
}

/// Represents a function call from the AI
class FunctionCall {
  final String callId;
  final String name;
  final String arguments;

  const FunctionCall({
    required this.callId,
    required this.name,
    required this.arguments,
  });
}

/// Rate limit information
class RateLimit {
  final String name;
  final int limit;
  final int remaining;
  final double resetSeconds;

  const RateLimit({
    required this.name,
    required this.limit,
    required this.remaining,
    required this.resetSeconds,
  });

  factory RateLimit.fromJson(Map<String, dynamic> json) {
    return RateLimit(
      name: json['name'] as String? ?? '',
      limit: json['limit'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? 0,
      resetSeconds: (json['reset_seconds'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Content part types
enum ContentPartType {
  text,
  audio,
  inputText,
  inputAudio,
}

/// Content part in a conversation item
class ContentPart {
  final String type;
  final String? text;
  final String? audio;
  final String? transcript;

  const ContentPart({
    required this.type,
    this.text,
    this.audio,
    this.transcript,
  });

  factory ContentPart.fromJson(Map<String, dynamic> json) {
    return ContentPart(
      type: json['type'] as String? ?? '',
      text: json['text'] as String?,
      audio: json['audio'] as String?,
      transcript: json['transcript'] as String?,
    );
  }
}

/// Conversation item in the API
class ConversationItem {
  final String id;
  final String object;
  final String type;
  final String? status;
  final String? role;
  final List<ContentPart> content;
  final String? callId;
  final String? name;
  final String? arguments;
  final String? output;

  const ConversationItem({
    required this.id,
    required this.object,
    required this.type,
    this.status,
    this.role,
    this.content = const [],
    this.callId,
    this.name,
    this.arguments,
    this.output,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    return ConversationItem(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.item',
      type: json['type'] as String? ?? '',
      status: json['status'] as String?,
      role: json['role'] as String?,
      content: contentList
          .map((c) => ContentPart.fromJson(c as Map<String, dynamic>))
          .toList(),
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
      output: json['output'] as String?,
    );
  }
}

/// Response usage information
class ResponseUsage {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final InputTokenDetails? inputTokenDetails;
  final OutputTokenDetails? outputTokenDetails;

  const ResponseUsage({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    this.inputTokenDetails,
    this.outputTokenDetails,
  });

  factory ResponseUsage.fromJson(Map<String, dynamic> json) {
    return ResponseUsage(
      totalTokens: json['total_tokens'] as int? ?? 0,
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
      inputTokenDetails: json['input_token_details'] != null
          ? InputTokenDetails.fromJson(
              json['input_token_details'] as Map<String, dynamic>)
          : null,
      outputTokenDetails: json['output_token_details'] != null
          ? OutputTokenDetails.fromJson(
              json['output_token_details'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Input token details
class InputTokenDetails {
  final int? cachedTokens;
  final int? textTokens;
  final int? audioTokens;

  const InputTokenDetails({
    this.cachedTokens,
    this.textTokens,
    this.audioTokens,
  });

  factory InputTokenDetails.fromJson(Map<String, dynamic> json) {
    return InputTokenDetails(
      cachedTokens: json['cached_tokens'] as int?,
      textTokens: json['text_tokens'] as int?,
      audioTokens: json['audio_tokens'] as int?,
    );
  }
}

/// Output token details
class OutputTokenDetails {
  final int? textTokens;
  final int? audioTokens;

  const OutputTokenDetails({
    this.textTokens,
    this.audioTokens,
  });

  factory OutputTokenDetails.fromJson(Map<String, dynamic> json) {
    return OutputTokenDetails(
      textTokens: json['text_tokens'] as int?,
      audioTokens: json['audio_tokens'] as int?,
    );
  }
}

/// Response object from the API
class RealtimeResponse {
  final String id;
  final String object;
  final String status;
  final Map<String, dynamic>? statusDetails;
  final List<ConversationItem> output;
  final ResponseUsage? usage;
  final String? conversationId;

  const RealtimeResponse({
    required this.id,
    required this.object,
    required this.status,
    this.statusDetails,
    this.output = const [],
    this.usage,
    this.conversationId,
  });

  factory RealtimeResponse.fromJson(Map<String, dynamic> json) {
    final outputList = json['output'] as List<dynamic>? ?? [];
    return RealtimeResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.response',
      status: json['status'] as String? ?? '',
      statusDetails: json['status_details'] as Map<String, dynamic>?,
      output: outputList
          .map((o) => ConversationItem.fromJson(o as Map<String, dynamic>))
          .toList(),
      usage: json['usage'] != null
          ? ResponseUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      conversationId: json['conversation_id'] as String?,
    );
  }
}

/// Session object from the API
class RealtimeSession {
  final String id;
  final String object;
  final String model;
  final List<String> modalities;
  final String? instructions;
  final String? voice;
  final String? inputAudioFormat;
  final String? outputAudioFormat;
  final Map<String, dynamic>? inputAudioTranscription;
  final Map<String, dynamic>? turnDetection;
  final List<Map<String, dynamic>> tools;
  final String? toolChoice;
  final double? temperature;
  final dynamic maxResponseOutputTokens;

  const RealtimeSession({
    required this.id,
    required this.object,
    required this.model,
    this.modalities = const ['text', 'audio'],
    this.instructions,
    this.voice,
    this.inputAudioFormat,
    this.outputAudioFormat,
    this.inputAudioTranscription,
    this.turnDetection,
    this.tools = const [],
    this.toolChoice,
    this.temperature,
    this.maxResponseOutputTokens,
  });

  factory RealtimeSession.fromJson(Map<String, dynamic> json) {
    final modalitiesList = json['modalities'] as List<dynamic>? ?? ['text', 'audio'];
    final toolsList = json['tools'] as List<dynamic>? ?? [];
    return RealtimeSession(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.session',
      model: json['model'] as String? ?? '',
      modalities: modalitiesList.map((m) => m.toString()).toList(),
      instructions: json['instructions'] as String?,
      voice: json['voice'] as String?,
      inputAudioFormat: json['input_audio_format'] as String?,
      outputAudioFormat: json['output_audio_format'] as String?,
      inputAudioTranscription:
          json['input_audio_transcription'] as Map<String, dynamic>?,
      turnDetection: json['turn_detection'] as Map<String, dynamic>?,
      tools: toolsList
          .map((t) => t as Map<String, dynamic>)
          .toList(),
      toolChoice: json['tool_choice'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxResponseOutputTokens: json['max_response_output_tokens'],
    );
  }
}

/// Conversation object from the API
class RealtimeConversation {
  final String id;
  final String object;

  const RealtimeConversation({
    required this.id,
    required this.object,
  });

  factory RealtimeConversation.fromJson(Map<String, dynamic> json) {
    return RealtimeConversation(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.conversation',
    );
  }
}
