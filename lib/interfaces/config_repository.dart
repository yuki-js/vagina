import 'package:vagina/feat/call/models/text_agent_info.dart';

/// Repository for managing application configuration
abstract class ConfigRepository {
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
