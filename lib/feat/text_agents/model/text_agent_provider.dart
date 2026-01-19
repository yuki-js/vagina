/// Provider type for text agent configuration
enum TextAgentProvider {
  /// OpenAI official API (api.openai.com)
  openai('openai', 'OpenAI'),

  /// Azure OpenAI Service
  azure('azure', 'Azure OpenAI'),

  /// LiteLLM proxy service
  litellm('litellm', 'LiteLLM Proxy'),

  /// Any OpenAI-compatible endpoint
  custom('custom', 'Custom Endpoint');

  final String value;
  final String displayName;

  const TextAgentProvider(this.value, this.displayName);

  factory TextAgentProvider.fromString(String value) {
    return TextAgentProvider.values.firstWhere(
      (provider) => provider.value == value,
      orElse: () => TextAgentProvider.openai,
    );
  }

  /// Get the default endpoint for this provider
  String? getDefaultEndpoint() {
    switch (this) {
      case TextAgentProvider.openai:
        return 'https://api.openai.com/v1';
      case TextAgentProvider.azure:
        return null; // Azure requires custom endpoint
      case TextAgentProvider.litellm:
        return null; // LiteLLM requires custom endpoint
      case TextAgentProvider.custom:
        return null; // Custom requires endpoint
    }
  }

  /// Get the required fields description for this provider
  String getFieldsDescription() {
    switch (this) {
      case TextAgentProvider.openai:
        return 'API Key, Model ID (e.g., gpt-4, gpt-4o)';
      case TextAgentProvider.azure:
        return 'API Key, Endpoint URL (from Azure Portal)';
      case TextAgentProvider.litellm:
        return 'API Key, Proxy URL (e.g., http://localhost:4000)';
      case TextAgentProvider.custom:
        return 'API Key, Endpoint URL (OpenAI-compatible)';
    }
  }

  /// Get commonly available models for this provider
  List<String> getCommonModels() {
    switch (this) {
      case TextAgentProvider.openai:
        return [
          'gpt-4o',
          'gpt-4-turbo',
          'gpt-4',
          'gpt-3.5-turbo',
        ];
      case TextAgentProvider.azure:
        return [
          'gpt-4o',
          'gpt-4-turbo',
          'gpt-4',
          'gpt-35-turbo',
        ];
      case TextAgentProvider.litellm:
        return [
          'gpt-4o',
          'gpt-4-turbo',
          'claude-3-opus',
          'claude-3-sonnet',
        ];
      case TextAgentProvider.custom:
        return [];
    }
  }
}
