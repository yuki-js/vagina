import 'package:vagina/feat/call/models/text_agent_api_config.dart';

/// Self-contained configuration for a text agent available during a call.
class TextAgentInfo {
  final String id;
  final String name;
  final String description;
  final String? iconEmoji;
  final String prompt;
  final TextAgentApiConfig apiConfig;
  final Map<String, bool> enabledTools;

  const TextAgentInfo({
    required this.id,
    required this.name,
    required this.description,
    this.iconEmoji,
    required this.prompt,
    required this.apiConfig,
    this.enabledTools = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      if (iconEmoji != null) 'iconEmoji': iconEmoji,
      'prompt': prompt,
      'apiConfig': apiConfig.toJson(),
      'enabledTools': enabledTools,
    };
  }

  factory TextAgentInfo.fromJson(Map<String, dynamic> json) {
    return TextAgentInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      iconEmoji: json['iconEmoji'] as String?,
      prompt: json['prompt'] as String? ?? '',
      apiConfig: TextAgentApiConfig.fromJson(
        json['apiConfig'] as Map<String, dynamic>,
      ),
      enabledTools: json['enabledTools'] != null
          ? Map<String, bool>.from(json['enabledTools'] as Map)
          : const {},
    );
  }
}
