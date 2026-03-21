import 'package:vagina/feat/callv2/models/voice_agent_api_config.dart';

/// Self-contained configuration for the voice agent used in a call session.
class VoiceAgentInfo {
  final String id;
  final String name;
  final String description;
  final String? iconEmoji;
  final String voice;
  final String prompt;
  final VoiceAgentApiConfig apiConfig;
  final List<String> enabledTools;

  const VoiceAgentInfo({
    required this.id,
    required this.name,
    required this.description,
    this.iconEmoji,
    required this.voice,
    required this.prompt,
    required this.apiConfig,
    this.enabledTools = const [],
  });
}
