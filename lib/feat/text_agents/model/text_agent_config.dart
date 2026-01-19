import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';

/// Simplified configuration for a text agent supporting multiple providers
class TextAgentConfig {
  /// Provider type (OpenAI, Azure, LiteLLM, or Custom)
  final TextAgentProvider provider;

  /// API Key for authentication
  final String apiKey;

  /// Provider-specific identifier:
  /// - OpenAI: model name (e.g., "gpt-4o")
  /// - Azure: endpoint URL (e.g., "https://example.openai.azure.com")
  /// - LiteLLM: proxy URL (e.g., "http://localhost:4000")
  /// - Custom: endpoint URL (OpenAI-compatible)
  final String apiIdentifier;

  const TextAgentConfig({
    required this.provider,
    required this.apiKey,
    required this.apiIdentifier,
  });

  /// Get a display string for this config (for UI display)
  String getDisplayString() {
    switch (provider) {
      case TextAgentProvider.openai:
        return apiIdentifier; // Show model name
      case TextAgentProvider.azure:
        return 'Azure: ${_extractHostname(apiIdentifier)}';
      case TextAgentProvider.litellm:
        return 'LiteLLM: ${_extractHostname(apiIdentifier)}';
      case TextAgentProvider.custom:
        return _extractHostname(apiIdentifier);
    }
  }

  /// Extract hostname from URL for display
  static String _extractHostname(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  TextAgentConfig copyWith({
    TextAgentProvider? provider,
    String? apiKey,
    String? apiIdentifier,
  }) {
    return TextAgentConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      apiIdentifier: apiIdentifier ?? this.apiIdentifier,
    );
  }

  /// Get the API endpoint URL for making requests
  String getEndpointUrl() {
    switch (provider) {
      case TextAgentProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case TextAgentProvider.azure:
        // apiIdentifier contains the base endpoint URL
        return '$apiIdentifier/openai/deployments/default/chat/completions?api-version=2024-10-01-preview';
      case TextAgentProvider.litellm:
        // apiIdentifier contains the proxy URL
        return '${apiIdentifier.replaceAll(RegExp(r'/$'), '')}/chat/completions';
      case TextAgentProvider.custom:
        // apiIdentifier contains the endpoint URL
        return '${apiIdentifier.replaceAll(RegExp(r'/$'), '')}/chat/completions';
    }
  }

  /// Get the model name/identifier for the request
  String getModelIdentifier() {
    switch (provider) {
      case TextAgentProvider.openai:
        return apiIdentifier; // apiIdentifier is the model name
      case TextAgentProvider.azure:
        return 'gpt-4o'; // Azure uses deployment names, but model field is separate
      case TextAgentProvider.litellm:
        return 'gpt-4o'; // Default, can be overridden in request
      case TextAgentProvider.custom:
        return 'gpt-4o'; // Default, can be overridden in request
    }
  }

  /// Build request headers based on provider
  Map<String, String> getRequestHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    switch (provider) {
      case TextAgentProvider.openai:
        headers['Authorization'] = 'Bearer $apiKey';
        break;
      case TextAgentProvider.azure:
        headers['api-key'] = apiKey;
        break;
      case TextAgentProvider.litellm:
        headers['Authorization'] = 'Bearer $apiKey';
        break;
      case TextAgentProvider.custom:
        // Try both common header formats for custom endpoints
        headers['Authorization'] = 'Bearer $apiKey';
        headers['api-key'] = apiKey;
        break;
    }

    return headers;
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.value,
      'apiKey': apiKey,
      'apiIdentifier': apiIdentifier,
    };
  }

  factory TextAgentConfig.fromJson(Map<String, dynamic> json) {
    return TextAgentConfig(
      provider: TextAgentProvider.fromString(
        json['provider'] as String? ?? 'openai',
      ),
      apiKey: json['apiKey'] as String,
      apiIdentifier: json['apiIdentifier'] as String,
    );
  }

  /// Migrate from old AzureTextAgentConfig format
  factory TextAgentConfig.fromLegacyAzure({
    required String endpoint,
    required String apiKey,
    required String deploymentName,
  }) {
    return TextAgentConfig(
      provider: TextAgentProvider.azure,
      apiKey: apiKey,
      apiIdentifier: endpoint, // Store endpoint as apiIdentifier
    );
  }
}
