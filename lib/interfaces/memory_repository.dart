/// Repository for managing AI memory/recall data
abstract class MemoryRepository {
  /// Save a memory entry
  Future<void> save(String key, String value);

  /// Get a memory entry
  Future<String?> get(String key);

  /// Get all memories
  Future<Map<String, dynamic>> getAll();

  /// Delete a specific memory
  Future<bool> delete(String key);

  /// Delete all memories
  Future<void> deleteAll();
}
