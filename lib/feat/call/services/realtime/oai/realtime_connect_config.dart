/// Provider-specific connection configuration for the OpenAI Realtime binding.
///
/// This module lives under `realtime/oai` because it only understands the
/// OpenAI Realtime protocol family, including Azure OpenAI's compatible
/// transport shape.
sealed class OaiRealtimeConnectConfig {
  const OaiRealtimeConnectConfig();

  OaiRealtimeProvider get provider;
}

enum OaiRealtimeProvider {
  openAi,
  azureOpenAi,
}

final class OpenAiRealtimeConnectConfig extends OaiRealtimeConnectConfig {
  final String apiKey;
  final String model;
  final Uri? baseUri;
  final String? organization;
  final String? project;

  const OpenAiRealtimeConnectConfig({
    required this.apiKey,
    required this.model,
    this.baseUri,
    this.organization,
    this.project,
  });

  @override
  OaiRealtimeProvider get provider => OaiRealtimeProvider.openAi;
}

final class AzureOpenAiRealtimeConnectConfig extends OaiRealtimeConnectConfig {
  final String apiKey;
  final Uri endpoint;
  final String deployment;
  final String apiVersion;

  const AzureOpenAiRealtimeConnectConfig({
    required this.apiKey,
    required this.endpoint,
    required this.deployment,
    this.apiVersion = '2025-04-01-preview',
  });

  @override
  OaiRealtimeProvider get provider => OaiRealtimeProvider.azureOpenAi;
}
