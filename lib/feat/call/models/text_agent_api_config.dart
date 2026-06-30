/// API access selection for a text agent available during a call session.
abstract class TextAgentApiConfig {
  const TextAgentApiConfig();

  Map<String, dynamic> toJson();

  factory TextAgentApiConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'serverBacked':
        return ServerBackedTextAgentApiConfig.fromJson(json);
      default:
        throw ArgumentError('Unknown TextAgentApiConfig type: $type');
    }
  }
}

/// Server-owned text-agent definition selected from the server model registry.
///
/// This intentionally carries only the safe public model preset identifier. It
/// does not expose private provider configuration to the client runtime.
class ServerBackedTextAgentApiConfig extends TextAgentApiConfig {
  final String textModelId;

  const ServerBackedTextAgentApiConfig({required this.textModelId});

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'serverBacked', 'textModelId': textModelId};
  }

  factory ServerBackedTextAgentApiConfig.fromJson(Map<String, dynamic> json) {
    return ServerBackedTextAgentApiConfig(
      textModelId: json['textModelId'] as String,
    );
  }
}
