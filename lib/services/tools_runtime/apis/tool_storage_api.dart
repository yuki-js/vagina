/// Tool-isolated storage API for tools running in isolates
///
/// This API allows individual tools to persist data in their own isolated namespace.
/// Tools cannot access other tools' data. The toolKey is managed by the host context
/// and passed implicitly - tools don't need to know about isolation.
abstract class ToolStorageApi {
  /// Save a value in the tool's isolated storage
  ///
  /// Arguments:
  /// - key: Storage key (within this tool's namespace)
  /// - value: The data to store (must be JSON-serializable)
  ///
  /// Returns true if successful, false otherwise
  Future<bool> save(String key, dynamic value);

  /// Retrieve a value from the tool's isolated storage
  ///
  /// Arguments:
  /// - key: The storage key to retrieve
  ///
  /// Returns the stored value, or null if not found
  Future<dynamic> get(String key);

  /// List all data in the tool's isolated storage
  ///
  /// Returns a map of all data stored by this tool
  Future<Map<String, dynamic>> list();

  /// Delete a specific entry from the tool's storage
  ///
  /// Arguments:
  /// - key: The storage key to delete
  ///
  /// Returns true if successful, false if key not found
  Future<bool> delete(String key);

  /// Delete all data for this tool
  ///
  /// This is typically called when cleaning up the tool.
  /// Use with caution as this cannot be undone.
  Future<void> deleteAll();
}

/// Client implementation of ToolStorageApi for isolate communication
class ToolStorageApiClient implements ToolStorageApi {
  final Future<Map<String, dynamic>> Function(
      String method, Map<String, dynamic> args) hostCall;

  ToolStorageApiClient({required this.hostCall});

  @override
  Future<bool> save(String key, dynamic value) async {
    try {
      final args = {
        'key': key,
        'value': value,
      };

      final result = await hostCall('save', args);

      if (result['status'] == 'success') {
        return true;
      }

      throw result['error'] ?? 'Failed to save';
    } catch (e) {
      throw Exception('Error saving to storage: $e');
    }
  }

  @override
  Future<dynamic> get(String key) async {
    try {
      final result = await hostCall('get', {'key': key});

      if (result['status'] == 'success') {
        return result['data'];
      }

      throw result['error'] ?? 'Failed to get value';
    } catch (e) {
      throw Exception('Error retrieving from storage: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> list() async {
    try {
      final result = await hostCall('list', {});

      if (result['status'] == 'success') {
        final data = result['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return {};
      }

      throw result['error'] ?? 'Failed to list storage';
    } catch (e) {
      throw Exception('Error listing storage: $e');
    }
  }

  @override
  Future<bool> delete(String key) async {
    try {
      final result = await hostCall('delete', {'key': key});

      if (result['status'] == 'success') {
        final data = result['data'] as bool?;
        return data ?? false;
      }

      throw result['error'] ?? 'Failed to delete';
    } catch (e) {
      throw Exception('Error deleting from storage: $e');
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final result = await hostCall('deleteAll', {});

      if (result['status'] != 'success') {
        throw result['error'] ?? 'Failed to delete all';
      }
    } catch (e) {
      throw Exception('Error deleting all from storage: $e');
    }
  }
}
