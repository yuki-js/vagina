import 'package:vagina/feat/callv2/services/notepad_service.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';

/// Session-scoped [FilesystemApi] implementation for tool execution.
///
/// This is a thin compatibility adapter that delegates all operations to
/// [NotepadService]. It preserves the existing FilesystemApi contract
/// while allowing NotepadService to own the domain logic.
final class CallFilesystemApi implements FilesystemApi {
  final NotepadService _notepadService;

  CallFilesystemApi({
    required NotepadService notepadService,
  }) : _notepadService = notepadService;

  // ---------------------------------------------------------------------------
  // Persistence operations (delegate to NotepadService → VFS)
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final content = await _notepadService.read(path);
    if (content == null) return null;
    return {'path': path, 'content': content};
  }

  @override
  Future<void> write(String path, String content) async {
    // Check if file is active
    final isActive = _notepadService.getActive(path) != null;

    if (isActive) {
      // Update active file and persist immediately (tool-driven)
      await _notepadService.update(path, content, persist: true);
    } else {
      // Direct VFS write for non-active files
      await _notepadService.write(path, content);
    }
  }

  @override
  Future<void> delete(String path) async {
    // Close if active
    final isActive = _notepadService.getActive(path) != null;
    if (isActive) {
      await _notepadService.close(path);
    }

    // Delete from VFS
    await _notepadService.delete(path);
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    // Handle active file state
    final content = _notepadService.getActive(fromPath);
    if (content != null) {
      await _notepadService.close(fromPath);
      await _notepadService.open(toPath, content);
    }

    // Move in VFS
    await _notepadService.move(fromPath, toPath);
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    return _notepadService.list(path, recursive: recursive);
  }

  // ---------------------------------------------------------------------------
  // Active file operations (delegate to NotepadService in-memory state)
  // ---------------------------------------------------------------------------

  @override
  Future<void> openFile(String path, String content) async {
    await _notepadService.open(path, content);
  }

  @override
  Future<Map<String, dynamic>?> getActiveFile(String path) async {
    final content = _notepadService.getActive(path);
    if (content == null) return null;
    return {'path': path, 'content': content};
  }

  @override
  Future<void> updateActiveFile(String path, String content) async {
    // Tool-driven updates persist immediately
    await _notepadService.update(path, content, persist: true);
  }

  @override
  Future<void> closeFile(String path) async {
    await _notepadService.close(path);
  }

  @override
  Future<List<Map<String, dynamic>>> listActiveFiles() async {
    return _notepadService
        .listActive()
        .map((file) =>
            <String, dynamic>{'path': file.path, 'content': file.content})
        .toList();
  }
}
