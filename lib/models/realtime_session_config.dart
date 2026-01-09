/// Configuration for OpenAI Realtime API session
class RealtimeSessionConfig {
  /// Voice to use for audio output
  final String voice;

  /// Noise reduction type: 'near' (close-talk) or 'far' (far-field)
  final String noiseReduction;

  /// Tools registered with the session
  final List<Map<String, dynamic>> tools;

  /// System instructions (custom or default)
  final String instructions;

  /// Default system instructions
  static const String defaultInstructions = '''
あなたの名前はVaginaです。Voice AGI Notepad Agentの略です。
ユーザーとの音声会話を通じて、役立つアシスタントとして振る舞ってください。
日本語で応答し、親しみやすく自然な会話を心がけてください。
ツールを使って時刻を確認したり、情報を記憶したり、計算を行うことができます。
''';

  const RealtimeSessionConfig({
    this.voice = 'alloy',
    this.noiseReduction = 'near',
    this.tools = const [],
    this.instructions = defaultInstructions,
  });

  RealtimeSessionConfig copyWith({
    String? voice,
    String? noiseReduction,
    List<Map<String, dynamic>>? tools,
    String? instructions,
  }) {
    return RealtimeSessionConfig(
      voice: voice ?? this.voice,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      tools: tools ?? this.tools,
      instructions: instructions ?? this.instructions,
    );
  }

  /// Convert to session.update payload format for OpenAI Realtime API
  /// Reference: https://platform.openai.com/docs/api-reference/realtime-client-events/session/update
  /// Reference: https://platform.openai.com/docs/guides/realtime-transcription
  Map<String, dynamic> toSessionPayload() {
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
        // create_response: Automatically create a response when VAD detects end of speech
        'create_response': true,
        // interrupt_response: Allow user speech to interrupt an ongoing response
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
