import 'package:vagina/feat/call/models/voice_agent_api_config.dart';

/// Configuration for OpenAI Chat Completions API connections.
final class OaiCcConnectConfig {
  /// The base URL for the Chat Completions API (e.g., https://api.openai.com/v1).
  final Uri baseUrl;

  /// The model identifier to use (e.g., gpt-4o).
  final String model;

  /// Optional API key / token.
  final String? apiKey;

  /// Modality selection (VoiceAgentModality.audio or VoiceAgentModality.text).
  final VoiceAgentModality modality;

  /// Additional custom headers.
  final Map<String, String> extraHeaders;

  const OaiCcConnectConfig({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    this.modality = VoiceAgentModality.audio,
    this.extraHeaders = const <String, String>{},
  });
}
