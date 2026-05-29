/// API access selection for a voice agent available during a call session.
abstract class VoiceAgentApiConfig {
  const VoiceAgentApiConfig();
}

/// Provider selection for self-hosted voice agent APIs.
enum VoiceAgentProviderType {
  openai,
  gemini,
}

/// Use the application's hosted realtime voice API.
class HostedVoiceAgentApiConfig extends VoiceAgentApiConfig {
  final String modelId;

  const HostedVoiceAgentApiConfig({
    required this.modelId,
  });
}

/// Use a self-hosted or user-managed realtime voice API endpoint.
class SelfhostedVoiceAgentApiConfig extends VoiceAgentApiConfig {
  final VoiceAgentProviderType providerType;
  final String baseUrl;
  final String apiKey;
  final Map<String, Object?> params;

  const SelfhostedVoiceAgentApiConfig({
    required this.providerType,
    required this.baseUrl,
    required this.apiKey,
    this.params = const {},
  });
}
