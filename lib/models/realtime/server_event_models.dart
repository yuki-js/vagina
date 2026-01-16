/// Server event data models for Azure OpenAI Realtime API
library;

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

/// Function call from the AI
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

/// Conversation item
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
  final int cachedTokens;
  final int textTokens;
  final int audioTokens;

  const InputTokenDetails({
    required this.cachedTokens,
    required this.textTokens,
    required this.audioTokens,
  });

  factory InputTokenDetails.fromJson(Map<String, dynamic> json) {
    return InputTokenDetails(
      cachedTokens: json['cached_tokens'] as int? ?? 0,
      textTokens: json['text_tokens'] as int? ?? 0,
      audioTokens: json['audio_tokens'] as int? ?? 0,
    );
  }
}

/// Output token details
class OutputTokenDetails {
  final int textTokens;
  final int audioTokens;

  const OutputTokenDetails({
    required this.textTokens,
    required this.audioTokens,
  });

  factory OutputTokenDetails.fromJson(Map<String, dynamic> json) {
    return OutputTokenDetails(
      textTokens: json['text_tokens'] as int? ?? 0,
      audioTokens: json['audio_tokens'] as int? ?? 0,
    );
  }
}

/// Realtime response information
class RealtimeResponse {
  final String id;
  final String object;
  final String status;
  final List<dynamic> output;
  final ResponseUsage? usage;

  const RealtimeResponse({
    required this.id,
    required this.object,
    required this.status,
    required this.output,
    this.usage,
  });

  factory RealtimeResponse.fromJson(Map<String, dynamic> json) {
    return RealtimeResponse(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.response',
      status: json['status'] as String? ?? '',
      output: json['output'] as List<dynamic>? ?? [],
      usage: json['usage'] != null
          ? ResponseUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Realtime session information
class RealtimeSession {
  final String id;
  final String object;
  final String model;
  final String? voice;
  final String? instructions;
  final Map<String, dynamic>? turnDetection;
  final List<dynamic> tools;

  const RealtimeSession({
    required this.id,
    required this.object,
    required this.model,
    this.voice,
    this.instructions,
    this.turnDetection,
    required this.tools,
  });

  factory RealtimeSession.fromJson(Map<String, dynamic> json) {
    return RealtimeSession(
      id: json['id'] as String? ?? '',
      object: json['object'] as String? ?? 'realtime.session',
      model: json['model'] as String? ?? '',
      voice: json['voice'] as String?,
      instructions: json['instructions'] as String?,
      turnDetection: json['turn_detection'] as Map<String, dynamic>?,
      tools: json['tools'] as List<dynamic>? ?? [],
    );
  }
}

/// Realtime conversation
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
