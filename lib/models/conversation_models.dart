/// Models for representing OpenAI Realtime API conversation structure
/// 
/// The conversation model hierarchy:
/// - Conversation: Top-level container for all items
/// - ConversationItem: A single item (message, function_call, function_call_output)
/// - ContentPart: A part of a message (text, audio, etc.)
/// - Response: An AI response containing multiple output items
/// - ResponseOutputItem: A single output item within a response

/// Represents a conversation item in the OpenAI Realtime API
/// Items can be messages (user/assistant), function calls, or function call outputs
class ConversationItem {
  final String id;
  final String? object; // 'realtime.item'
  final ItemType type;
  final ItemStatus status;
  final ItemRole? role; // For messages: 'user', 'assistant', 'system'
  final List<ContentPart> content;
  
  // For function_call items
  final String? callId;
  final String? name; // Function name
  final String? arguments; // Function arguments (JSON string)
  
  // For function_call_output items
  final String? output; // Function output

  ConversationItem({
    required this.id,
    this.object,
    required this.type,
    this.status = ItemStatus.completed,
    this.role,
    this.content = const [],
    this.callId,
    this.name,
    this.arguments,
    this.output,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'] as String? ?? '',
      object: json['object'] as String?,
      type: ItemType.fromString(json['type'] as String? ?? 'message'),
      status: ItemStatus.fromString(json['status'] as String? ?? 'completed'),
      role: json['role'] != null ? ItemRole.fromString(json['role'] as String) : null,
      content: (json['content'] as List?)
          ?.map((e) => ContentPart.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
      output: json['output'] as String?,
    );
  }

  ConversationItem copyWith({
    String? id,
    String? object,
    ItemType? type,
    ItemStatus? status,
    ItemRole? role,
    List<ContentPart>? content,
    String? callId,
    String? name,
    String? arguments,
    String? output,
  }) {
    return ConversationItem(
      id: id ?? this.id,
      object: object ?? this.object,
      type: type ?? this.type,
      status: status ?? this.status,
      role: role ?? this.role,
      content: content ?? this.content,
      callId: callId ?? this.callId,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      output: output ?? this.output,
    );
  }
}

/// Type of conversation item
enum ItemType {
  message('message'),
  functionCall('function_call'),
  functionCallOutput('function_call_output');

  final String value;
  const ItemType(this.value);

  static ItemType fromString(String value) {
    return ItemType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemType.message,
    );
  }
}

/// Status of a conversation item
enum ItemStatus {
  inProgress('in_progress'),
  completed('completed'),
  incomplete('incomplete');

  final String value;
  const ItemStatus(this.value);

  static ItemStatus fromString(String value) {
    return ItemStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemStatus.completed,
    );
  }
}

/// Role of a message item
enum ItemRole {
  user('user'),
  assistant('assistant'),
  system('system');

  final String value;
  const ItemRole(this.value);

  static ItemRole fromString(String value) {
    return ItemRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemRole.user,
    );
  }
}

/// Represents a content part within a conversation item
class ContentPart {
  final ContentType type;
  final String? text;
  final String? audio; // Base64 encoded audio
  final String? transcript;

  ContentPart({
    required this.type,
    this.text,
    this.audio,
    this.transcript,
  });

  factory ContentPart.fromJson(Map<String, dynamic> json) {
    return ContentPart(
      type: ContentType.fromString(json['type'] as String? ?? 'text'),
      text: json['text'] as String?,
      audio: json['audio'] as String?,
      transcript: json['transcript'] as String?,
    );
  }

  ContentPart copyWith({
    ContentType? type,
    String? text,
    String? audio,
    String? transcript,
  }) {
    return ContentPart(
      type: type ?? this.type,
      text: text ?? this.text,
      audio: audio ?? this.audio,
      transcript: transcript ?? this.transcript,
    );
  }
}

/// Type of content part
enum ContentType {
  inputText('input_text'),
  inputAudio('input_audio'),
  text('text'),
  audio('audio');

  final String value;
  const ContentType(this.value);

  static ContentType fromString(String value) {
    return ContentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ContentType.text,
    );
  }
}

/// Represents an AI response containing multiple output items
class Response {
  final String id;
  final String? object; // 'realtime.response'
  final ResponseStatus status;
  final ResponseStatusDetails? statusDetails;
  final List<ResponseOutputItem> output;
  final Usage? usage;

  Response({
    required this.id,
    this.object,
    this.status = ResponseStatus.inProgress,
    this.statusDetails,
    this.output = const [],
    this.usage,
  });

