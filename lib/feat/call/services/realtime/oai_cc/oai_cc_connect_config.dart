/// Configuration for OpenAI Chat Completions API connections.
final class OaiCcConnectConfig {
  /// The base URL for the Chat Completions API (e.g., https://api.openai.com/v1).
  final Uri baseUrl;

  /// The model identifier to use (e.g., gpt-4o).
  final String model;

  /// Optional API key / token.
  final String? apiKey;

  /// Additional custom headers.
  final Map<String, String> extraHeaders;

  const OaiCcConnectConfig({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    this.extraHeaders = const <String, String>{},
  });
}
