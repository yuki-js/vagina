
/// Models representing requests sent to the OpenAI Chat Completions API.
final class OaiCcRequest {
  final String model;
  final List<OaiCcMessage> messages;
  final bool stream;
  final List<String>? modalities;
  final Map<String, dynamic>? additionalParams;

  const OaiCcRequest({
    required this.model,
    required this.messages,
    this.stream = true,
    this.modalities,
    this.additionalParams,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': stream,
      if (modalities != null) 'modalities': modalities,
      ...?additionalParams,
    };
  }
}

abstract class OaiCcMessage {
  final String role;

  const OaiCcMessage({required this.role});

  Map<String, dynamic> toJson();
}

final class OaiCcTextMessage extends OaiCcMessage {
  final String content;

  const OaiCcTextMessage({
    required super.role,
    required this.content,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

final class OaiCcAudioMessage extends OaiCcMessage {
  /// Base64 encoded WAV audio bytes (e.g. PCM 16-bit 24kHz mono).
  final String audioBase64;
  final String format;

  const OaiCcAudioMessage({
    required super.role,
    required this.audioBase64,
    this.format = 'wav',
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': [
        {
          'type': 'input_audio',
          'input_audio': {
            'data': audioBase64,
            'format': format,
          },
        }
      ],
    };
  }
}

final class OaiCcAssistantAudioMessage extends OaiCcMessage {
  final String audioId;

  const OaiCcAssistantAudioMessage({
    required this.audioId,
  }) : super(role: 'assistant');

  @override
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'audio': {
        'id': audioId,
      },
    };
  }
}