  factory Response.fromJson(Map<String, dynamic> json) {
    return Response(
      id: json['id'] as String? ?? '',
      object: json['object'] as String?,
      status: ResponseStatus.fromString(json['status'] as String? ?? 'in_progress'),
      statusDetails: json['status_details'] != null
          ? ResponseStatusDetails.fromJson(json['status_details'] as Map<String, dynamic>)
          : null,
      output: (json['output'] as List?)
          ?.map((e) => ResponseOutputItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      usage: json['usage'] != null
          ? Usage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Status of a response
enum ResponseStatus {
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  failed('failed'),
  incomplete('incomplete');

  final String value;
  const ResponseStatus(this.value);

  static ResponseStatus fromString(String value) {
    return ResponseStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ResponseStatus.inProgress,
    );
  }
}

/// Details about response status
class ResponseStatusDetails {
  final String? type;
  final String? reason;
  final Map<String, dynamic>? error;

  ResponseStatusDetails({
    this.type,
    this.reason,
    this.error,
  });

  factory ResponseStatusDetails.fromJson(Map<String, dynamic> json) {
    return ResponseStatusDetails(
      type: json['type'] as String?,
      reason: json['reason'] as String?,
      error: json['error'] as Map<String, dynamic>?,
    );
  }
}

/// Represents an output item within a response
class ResponseOutputItem {
  final String id;
  final String? object;
  final ItemType type;
  final ItemStatus status;
  final ItemRole? role;
  final List<ContentPart> content;
  final String? callId;
  final String? name;
  final String? arguments;

  ResponseOutputItem({
    required this.id,
    this.object,
    required this.type,
    this.status = ItemStatus.inProgress,
    this.role,
    this.content = const [],
    this.callId,
    this.name,
    this.arguments,
  });

  factory ResponseOutputItem.fromJson(Map<String, dynamic> json) {
    return ResponseOutputItem(
      id: json['id'] as String? ?? '',
      object: json['object'] as String?,
      type: ItemType.fromString(json['type'] as String? ?? 'message'),
      status: ItemStatus.fromString(json['status'] as String? ?? 'in_progress'),
      role: json['role'] != null ? ItemRole.fromString(json['role'] as String) : null,
      content: (json['content'] as List?)
          ?.map((e) => ContentPart.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
    );
  }
}

/// Token usage information
class Usage {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final InputTokenDetails? inputTokenDetails;
  final OutputTokenDetails? outputTokenDetails;

  Usage({
    this.totalTokens = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.inputTokenDetails,
    this.outputTokenDetails,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      totalTokens: json['total_tokens'] as int? ?? 0,
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
      inputTokenDetails: json['input_token_details'] != null
          ? InputTokenDetails.fromJson(json['input_token_details'] as Map<String, dynamic>)
          : null,
      outputTokenDetails: json['output_token_details'] != null
          ? OutputTokenDetails.fromJson(json['output_token_details'] as Map<String, dynamic>)
          : null,
    );
  }
}

class InputTokenDetails {
  final int cachedTokens;
  final int textTokens;
  final int audioTokens;

  InputTokenDetails({
    this.cachedTokens = 0,
    this.textTokens = 0,
    this.audioTokens = 0,
  });

  factory InputTokenDetails.fromJson(Map<String, dynamic> json) {
    return InputTokenDetails(
      cachedTokens: json['cached_tokens'] as int? ?? 0,
      textTokens: json['text_tokens'] as int? ?? 0,
      audioTokens: json['audio_tokens'] as int? ?? 0,
    );
  }
}

class OutputTokenDetails {
  final int textTokens;
  final int audioTokens;

  OutputTokenDetails({
    this.textTokens = 0,
    this.audioTokens = 0,
  });

  factory OutputTokenDetails.fromJson(Map<String, dynamic> json) {
    return OutputTokenDetails(
      textTokens: json['text_tokens'] as int? ?? 0,
      audioTokens: json['audio_tokens'] as int? ?? 0,
    );
  }
}

/// Rate limit information
class RateLimit {
  final String name;
  final int limit;
  final int remaining;
  final double resetSeconds;

  RateLimit({
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

/// Error information from the API
class RealtimeError {
  final String type;
  final String? code;
  final String message;
  final String? param;
  final String? eventId;

  RealtimeError({
    required this.type,
    this.code,
    required this.message,
    this.param,
    this.eventId,
  });

  factory RealtimeError.fromJson(Map<String, dynamic> json) {
    return RealtimeError(
      type: json['type'] as String? ?? 'error',
      code: json['code'] as String?,
      message: json['message'] as String? ?? 'Unknown error',
      param: json['param'] as String?,
      eventId: json['event_id'] as String?,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    if (code != null) {
      buffer.write('[$code] ');
    }
    buffer.write(message);
    return buffer.toString();
  }
}
