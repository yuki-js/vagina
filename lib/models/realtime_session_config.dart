/// Configuration for OpenAI Realtime API session
class RealtimeSessionConfig {
  /// Voice to use for audio output
  final String voice;
  
  /// Noise reduction type: 'near' (close-talk) or 'far' (far-field)
  final String noiseReduction;
  
  /// Tools registered with the session
  final List<Map<String, dynamic>> tools;

  const RealtimeSessionConfig({
    this.voice = 'alloy',
    this.noiseReduction = 'near',
    this.tools = const [],
  });

  RealtimeSessionConfig copyWith({
    String? voice,
    String? noiseReduction,
    List<Map<String, dynamic>>? tools,
  }) {
    return RealtimeSessionConfig(
      voice: voice ?? this.voice,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      tools: tools ?? this.tools,
    );
  }

  /// Convert to session.update payload format for OpenAI Realtime API
  /// Reference: https://platform.openai.com/docs/api-reference/realtime-client-events/session/update
  /// Reference: https://platform.openai.com/docs/guides/realtime-transcription
  Map<String, dynamic> toSessionPayload(String instructions) {
    final config = <String, dynamic>{
      'modalities': ['text', 'audio'],
      'instructions': instructions,
      'voice': voice,
      'input_audio_format': 'pcm16',
      'output_audio_format': 'pcm16',
      'input_audio_transcription': {
        'model': 'gpt-4o-transcribe',
      },
      'turn_detection': {
        'type': 'semantic_vad',
        'eagerness': 'low',
        'create_response': true,
        'interrupt_response': true,
      },
    };
    
    // Add tools if any are configured
    if (tools.isNotEmpty) {
      config['tools'] = tools;
      config['tool_choice'] = 'auto';
    }
    
    return config;
  }
}
