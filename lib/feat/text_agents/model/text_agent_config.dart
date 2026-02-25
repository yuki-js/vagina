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

  /// Returns true if [url] already looks like a full Azure Chat Completions URL.
  ///
  /// We intentionally keep this permissive (substring/URI-path based) to avoid
  /// misclassifying a full URL as a base endpoint and accidentally concatenating
  /// another `/openai/deployments/...` path onto it.
  static bool _looksLikeAzureChatCompletionsUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // If parsing fails, fall back to a simple check on the raw string.
      final lower = trimmed.toLowerCase();
      final hasHttpScheme =
          lower.startsWith('https://') || lower.startsWith('http://');
      return hasHttpScheme &&
          lower.contains('/openai/deployments/') &&
          lower.contains('/chat/completions');
    }

    final path = uri.path.toLowerCase();
    return path.contains('/openai/deployments/') &&
        path.contains('/chat/completions');
  }

  /// Try to extract Azure deployment name from a full Azure URL.
  static String? _tryExtractAzureDeploymentFromUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);

    // Prefer URI parsing when possible (avoids matching inside query strings).
    final path = uri?.path ?? trimmed.split('?').first;

    final match = RegExp(
      r'/openai/deployments/([^/]+)/',
      caseSensitive: false,
    ).firstMatch(path);

    return match?.group(1);
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
        // apiIdentifier may be either:
        // - base endpoint URL (e.g., https://{resource}.openai.azure.com)
        // - full Chat Completions URL (e.g., https://{resource}.openai.azure.com/openai/deployments/{deployment}/chat/completions?api-version=...)
        final trimmed = apiIdentifier.trim();
        if (_looksLikeAzureChatCompletionsUrl(trimmed)) {
          return trimmed;
        }

        // Fallback: treat as base endpoint URL.
        final base = trimmed.replaceAll(RegExp(r'/$'), '');
        return '$base/openai/deployments/default/chat/completions?api-version=2024-10-01-preview';
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
        // Azure identifies the model via the deployment name in the URL path.
        // If the user provided a full endpoint URL, extract it for better logging/debugging.
        return _tryExtractAzureDeploymentFromUrl(apiIdentifier) ?? 'gpt-4o';
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
