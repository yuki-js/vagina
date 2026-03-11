/// Abstract API for virtual filesystem operations from sandboxed tools.
///
/// This API covers both persistent filesystem operations and runtime active-file
/// state used during active calls.
abstract class FilesystemApi {
  /// Read a persisted file.
  ///
  /// Returns:
  /// - `{ 'path': String, 'content': String }` when found
  /// - `null` when not found
  Future<Map<String, dynamic>?> read(String path);

  /// Create or overwrite a persisted file.
  Future<void> write(String path, String content);

  /// Delete a persisted file.
  Future<void> delete(String path);

  /// Move/rename a persisted file.
  Future<void> move(String fromPath, String toPath);

  /// List persisted filesystem entries.
  Future<List<String>> list(String path, {bool recursive = false});

  /// Register file as active in runtime state.
  Future<void> openFile(String path, String content);

  /// Get runtime active file state by path.
  ///
  /// Returns:
  /// - `{ 'path': String, 'content': String }` when active
  /// - `null` when not active
  Future<Map<String, dynamic>?> getActiveFile(String path);

  /// Update runtime active file content.
  Future<void> updateActiveFile(String path, String content);

  /// Remove file from runtime active state.
  Future<void> closeFile(String path);

  /// List all currently active runtime files.
  ///
  /// Returns list of `{ 'path': String, 'content': String }`.
  Future<List<Map<String, dynamic>>> listActiveFiles();
}

/// Client implementation of [FilesystemApi] that uses hostCall.
class FilesystemApiClient implements FilesystemApi {
  final Future<dynamic> Function(String method, Map<String, dynamic> args)
      hostCall;

  FilesystemApiClient({required this.hostCall});

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final data = await hostCall('read', {'path': path});
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError(
      'Invalid filesystem.read response type: ${data.runtimeType}',
    );
  }

  @override
  Future<void> write(String path, String content) async {
    await hostCall('write', {'path': path, 'content': content});
  }

  @override
  Future<void> delete(String path) async {
    await hostCall('delete', {'path': path});
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    await hostCall('move', {'fromPath': fromPath, 'toPath': toPath});
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final data = await hostCall(
      'list',
      {'path': path, 'recursive': recursive},
    );

    if (data is List) {
      return List<String>.from(data);
    }
    throw StateError(
      'Invalid filesystem.list response type: ${data.runtimeType}',
    );
  }

  @override
  Future<void> openFile(String path, String content) async {
    await hostCall('openFile', {'path': path, 'content': content});
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final data = await hostCall('getActiveFile', {'path': path});
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError(
      'Invalid filesystem.getActiveFile response type: ${data.runtimeType}',
    );
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    await hostCall('updateActiveFile', {'path': path, 'content': content});
  }

  @override
  Future<void> closeFile(String path) async {
    await hostCall('closeFile', {'path': path});
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    final data = await hostCall('listActiveFiles', {});
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((entry) => Map<String, dynamic>.from(entry as Map)),
      );
    }
    throw StateError(
      'Invalid filesystem.listActiveFiles response type: ${data.runtimeType}',
    );
  }
}
