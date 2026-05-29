import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';

/// Repository for managing application configuration
abstract class ConfigRepository {
  /// Voice agent API configuration
  Future<void> saveVoiceAgentApiConfig(VoiceAgentApiConfig config);
  Future<VoiceAgentApiConfig?> getVoiceAgentApiConfig();

  /// Text Agent Configuration
  Future<List<TextAgentInfo>> getAllTextAgents();
  Future<TextAgentInfo?> getTextAgentById(String id);
  Future<void> saveTextAgent(TextAgentInfo agent);
  Future<void> deleteTextAgent(String id);

  /// Clear all configuration
  Future<void> clearAll();

  /// Get config file path (for debugging)
  Future<String> getConfigFilePath();
}
