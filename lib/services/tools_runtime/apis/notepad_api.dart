/// Abstract API for notepad operations
/// 
/// This API allows tools running in isolates to interact with the notepad service.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class NotepadApi {
  /// List all tabs
  /// 
  /// Returns a list of tab metadata maps with structure:
  /// {
  ///   'id': String,
  ///   'title': String,
  ///   'mimeType': String,
  ///   'createdAt': String (ISO 8601),
  ///   'updatedAt': String (ISO 8601),
  ///   'contentLength': int
  /// }
  Future<List<Map<String, dynamic>>> listTabs();
  
  /// Get a specific tab by ID
  /// 
  /// Returns tab metadata map with the same structure as listTabs,
  /// or null if tab not found.
  Future<Map<String, dynamic>?> getTab(String id);
  
  /// Create a new tab
  /// 
  /// Arguments:
  /// - title: Display name for the tab (optional, auto-generated if not provided)
  /// - content: Content of the tab
  /// - mimeType: MIME type of the content (e.g., 'text/markdown', 'text/html')
  /// 
  /// Returns the ID of the created tab
  Future<String> createTab({
    required String content,
    required String mimeType,
    String? title,
  });
  
  /// Update an existing tab
  /// 
  /// Arguments:
  /// - id: ID of the tab to update
  /// - content: New content (optional)
  /// - title: New title (optional)
  /// - mimeType: New MIME type (optional)
  /// 
  /// Returns true if successful, false if tab not found
  Future<bool> updateTab(
    String id, {
    String? content,
    String? title,
    String? mimeType,
  });
  
  /// Close/delete a tab
  /// 
  /// Arguments:
  /// - id: ID of the tab to close
  /// 
  /// Returns true if successful, false if tab not found
  Future<bool> closeTab(String id);
}

/// Client implementation of NotepadApi that uses hostCall for isolate communication
class NotepadApiClient implements NotepadApi {
  final Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args) hostCall;
  
  NotepadApiClient({required this.hostCall});
  
  @override
  Future<List<Map<String, dynamic>>> listTabs() async {
    try {
      final result = await hostCall('listTabs', {});
      
      if (result['status'] == 'success') {
        final data = result['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(
            data.map((tab) => Map<String, dynamic>.from(tab as Map))
          );
        }
        return [];
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to list tabs';
    } catch (e) {
      throw Exception('Error listing tabs: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>?> getTab(String id) async {
    try {
      final result = await hostCall('getTab', {'id': id});
      
      if (result['status'] == 'success') {
        final data = result['data'];
        if (data != null) {
          return Map<String, dynamic>.from(data as Map);
        }
        return null;
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to get tab';
    } catch (e) {
      throw Exception('Error getting tab: $e');
    }
  }
  
  @override
  Future<String> createTab({
    required String content,
    required String mimeType,
    String? title,
  }) async {
    try {
      final args = {
        'content': content,
        'mimeType': mimeType,
        if (title != null) 'title': title,
      };
      
      final result = await hostCall('createTab', args);
      
      if (result['status'] == 'success') {
        final data = result['data'];
        if (data is String) {
          return data;
        }
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to create tab';
    } catch (e) {
      throw Exception('Error creating tab: $e');
    }
  }
  
  @override
  Future<bool> updateTab(
    String id, {
    String? content,
    String? title,
    String? mimeType,
  }) async {
    try {
      final args = {
        'id': id,
        if (content != null) 'content': content,
        if (title != null) 'title': title,
        if (mimeType != null) 'mimeType': mimeType,
      };
      
      final result = await hostCall('updateTab', args);
      
      if (result['status'] == 'success') {
        final data = result['data'] as bool?;
        return data ?? false;
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to update tab';
    } catch (e) {
      throw Exception('Error updating tab: $e');
    }
  }
  
  @override
  Future<bool> closeTab(String id) async {
    try {
      final result = await hostCall('closeTab', {'id': id});
      
      if (result['status'] == 'success') {
        final data = result['data'] as bool?;
        return data ?? false;
      }
      
      // Handle error
      throw result['error'] ?? 'Failed to close tab';
    } catch (e) {
      throw Exception('Error closing tab: $e');
    }
  }
}
