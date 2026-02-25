import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';

/// Utility class for parsing and validating LLM provider URLs
class ProviderParser {
  /// Parse a URL to detect the provider type
  ///
  /// Returns the detected provider type based on the URL hostname
  static TextAgentProvider detectProvider(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Detect based on hostname patterns
      if (host.contains('openai.com') && !host.contains('azure')) {
        return TextAgentProvider.openai;
      }
      if (host.contains('azure') && host.contains('openai')) {
        return TextAgentProvider.azure;
      }

      // If not recognized, default to custom
      return TextAgentProvider.custom;
    } catch (_) {
      return TextAgentProvider.custom;
    }
  }

  /// Validate URL format for a given provider
  ///
  /// Returns error message if invalid, null if valid
  static String? validateUrl(String url, TextAgentProvider provider) {
    if (url.trim().isEmpty) {
      return 'URLを入力してください';
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '有効なURLを入力してください';
    }

    // Allow http for localhost/development, https for production
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'HTTP/HTTPSのURLを入力してください';
    }

    // For Azure, check basic Azure URL pattern
    if (provider == TextAgentProvider.azure) {
      if (!uri.host.contains('openai') || !uri.host.contains('azure')) {
        return 'Azure OpenAIのURLが正しくない可能性があります';
      }
    }

    return null;
  }

  /// Extract information from an Azure URL
  ///
  /// Returns a map with extracted values:
  /// - resource: Azure resource name (e.g., "myresource")
  /// - deployment: Deployment ID (e.g., "gpt-4")
  /// - version: API version (e.g., "2024-10-01-preview")
  static Map<String, String?> parseAzureUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Expected: /openai/deployments/{deployment-id}/chat/completions
      String? deployment;
      if (pathSegments.length >= 3 &&
          pathSegments[0] == 'openai' &&
          pathSegments[1] == 'deployments') {
        deployment = pathSegments[2];
      }

      // Extract resource name from host
      // Format: {resource}.openai.azure.com
      String? resource;
      final hostParts = uri.host.split('.');
      if (hostParts.isNotEmpty && hostParts[0].isNotEmpty) {
        resource = hostParts[0];
      }

      // Extract API version from query parameters
      final version = uri.queryParameters['api-version'];

      return {
        'resource': resource,
        'deployment': deployment,
        'version': version,
      };
    } catch (_) {
      return {
        'resource': null,
        'deployment': null,
        'version': null,
      };
    }
  }

  /// Get help text for a provider
  static String getProviderHelpText(TextAgentProvider provider) {
    switch (provider) {
      case TextAgentProvider.openai:
        return 'OpenAIの公式API。api.openai.comを使用します。';
      case TextAgentProvider.azure:
        return 'Azure OpenAI Service。リソース固有のエンドポイントを指定します。';
      case TextAgentProvider.litellm:
        return 'LiteLLMプロキシサービス。ローカルまたはリモートのプロキシURLを指定します。';
      case TextAgentProvider.custom:
        return 'OpenAI互換のカスタムエンドポイント。完全なURLを指定します。';
    }
  }

  /// Get example URL for a provider
  static String getExampleUrl(TextAgentProvider provider) {
    switch (provider) {
      case TextAgentProvider.openai:
        return 'gpt-4o';
      case TextAgentProvider.azure:
        return 'https://myresource.openai.azure.com';
      case TextAgentProvider.litellm:
        return 'http://localhost:4000';
      case TextAgentProvider.custom:
        return 'https://api.example.com/v1';
    }
  }

  /// Check if URL is a complete endpoint URL (not just a model name)
  static bool isEndpointUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Normalize a URL by removing trailing slashes and extra whitespace
  static String normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
