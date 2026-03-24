/// API access selection for a text agent available during a call session.
abstract class TextAgentApiConfig {
  const TextAgentApiConfig();

  Map<String, dynamic> toJson();

  factory TextAgentApiConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'selfhosted':
        return SelfhostedTextAgentApiConfig.fromJson(json);
      case 'hosted':
        return HostedTextAgentApiConfig.fromJson(json);
      default:
        throw ArgumentError('Unknown TextAgentApiConfig type: $type');
    }
  }
}

/// Use a self-hosted or user-managed API endpoint.
class SelfhostedTextAgentApiConfig extends TextAgentApiConfig {
  final String provider;
  final String baseUrl;
  final String apiKey;
  final String model;
  final Map<String, Object?> params;

  const SelfhostedTextAgentApiConfig({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.params = const {},
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'selfhosted',
      'provider': provider,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'params': params,
    };
  }

  factory SelfhostedTextAgentApiConfig.fromJson(Map<String, dynamic> json) {
    return SelfhostedTextAgentApiConfig(
      provider: json['provider'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      model: json['model'] as String,
      params: json['params'] != null
          ? Map<String, Object?>.from(json['params'] as Map)
          : const {},
    );
  }
}

/// Use the application's hosted API.
class HostedTextAgentApiConfig extends TextAgentApiConfig {
  final String modelId;

  const HostedTextAgentApiConfig({
    required this.modelId,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'hosted',
      'modelId': modelId,
    };
  }

  factory HostedTextAgentApiConfig.fromJson(Map<String, dynamic> json) {
    return HostedTextAgentApiConfig(
      modelId: json['modelId'] as String,
    );
  }
}
