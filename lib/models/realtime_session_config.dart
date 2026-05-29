import 'package:vagina/services/tools_runtime/tool.dart';

/// Configuration for OpenAI Realtime API session
class RealtimeSessionConfig {
  /// Voice to use for audio output
  final String voice;

  /// Noise reduction type: 'near' (close-talk) or 'far' (far-field)
  final String noiseReduction;

  /// Tools registered with the session
  final List<Tool> tools;

  /// System instructions
  final String instructions;

  const RealtimeSessionConfig({
    this.voice = 'alloy',
    this.noiseReduction = 'near',
    this.tools = const [],
    this.instructions = '',
  });

  RealtimeSessionConfig copyWith({
    String? voice,
    String? noiseReduction,
    List<Tool>? tools,
    String? instructions,
  }) {
    return RealtimeSessionConfig(
      voice: voice ?? this.voice,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      tools: tools ?? this.tools,
      instructions: instructions ?? this.instructions,
    );
  }
}
