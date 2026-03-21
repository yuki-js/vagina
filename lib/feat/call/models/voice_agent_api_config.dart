/// API access selection for a voice agent available during a call session.
abstract class VoiceAgentApiConfig {
  const VoiceAgentApiConfig();
}

/// Provider type enum for voice agent APIs.
enum VoiceAgentProviderType {
  openai,
  azureOpenAi,
  gemini,
  unknown,
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
  final String model;
  final Map<String, Object?> params;

  const SelfhostedVoiceAgentApiConfig({
    required this.providerType,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.params = const {},
  });
}
