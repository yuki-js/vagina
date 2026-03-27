import 'package:vagina/feat/callv2/models/text_agent_info.dart';

/// Repository for managing application configuration
abstract class ConfigRepository {
  /// Azure OpenAI Configuration
  Future<void> saveApiKey(String apiKey);
  Future<String?> getApiKey();
  Future<void> deleteApiKey();
  Future<bool> hasApiKey();

  Future<void> saveRealtimeUrl(String url);
  Future<String?> getRealtimeUrl();
  Future<void> deleteRealtimeUrl();
  Future<bool> hasAzureConfig();

  /// Text Agent Configuration
  Future<List<TextAgentInfo>> getAllTextAgents();
  Future<TextAgentInfo?> getTextAgentById(String id);
  Future<void> saveTextAgent(TextAgentInfo agent);
  Future<void> deleteTextAgent(String id);
  Future<String?> getSelectedTextAgentId();
  Future<void> setSelectedTextAgentId(String? id);

  /// Clear all configuration
  Future<void> clearAll();

  /// Get config file path (for debugging)
  Future<String> getConfigFilePath();
}
