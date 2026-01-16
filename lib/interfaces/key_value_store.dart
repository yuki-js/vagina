/// Abstract key-value store interface
abstract class KeyValueStore {
  /// Initialize the store
  Future<void> initialize();

  /// Load all data
  Future<Map<String, dynamic>> load();

  /// Save all data
  Future<void> save(Map<String, dynamic> data);

  /// Get a value by key
  Future<dynamic> get(String key);

  /// Set a value by key
  Future<void> set(String key, dynamic value);

  /// Delete a value by key
  Future<void> delete(String key);

  /// Check if key exists
  Future<bool> contains(String key);

  /// Clear all data
  Future<void> clear();

  /// Get the storage file path (for debugging)
  Future<String> getFilePath();
}
