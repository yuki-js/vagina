import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';

/// Self-contained configuration for a text agent available during a call.
class TextAgentInfo {
  final String id;
  final String name;
  final String description;
  final String? iconEmoji;
  final String prompt;
  final TextAgentApiConfig apiConfig;
  final List<String> enabledTools;

  const TextAgentInfo({
    required this.id,
    required this.name,
    required this.description,
    this.iconEmoji,
    required this.prompt,
    required this.apiConfig,
    this.enabledTools = const [],
  });
}
