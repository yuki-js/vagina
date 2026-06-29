/// Repository for managing application configuration
abstract class ConfigRepository {
  /// Clear all configuration
  Future<void> clearAll();

  /// Get config file path (for debugging)
  Future<String> getConfigFilePath();
}
