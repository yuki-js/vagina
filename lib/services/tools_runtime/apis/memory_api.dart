/// Abstract API for memory/recall operations
/// 
/// This API allows tools running in isolates to interact with the memory repository.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class MemoryApi {
  /// Save a memory entry
  /// 
  /// Arguments:
  /// - key: Unique identifier for the memory
  /// - value: The memory content (string)
  /// - metadata: Optional metadata about the memory
  /// 
  /// Returns true if successful, false otherwise
  Future<bool> save(
    String key,
    String value, {
    Map<String, dynamic>? metadata,
  });
  
  /// Retrieve a specific memory by key
  /// 
  /// Arguments:
  /// - key: The key of the memory to retrieve
  /// 
  /// Returns the memory value as a string, or null if not found
  Future<String?> recall(String key);
  
  /// Delete a specific memory
  /// 
  /// Arguments:
  /// - key: The key of the memory to delete
  /// 
  /// Returns true if successful, false if memory not found
  Future<bool> delete(String key);
  
  /// List all memories
  /// 
  /// Returns a map of all memories where keys are memory keys and values
  /// are the memory entries as strings
  Future<Map<String, dynamic>> list();
}

/// Client implementation of MemoryApi that uses hostCall for isolate communication
class MemoryApiClient implements MemoryApi {
  final Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args) hostCall;
  
  MemoryApiClient({required this.hostCall});
  
  @override
  Future<bool> save(
    String key,
    String value, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final args = {
        'key': key,
        'value': value,
        if (metadata != null) 'metadata': metadata,
      };
      
      final result = await hostCall('save', args);
      
      if (result['status'] == 'success') {
        return true;
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to save memory';
    } catch (e) {
      throw Exception('Error saving memory: $e');
    }
  }
  
  @override
  Future<String?> recall(String key) async {
    try {
      final result = await hostCall('recall', {'key': key});
      
      if (result['status'] == 'success') {
        final data = result['data'];
        if (data is String) {
          return data;
        }
        return null;
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to recall memory';
    } catch (e) {
      throw Exception('Error recalling memory: $e');
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
      
      // Handle error
      throw result['error'] ?? 'Failed to delete memory';
    } catch (e) {
      throw Exception('Error deleting memory: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>> list() async {
    try {
      final result = await hostCall('list', {});
      
      if (result['status'] == 'success') {
        final data = result['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data as Map);
        }
        return {};
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to list memories';
    } catch (e) {
      throw Exception('Error listing memories: $e');
    }
  }
}
