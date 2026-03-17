/// API access selection for a text agent available during a call session.
abstract class TextAgentApiConfig {
  const TextAgentApiConfig();
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
}

/// Use the application's hosted API.
class HostedTextAgentApiConfig extends TextAgentApiConfig {
  final String modelId;

  const HostedTextAgentApiConfig({
    required this.modelId,
  });
}
