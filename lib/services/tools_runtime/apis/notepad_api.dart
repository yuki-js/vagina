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
  final Future<dynamic> Function(String method, Map<String, dynamic> args) hostCall;
  
  NotepadApiClient({required this.hostCall});
  
  @override
  Future<List<Map<String, dynamic>>> listTabs() async {
    final data = await hostCall('listTabs', {});

    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((tab) => Map<String, dynamic>.from(tab as Map)),
      );
    }

    throw StateError(
      'Invalid notepad.listTabs response type: ${data.runtimeType}',
    );
  }
  
  @override
  Future<Map<String, dynamic>?> getTab(String id) async {
    final data = await hostCall('getTab', {'id': id});

    if (data == null) {
      return null;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw StateError(
      'Invalid notepad.getTab response type: ${data.runtimeType}',
    );
  }
  
  @override
  Future<String> createTab({
    required String content,
    required String mimeType,
    String? title,
  }) async {
    final args = {
      'content': content,
      'mimeType': mimeType,
      if (title != null) 'title': title,
    };

    final data = await hostCall('createTab', args);

    if (data is String) {
      return data;
    }

    throw StateError(
      'Invalid notepad.createTab response type: ${data.runtimeType}',
    );
  }
  
  @override
  Future<bool> updateTab(
    String id, {
    String? content,
    String? title,
    String? mimeType,
  }) async {
    final args = {
      'id': id,
      if (content != null) 'content': content,
      if (title != null) 'title': title,
      if (mimeType != null) 'mimeType': mimeType,
    };

    final data = await hostCall('updateTab', args);

    if (data is bool) {
      return data;
    }

    throw StateError(
      'Invalid notepad.updateTab response type: ${data.runtimeType}',
    );
  }
  
  @override
  Future<bool> closeTab(String id) async {
    final data = await hostCall('closeTab', {'id': id});

    if (data is bool) {
      return data;
    }

    throw StateError(
      'Invalid notepad.closeTab response type: ${data.runtimeType}',
    );
  }
}
