import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/azure_text_agent_config.dart';

/// Represents a configured text agent
class TextAgent {
  final String id;
  final String name;
  final String? description;
  final TextAgentConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TextAgent({
    required this.id,
    required this.name,
    this.description,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  TextAgent copyWith({
    String? id,
    String? name,
    String? description,
    TextAgentConfig? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TextAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'config': config.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TextAgent.fromJson(Map<String, dynamic> json) {
    final configJson = json['config'] as Map<String, dynamic>;
    
    // Try to parse as new format first, fall back to legacy Azure format
    TextAgentConfig config;
    if (configJson.containsKey('provider')) {
      // New format
      config = TextAgentConfig.fromJson(configJson);
    } else {
      // Legacy Azure format - migrate to new format
      final legacyConfig = AzureTextAgentConfig.fromJson(configJson);
      config = TextAgentConfig.fromLegacyAzure(
        endpoint: legacyConfig.endpoint,
        apiKey: legacyConfig.apiKey,
        deploymentName: legacyConfig.deploymentName,
      );
    }
    
    return TextAgent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      config: config,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
