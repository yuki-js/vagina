import 'package:vagina/models/android_audio_config.dart';

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

  /// Android Audio Configuration
  Future<void> saveAndroidAudioConfig(AndroidAudioConfig config);
  Future<AndroidAudioConfig> getAndroidAudioConfig();

  /// Tool Configuration
  Future<bool> isToolEnabled(String toolName);
  Future<void> enableTool(String toolKey);
  Future<void> disableTool(String toolKey);

  /// Clear all configuration
  Future<void> clearAll();

  /// Get config file path (for debugging)
  Future<String> getConfigFilePath();
}
