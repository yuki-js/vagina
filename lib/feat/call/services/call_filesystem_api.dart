import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/virtual_filesystem_service.dart';

/// Session-scoped [FilesystemApi] implementation for tool execution.
///
/// Delegates persistence operations to [VirtualFilesystemService] and maintains
/// in-memory active file state. Fires [onActiveFilesChanged] callback whenever
/// the active file set changes.
final class CallFilesystemApi implements FilesystemApi {
  final VirtualFilesystemService _filesystemService;
  final void Function(List<Map<String, String>>) _onActiveFilesChanged;
  final Map<String, String> _activeFiles = {};

  CallFilesystemApi({
    required VirtualFilesystemService filesystemService,
    required void Function(List<Map<String, String>>) onActiveFilesChanged,
  })  : _filesystemService = filesystemService,
        _onActiveFilesChanged = onActiveFilesChanged;

  // ---------------------------------------------------------------------------
  // Persistence operations (delegate to VirtualFilesystemService)
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final file = await _filesystemService.read(path);
    if (file == null) return null;
    return {'path': file.path, 'content': file.content};
  }

  @override
  Future<void> write(String path, String content) async {
    await _filesystemService.write(VirtualFile(path: path, content: content));
  }

  @override
  Future<void> delete(String path) async {
    await _filesystemService.delete(path);
    _activeFiles.remove(path);
    _emitChanged();
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    await _filesystemService.move(fromPath, toPath);
    final content = _activeFiles.remove(fromPath);
    if (content != null) {
      _activeFiles[toPath] = content;
    }
    _emitChanged();
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return _filesystemService.list(path, recursive: recursive);
  }

  // ---------------------------------------------------------------------------
  // Active file operations (in-memory)
  // ---------------------------------------------------------------------------

  @override
  Future<void> openFile(String path, String content) async {
    _activeFiles[path] = content;
    _emitChanged();
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final content = _activeFiles[path];
    if (content == null) return null;
    return {'path': path, 'content': content};
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    if (!_activeFiles.containsKey(path)) {
      throw Exception('Active file not found: $path');
    }
    _activeFiles[path] = content;
    _emitChanged();
  }

  @override
  Future<void> closeFile(String path) async {
    _activeFiles.remove(path);
    _emitChanged();
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    return _activeFiles.entries
        .map((e) => <String, dynamic>{'path': e.key, 'content': e.value})
        .toList()
      ..sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _emitChanged() {
    _onActiveFilesChanged(
      _activeFiles.entries
          .map((e) => {'path': e.key, 'content': e.value})
          .toList()
        ..sort((a, b) => a['path']!.compareTo(b['path']!)),
    );
  }
}
