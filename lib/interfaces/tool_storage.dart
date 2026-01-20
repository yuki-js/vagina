/// Tool-isolated storage repository for per-tool data persistence
///
/// Each tool gets its own isolated namespace in the storage layer,
/// allowing tools to manage their own data without the host needing
/// to know about tool-specific logic.
///
/// Keys are automatically namespaced by toolKey, so a tool with key "calculator"
/// storing "config" will not collide with another tool storing the same key.
abstract class ToolStorage {
  /// Save a value in the tool's isolated storage namespace
  ///
  /// Arguments:
  /// - toolKey: Unique identifier of the tool (provided by host)
  /// - key: Key within the tool's namespace
  /// - value: The data to store (must be JSON-serializable)
  ///
  /// The actual storage key becomes: "toolKey:key"
  /// This ensures tools cannot access each other's data.
  Future<void> save(String toolKey, String key, dynamic value);

  /// Retrieve a value from the tool's isolated storage namespace
  ///
  /// Arguments:
  /// - toolKey: Unique identifier of the tool
  /// - key: Key within the tool's namespace
  ///
  /// Returns the stored value, or null if not found.
  /// Tools can only read from their own namespace.
  Future<dynamic> get(String toolKey, String key);

  /// List all data in the tool's isolated storage namespace
  ///
  /// Arguments:
  /// - toolKey: Unique identifier of the tool
  ///
  /// Returns a map of all data stored by this tool (without the toolKey prefix).
  /// Tools only see their own data.
  Future<Map<String, dynamic>> listAll(String toolKey);

  /// Delete a specific entry from the tool's storage namespace
  ///
  /// Arguments:
  /// - toolKey: Unique identifier of the tool
  /// - key: Key within the tool's namespace
  ///
  /// Returns true if the entry existed and was deleted, false otherwise.
  Future<bool> delete(String toolKey, String key);

  /// Delete all data for a specific tool
  ///
  /// Arguments:
  /// - toolKey: Unique identifier of the tool
  ///
  /// This is called when a tool is removed from the system.
  Future<void> deleteAll(String toolKey);
}
